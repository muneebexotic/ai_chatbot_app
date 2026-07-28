import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source.dart';

/// Things PRD §16 forbids, expressed as the words a user would read rather
/// than as the symbols a developer would type.
///
/// Kept at the top level so the rule, the proof that it fires, and the proof
/// that it does not over-fire all read the same patterns. Three copies of a
/// regex is three chances for one of them to drift.
final _bannedInCopy = <String, RegExp>{
  // §2.2 CUT, §16 never-do. Every phrasing that would *offer* generation to a
  // user, not just the vendor names — the vendor names were already gone when
  // "Generate Avatar" was still on screen.
  'image generation': RegExp(
    r'\b(generate|generating|create|creating|make|draw|render)\s+'
    // Any run of modifiers, not one: the string that shipped was "generating
    // a unique avatar", and a single optional article let it through on the
    // first draft of this rule.
    r'((a|an|the|your|my|another|random|unique|new|custom)\s+)*'
    r'(image|images|picture|pictures|avatar|avatars|artwork|illustration)\b',
    caseSensitive: false,
  ),
  'image generation (noun form)': RegExp(
    r'\b(image|photo|picture|avatar)[ -]generation\b'
    r'|\btext[ -]to[ -]image\b'
    r'|\bai[ -]generated\s+(image|picture|avatar|art)\b',
    caseSensitive: false,
  ),
  'image generation vendor': RegExp(
    r'dall[·‑–-]?e\b|stable\s?diffusion|midjourney'
    r'|api\.stability\.ai|/text-to-image',
    caseSensitive: false,
  ),
  // §16 and R8.5: no ads in v1.
  'advertising': RegExp(
    r'\badmob\b|google_mobile_ads|\b(banner|interstitial|rewarded)ad\b'
    r'|\bwatch\s+(an?\s+)?ad\b|\bsponsored\b',
    caseSensitive: false,
  ),
  // §16 and R8.3: no fake urgency, no fake discounts, no guilt-based streak
  // copy. Note what is deliberately NOT here — "expires", "renews", and
  // "cancel" are absent, because R8.2 requires the app to state a real expiry
  // and R8.4 requires cancelling to be easy to find. A rule that forbade
  // telling the truth would be traded away the first time it fired, and then
  // the whole group would be untrustworthy.
  'dark pattern copy': RegExp(
    r"\bhurry\b|\bact now\b|\blimited[ -]time\b|\boffer ends\b"
    r"|\btoday only\b|\bdon'?t miss\b|\blast chance\b|\bonly \d+ left\b"
    r"|\b(lose|losing|lost|break|breaking)\s+(your\s+)?streak\b"
    r"|\bstreak\s+will\s+(end|break|reset)\b",
    caseSensitive: false,
  ),
  // §7.6 bans this phrase by name. It shipped as the splash subtitle — the
  // first copy anyone ever read — through four milestones.
  'AI-powered': RegExp(r'\bai[ -]powered\b', caseSensitive: false),
};

