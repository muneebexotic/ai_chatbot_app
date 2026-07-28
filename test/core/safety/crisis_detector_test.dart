import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/core/safety/crisis_detector.dart';
import 'package:speakwise/core/safety/crisis_resources.dart';

/// R10.6 and §14's "Crisis-response path (R10.6) tested with a scripted
/// transcript."
///
/// Two failure modes matter here and they pull in opposite directions.
///
/// **Missing a real disclosure** is the one the requirement is written about.
/// **Firing on an idiom** is the one that makes the feature useless in
/// practice: a card that interrupts practice to offer help for a problem the
/// user does not have is alarming the first time, irritating the second, and
/// ignored by the third — at which point the real disclosure gets an ignored
/// card. So the negative cases below are not padding; they are half the
/// requirement.
void main() {
  const detector = CrisisDetector();

  CrisisSignal? signal(String text) => detector.examine(text)?.signal;

  group('§14 — a scripted transcript', () {
    // A single session, written as it would actually unfold: an ordinary
    // interview rehearsal that turns. Every line before the disclosure must
    // stay silent, and the disclosure must be caught.
    const transcript = [
      'Hi, I want to practise for a product manager interview on Thursday.',
      'My last role was at a logistics startup, about two years.',
      "Honestly the interview prep is killing me, I've been at it for weeks.",
      "I'm dying to get this one, it's the job I actually want.",
      'I gave a presentation on suicide prevention at my last company, so I can '
          'talk about public speaking too.',
      'Sorry, I am not doing well. I have been thinking about killing myself.',
    ];

    test('nothing fires until the disclosure', () {
      for (final line in transcript.take(5)) {
        expect(
          signal(line),
          isNull,
          reason:
              'Fired on ordinary speech: "$line". A card here would teach the '
              'user that the safety behaviour is noise.',
        );
      }
    });

    test('the disclosure is caught', () {
      expect(signal(transcript.last), CrisisSignal.suicidalIntent);
    });

    test('examineAll finds it in the whole transcript', () {
      // The path used when a force-killed session is recovered from local
      // storage (R4.2.6): the card must reappear, because the reason for it did
      // not stop being true when the app died.
      expect(detector.examineAll(transcript)?.signal, CrisisSignal.suicidalIntent);
      expect(detector.examineAll(transcript.take(5)), isNull);
    });
  });

  group('idioms must not fire', () {
    const idioms = [
      "I'm dying to know what happens next",
      'I am dying for a coffee',
      'This deadline is killing me',
      'My back is killing me after that flight',
      "I could kill for a decent night's sleep",
      "I'd kill for that role",
      'I was dead tired by the end of it',
      "I'm dead serious about the deadline",
      'That would be career suicide',
      'Changing the pricing now would be commercial suicide',
      'It felt like a suicide mission',
      'She absolutely killed it in the demo',
      'I died laughing at that',
      'I gave a talk about self-harm awareness at work',
      'My research on suicide prevention was published last year',
      'We ran a campaign about self-harm in schools',
    ];

    for (final line in idioms) {
      test('"$line"', () => expect(signal(line), isNull));
    }
  });

  group('real disclosures must fire', () {
    const disclosures = {
      'I want to kill myself': CrisisSignal.suicidalIntent,
      'I have been thinking about ending my life': CrisisSignal.suicidalIntent,
      'sometimes I just want to die': CrisisSignal.suicidalIntent,
      'I wish I was dead': CrisisSignal.suicidalIntent,
      'everyone would be better off dead': CrisisSignal.suicidalIntent,
      'I feel suicidal': CrisisSignal.suicidalIntent,
      'I tried to commit suicide last year': CrisisSignal.suicidalIntent,
      'I want to take my own life': CrisisSignal.suicidalIntent,
      'I have been hurting myself': CrisisSignal.selfHarm,
      'I self harm when it gets bad': CrisisSignal.selfHarm,
      'I have been cutting myself again': CrisisSignal.selfHarm,
      'I took an overdose in March': CrisisSignal.selfHarm,
      "there's no reason to live": CrisisSignal.hopelessness,
      "I can't do this any more": CrisisSignal.hopelessness,
      'I have nothing left to live for': CrisisSignal.hopelessness,
      'I just want it to stop': CrisisSignal.hopelessness,
    };

    disclosures.forEach((line, expected) {
      test('"$line"', () => expect(signal(line), expected));
    });
  });

  group('the recogniser\'s output shapes', () {
    test('no punctuation at all still matches', () {
      // speech_to_text with autoPunctuation off, or a recogniser that simply
      // does not punctuate, produces a bare run of words. Every real
      // disclosure arrives this way at least sometimes.
      expect(
        signal('i have been thinking about killing myself for a while now'),
        CrisisSignal.suicidalIntent,
      );
    });

    test('a curly apostrophe matches the same as a straight one', () {
      expect(signal('I can’t do this any more'), CrisisSignal.hopelessness);
      expect(signal("I can't do this any more"), CrisisSignal.hopelessness);
    });

    test('case and spacing do not matter', () {
      expect(signal('I  WANT   TO  KILL    MYSELF'), CrisisSignal.suicidalIntent);
    });

    test('empty and whitespace input is silent', () {
      expect(signal(''), isNull);
      expect(signal('   '), isNull);
    });
  });

  group('an idiom does not shield a real disclosure', () {
    test('both in one utterance still fires', () {
      // The obvious wrong implementation is "if it contains an idiom, skip the
      // utterance", which turns ordinary English into an exploit of the safety
      // feature. Idioms are removed from the text; they do not excuse it.
      expect(
        signal("I'm dying to know whether I should just kill myself"),
        CrisisSignal.suicidalIntent,
      );
      expect(
        signal('That would be career suicide, and honestly I feel suicidal'),
        CrisisSignal.suicidalIntent,
      );
      expect(
        signal('I gave a talk about resilience. I have been cutting myself.'),
        CrisisSignal.selfHarm,
      );
    });
  });

  group('resources (R10.6) — and §16, which forbids inventing them', () {
    test('every locale gets emergency services and a directory', () {
      for (final locale in ['en', 'ur', 'en-GB', 'hi_IN', 'zz']) {
        final resources = CrisisResources.forLocale(locale);
        expect(
          resources.map((r) => r.kind),
          containsAll([
            CrisisResourceKind.emergencyServices,
            CrisisResourceKind.helplineDirectory,
          ]),
          reason: 'no locale may fall through to an empty card',
        );
      }
    });

    test('the directory resource carries a real URL and emergency does not', () {
      final resources = CrisisResources.forLocale('en');
      final directory = resources.firstWhere(
        (r) => r.kind == CrisisResourceKind.helplineDirectory,
      );
      expect(directory.url, startsWith('https://'));

      final emergency = resources.firstWhere(
        (r) => r.kind == CrisisResourceKind.emergencyServices,
      );
      expect(
        emergency.url,
        isNull,
        reason:
            'Emergency services is an instruction, not a link. It deliberately '
            'names no number, because no build of this app can know the '
            'reader s country.',
      );
    });

    test('no phone number is hardcoded anywhere in the resource table', () {
      // §16: no invented facts. A crisis line that has been reassigned, or that
      // is right for one country and wrong for the reader's, sends a person in
      // crisis to a disconnected line on this app's authority. verifiedLines is
      // empty until the owner has checked each number against its operator's
      // own site; this test is what stops one being added casually.
      expect(
        CrisisResources.verifiedLines,
        isEmpty,
        reason:
            'Someone added a crisis line. That is welcome — but it must come '
            'with the owner s verification and the date of the check recorded '
            'beside it (README TODO(muneeb)), and this test updated to assert '
            'the checked entries rather than emptiness.',
      );
    });
  });
}