/// Files in `lib/` that nothing reaches from `main.dart`, and why each is
/// allowed to stay that way for now.
///
/// Every entry names the milestone that resolves it. That is the difference
/// between a quarantine and an exemption: an exemption is permanent and this
/// is a countdown. The test fails if an entry becomes reachable or disappears
/// without being removed here, so the list cannot quietly outlive its reasons.
///
/// It should be empty by the end of Milestone 6. If it is not, that is a
/// finding for `CRITIQUE.md`, not a reason to relax the rule.
const _expectedOrphans = <String, String>{
  // RESOLVED IN MILESTONE 4:
  //   services/speech_service.dart and services/voice_service.dart — DELETED.
  //     The quarantine asked the milestone that needed them to "wire them up or
  //     delete them". Neither survived contact with the requirements: the first
  //     was 42 lines that re-initialised the recogniser on every listen and
  //     returned `bool` for failure, with no amplitude and no turn detection;
  //     the second was 15 lines that set the language and pitch before every
  //     utterance, three platform round trips inside R4.2.4's 1.5s budget.
  //     Replaced by features/session/data/{speech_recognition_service,
  //     tts_service}.dart, which are what §4.2 actually needs.

  // The R4.3.1 metrics engine, landed ahead of the screen that feeds it.
  //
  // These entries are IN-MILESTONE and short-lived, which is different from
  // every other entry in this map. DECISIONS D2 requires the engine to be "a
  // standalone, independently testable module with Drill Mode as a known
  // consumer" — so it is written and proved against a hand-checked transcript
  // (§14) before anything consumes it, rather than growing inside the session
  // controller where Drill Mode could not reach it in Milestone 5.
  //
  // The session controller imports all five. If these entries are still here
  // when Milestone 4 closes, the engine was never wired up and the milestone
  // is not done.
  'lib/core/speech_metrics/metrics_engine.dart': 'M4 — awaiting the session controller',
  'lib/core/speech_metrics/speech_metrics.dart': 'M4 — awaiting the session controller',
  'lib/core/speech_metrics/transcript.dart': 'M4 — awaiting the session controller',
  'lib/core/speech_metrics/filler_lexicon.dart': 'M4 — awaiting the session controller',
  'lib/core/speech_metrics/pace_band.dart': 'M4 — awaiting the session controller',

  // The two on-device services and the sentence splitter, same in-milestone
  // quarantine as the engine above and for the same reason: each is testable on
  // its own and none of them should grow inside the controller that drives
  // them. The controller imports all three.
  'lib/features/session/data/speech_recognition_service.dart':
      'M4 — awaiting the session controller',
  'lib/features/session/data/tts_service.dart': 'M4 — awaiting the session controller',
  'lib/features/session/domain/sentence_segmenter.dart':
      'M4 — awaiting the session controller',

  // Paywall debris. §14 and R0.5.6 both put the paywall on the list of screens
  // that must not ship as the default, so Milestone 6 rebuilds rather than
  // rewires these.
  'lib/services/subscription_service_extensions.dart': 'M6 — paywall rebuild',
  'lib/widgets/subscription_widgets.dart': 'M6 — paywall rebuild',

  // RESOLVED IN MILESTONE 3, listed here only so the record is legible:
  //   waveform.dart / waveform_painter.dart — now the chat loading state and
  //     the partner marks. W1.1's "built, tested, and completely unused" is
  //     no longer true of the signature element.
  //   constants/personas.dart — replaced by rows in `partners` (§5.3.2).
  //   models/conversation.dart — replaced by `threads`.
  //   services/clipboard_service.dart — the copy button uses
  //     `flutter/services` Clipboard directly, which §2.2 asked for.
  // All five are deleted or wired up; none needs an entry.
};

/// Executable versions of the layering rules in PRD §9.1.
///
/// F3 ("`BuildContext` inside services") survived a year because it was a
/// convention nobody could run. A convention that cannot fail a build is a
/// preference. These tests read the source and fail if the rules are broken,
/// so the next person to reach for `Provider.of` inside a service finds out in
/// CI rather than in review — or not at all.
void main() {
  final libFiles = dartFilesUnder('lib');

  List<File> dartFilesIn(String relativePath) =>
      dartFilesUnder('lib/$relativePath');

  /// Strips `//` and `///` comments so a rule is not tripped by prose about
  /// the rule — several files legitimately explain why they do NOT do these
  /// things.
  String codeOf(File file) => file
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('PRD §9.1 — services never know about the widget tree', () {
    test('no service takes or stores a BuildContext (F3)', () {
      final offenders = <String>[];
      for (final file in dartFilesIn('services')) {
        if (codeOf(file).contains('BuildContext')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These services reference BuildContext, which is F3. Inject plain '
            'dependencies through the constructor instead:\n${offenders.join('\n')}',
      );
    });

    test('no service imports flutter/material', () {
      final offenders = <String>[];
      for (final file in dartFilesIn('services')) {
        if (codeOf(file).contains("package:flutter/material.dart")) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A service importing Material is how presentation concerns leak '
            'into the data layer:\n${offenders.join('\n')}',
      );
    });

    test('no provider or controller stores a BuildContext as a field', () {
      // Holding a context is the same defect as a service holding one, one
      // layer up: it forces a liveness check before every use and makes the
      // class impossible to drive in a test without a widget tree.
      // `ChatProvider` was exactly this.
      //
      // HISTORY. This assertion originally covered `providers/` and
      // `controllers/`, failed on login_controller and welcome_controller, and
      // was narrowed to `providers/` with a justification. Narrowing a rule
      // because it caught something is how F3 survived a year in the first
      // place, so the controllers were fixed instead and the original scope
      // restored. Both now take a BuildContext per call. See CRITIQUE.md W1.3.
      final pattern = RegExp(r'final\s+BuildContext\s+\w+\s*;');
      final offenders = <String>[];
      for (final dir in ['providers', 'controllers']) {
        for (final file in dartFilesIn(dir)) {
          if (pattern.hasMatch(codeOf(file))) offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Storing a BuildContext on a long-lived object outlives the widget '
            'that provided it. Pass it per call instead:\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('PRD F5 — Provider is fully migrated to Riverpod', () {
    test('nothing imports package:provider', () {
      final offenders = <String>[];
      for (final entity in libFiles) {
        if (codeOf(entity).contains('package:provider/')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'F5 forbids ending a milestone half-Provider:\n${offenders.join('\n')}',
      );
    });

    test('no Provider.of / context.read / context.watch remains', () {
      final pattern = RegExp(r'Provider\.of<|context\.read<|context\.watch<');
      final offenders = <String>[];
      for (final entity in libFiles) {
        if (pattern.hasMatch(codeOf(entity))) offenders.add(entity.path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('PRD §2.2 — cut features stay cut', () {
    test('no image-generation or Cloudinary code', () {
      final pattern = RegExp(
        r'ImageGenerationProvider|ImageGenerationService|GeneratedImage\b|CloudinaryService|api\.cloudinary\.com',
      );
      final offenders = <String>[];
      for (final entity in libFiles) {
        if (pattern.hasMatch(codeOf(entity))) offenders.add(entity.path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no banned typeface is referenced', () {
      // §7 anti-brief and §16. Poppins and Urbanist were deleted from assets;
      // this stops a stray fontFamily string resurrecting them as a silent
      // fallback to the platform default.
      final banned = [
        'Poppins',
        'Urbanist',
        'Montserrat',
        'Space Grotesk',
      ];
      final offenders = <String>[];
      for (final entity in libFiles) {
        final code = codeOf(entity);
        for (final font in banned) {
          if (code.contains("'$font'") || code.contains('"$font"')) {
            offenders.add('${entity.path}: $font');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no banned feature has a user-facing entry point (§16)', () {
      // WHY THIS IS SEPARATE FROM THE TEST ABOVE.
      //
      // That one matches identifiers. This one matches *words a person can
      // read*, because Milestone 2 proved the two are different questions.
      // The generation services were deleted in Milestone 1 and the identifier
      // rule went green — while the shipped app still offered "Generate
      // Avatar" on the screen every new account saw and "Create Image" on the
      // chat empty state. Neither referenced a deleted symbol, so nothing
      // failed to compile and nothing failed here. Both were found by opening
      // a screenshot (CRITIQUE.md W2.1).
      //
      // The rule now reads string literals out of the parsed source, so a
      // banned feature cannot re-enter as a label in a constants list, a
      // suggestion chip, a menu entry, or a button.
      //
      // Comments are not literals, which is what makes this safe to run over a
      // codebase whose comments discuss these features at length in order to
      // explain why they are gone.
      final offenders = <String>[];
      for (final literal in allLibStrings()) {
        // A literal can wrap across source lines; a reader sees one line of
        // copy, so match what the reader sees.
        final text = literal.value.replaceAll(RegExp(r'\s+'), ' ');
        for (final entry in _bannedInCopy.entries) {
          if (entry.value.hasMatch(text)) {
            offenders.add('${literal.location}  [${entry.key}]  "$text"');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These strings offer, name, or advertise something the PRD §16 '
            'never-do list forbids. Deleting the service behind a feature is '
            'not deleting the feature; the label is what the user sees:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the entry-point rule catches the labels that actually shipped', () {
      // A rule written after the fact needs evidence that it is not vacuous,
      // so it is exercised against the real strings rather than trusted.
      //
      // Every entry below was live in the shipped app at some point in
      // Milestones 0–2 and was found by opening a screenshot, not by a test.
      // If someone later loosens a pattern to make a new string pass, this
      // fails — which is the point. CRITIQUE.md W1.3 records what happens
      // when a rule is narrowed instead of satisfied.
      const shipped = {
        'Generate Avatar': 'image generation',
        'Get a unique AI-generated avatar': 'image generation (noun form)',
        'Create Image': 'image generation',
        'Generate Images': 'image generation',
        'AI-Powered Conversations': 'AI-powered',
        'Help others recognize you by adding a profile photo or generating a '
                'unique avatar':
            'image generation',
      };

      for (final entry in shipped.entries) {
        expect(
          _bannedInCopy[entry.value]!.hasMatch(entry.key),
          isTrue,
          reason:
              '"${entry.key}" shipped in the app and must be caught by the '
              '"${entry.value}" rule',
        );
      }
    });

    test('the entry-point rule does not fire on legitimate copy', () {
      // The other half of the same argument. A rule that flags honest strings
      // is a rule someone eventually deletes, so the copy the product
      // genuinely needs is pinned here: §5.4 keeps image *understanding*, R8.2
      // requires stating a real expiry, and R4.3.5 requires a streak that
      // never uses loss-aversion pressure.
      const allowed = [
        'Ask about a photo',
        'Send a picture and ask what is in it',
        'Your subscription expires on 4 August',
        'Pro renews monthly. Cancel any time in Play.',
        '12 sessions. Your longest run was 5 days.',
        'No sessions yet. The first one takes 60 seconds.',
        'Speak. Hear how you sounded.',
      ];

      final wrongly = <String>[];
      for (final line in allowed) {
        for (final entry in _bannedInCopy.entries) {
          if (entry.value.hasMatch(line)) {
            wrongly.add('[${entry.key}] "$line"');
          }
        }
      }
      expect(wrongly, isEmpty, reason: wrongly.join('\n'));
    });

    test('every file in lib/ is reachable from main.dart', () {
      // The rule above catches a banned feature that is *offered*. This one
      // catches a banned feature that is merely *kept*.
      //
      // `image_prompt_suggestions.dart` was 470 lines of text-to-image prompt
      // library — "Dragon soaring over a medieval castle", six categories,
      // search, tabs — sitting in `lib/` with nothing importing it. Every
      // rule in this file passed over it: it named no deleted symbol, its
      // strings offer nothing (they *are* the prompts), and the analyzer does
      // not flag an unused public class. It compiled into nothing and shipped
      // in no APK, but it was the user interface of a feature §2.2 says to
      // "remove all related code" for, and it read as live code to anyone
      // opening the folder.
      //
      // Reachability is the property that actually distinguishes it. A file no
      // route, screen, or provider can reach is either dead or a feature
      // someone forgot to wire up, and both want a decision rather than a
      // resting place.
      final imports = RegExp(
        '''import\\s+['"]([^'"]+)['"]''',
        multiLine: true,
      );

      String? resolve(String from, String uri) {
        if (uri.startsWith('package:speakwise/')) {
          return 'lib/${uri.substring('package:speakwise/'.length)}';
        }
        if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
        // Relative: resolve against the importing file's directory.
        final segments = [
          ...from.split('/')..removeLast(),
          ...uri.split('/'),
        ];
        final stack = <String>[];
        for (final segment in segments) {
          if (segment == '.' || segment.isEmpty) continue;
          if (segment == '..') {
            if (stack.isNotEmpty) stack.removeLast();
            continue;
          }
          stack.add(segment);
        }
        return stack.join('/');
      }

      final reached = <String>{};
      final queue = <String>['lib/main.dart'];
      while (queue.isNotEmpty) {
        final path = queue.removeLast();
        if (!reached.add(path)) continue;
        final file = File(path);
        if (!file.existsSync()) continue;
        for (final match in imports.allMatches(codeOf(file))) {
          final target = resolve(path, match.group(1)!);
          if (target != null && target.startsWith('lib/')) queue.add(target);
        }
      }

      final orphans = [
        for (final file in libFiles)
          if (!reached.contains(relativePath(file))) relativePath(file),
      ];

      final unexpected = orphans
          .where((p) => !_expectedOrphans.containsKey(p))
          .map((p) => '$p — nothing reaches it')
          .toList();

      // A quarantine that is allowed to hold entries after they are resolved
      // is a list nobody reads. If a file here becomes reachable, or is
      // deleted, the entry has done its job and must go with it.
      final stale = [
        for (final entry in _expectedOrphans.entries)
          if (!orphans.contains(entry.key))
            '${entry.key} — no longer an orphan (or no longer exists); remove '
                'it from _expectedOrphans',
      ];

      expect(
        [...unexpected, ...stale],
        isEmpty,
        reason:
            'Nothing imports these, directly or transitively, from main.dart. '
            'Wire them up or delete them — a file that cannot be reached is '
            'covered by no other rule here, which is how 470 lines of '
            'image-generation UI survived §2.2. If it is genuinely waiting on '
            'a milestone, name it in _expectedOrphans with the reason:\n'
            '${[...unexpected, ...stale].join('\n')}',
      );
    });

    test('android and ios are the only platform folders', () {
      for (final gone in ['web', 'windows', 'macos', 'linux']) {
        expect(
          Directory(gone).existsSync(),
          isFalse,
          reason: '$gone/ was deleted in Milestone 1 (PRD §2.2)',
        );
      }
      expect(Directory('android').existsSync(), isTrue);
      expect(Directory('ios').existsSync(), isTrue);
    });
  });

  group('PRD §16 — no print in release', () {
    test('lib/ uses Log, not print or debugPrint', () {
      final pattern = RegExp(r'(?<![\w.])(print|debugPrint)\s*\(');
      final offenders = <String>[];
      for (final entity in libFiles) {
        if (entity.path.endsWith('log.dart')) continue;
        if (pattern.hasMatch(codeOf(entity))) offenders.add(entity.path);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use Log, which compiles out in release:\n${offenders.join('\n')}',
      );
    });
  });
}
