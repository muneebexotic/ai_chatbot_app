import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/safety/crisis_detector.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';
import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/waveform/waveform_painter.dart';
import 'package:speakwise/features/session/application/session_controller.dart';
import 'package:speakwise/features/session/application/session_providers.dart';
import 'package:speakwise/features/session/domain/session_settings.dart';
import 'package:speakwise/features/session/domain/session_state.dart';
import 'package:speakwise/features/session/presentation/live_session_screen.dart';
import 'package:speakwise/features/session/presentation/widgets/session_transcript.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// §14: "widget tests for the session, report, and paywall screens."
///
/// The session is the first of the three to exist. CRITIQUE W3.1 is the reason
/// these are written the way they are: Milestone 3's three layout defects were
/// all invisible to `flutter analyze` and to a bare `Scaffold`, and two of them
/// only appeared because the widget was pumped inside the parent it actually
/// has. So the transcript here is pumped as the real `ListView` it is, and the
/// assertions are about what renders rather than about what the code says.
///
/// What these cannot do is the thing that has found every real defect on this
/// project: run the app. They are a floor, not the pass.
class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);

  final SessionState _initial;

  @override
  SessionState build() => _initial;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The UniqueKey is load-bearing, not decoration. Pumping a second
  // `ProviderScope` of the same type reuses the element, and Riverpod keeps the
  // container — so the fake controller from the FIRST pump survives and every
  // later state in a loop is silently ignored. A fresh key forces a new
  // element, a new container, and the state the test actually asked for.
  Widget host(SessionState state) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      sessionControllerProvider.overrideWith(
        () => _FakeSessionController(state),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: const [AppColors.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LiveSessionScreen(),
    ),
  );

  SessionState live({
    SessionPhase phase = SessionPhase.listening,
    List<SessionTurn> turns = const [],
    bool isMuted = false,
    SessionInputMode inputMode = SessionInputMode.handsFree,
    CrisisMatch? crisis,
    InterruptionReason? interruption,
    bool isEnvironmentNoisy = false,
    bool isTypingFallback = false,
    SessionUsage? usage,
    AppFailure? failure,
    Duration elapsed = const Duration(minutes: 4, seconds: 20),
  }) => SessionState(
    phase: phase,
    partnerName: 'Interviewer',
    localId: 'local-1',
    turns: turns,
    isMuted: isMuted,
    inputMode: inputMode,
    crisis: crisis,
    interruption: interruption,
    isEnvironmentNoisy: isEnvironmentNoisy,
    isTypingFallback: isTypingFallback,
    usage: usage,
    failure: failure,
    elapsed: elapsed,
  );

  SessionTurn turn(Speaker speaker, String text, {double confidence = 1}) =>
      SessionTurn(
        id: '$speaker-$text',
        speaker: speaker,
        text: text,
        startOffset: Duration.zero,
        duration: const Duration(seconds: 4),
        confidence: confidence,
      );

  WaveformPainter? waveformIn(WidgetTester tester) {
    final paints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.painter is WaveformPainter);
    return paints.isEmpty ? null : paints.first.painter! as WaveformPainter;
  }

  group('R4.2.1 — the live screen shows what the requirement lists', () {
    testWidgets('partner name, state, elapsed timer, and three controls', (
      tester,
    ) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(host(live()));

      expect(find.text('Interviewer'), findsOneWidget);
      expect(find.text(l10n.sessionStateListening), findsOneWidget);
      // §7.2 puts durations in mono. The value matters more than the font here:
      // a timer that does not tick is the bug this would catch.
      expect(find.text('04:20'), findsOneWidget);

      expect(find.text(l10n.sessionMute), findsOneWidget);
      expect(find.text(l10n.sessionModeHandsFree), findsOneWidget);
      expect(find.text(l10n.sessionEnd), findsOneWidget);
    });

    testWidgets('there is no navigation chrome', (tester) async {
      // R4.2.1: "Full-screen, single-purpose, no navigation chrome." An AppBar
      // creeping back in is the most likely regression on a screen like this,
      // because every other screen in the app has one.
      await tester.pumpWidget(host(live()));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('exactly three controls, not four', (tester) async {
      // The temptation on this screen is a settings gear, a partner switcher, a
      // skip. Each is a reason to look at the phone during a conversation meant
      // to happen out loud.
      await tester.pumpWidget(host(live()));
      expect(find.byType(InkWell), findsNWidgets(3));
    });

    testWidgets('the state label changes with the phase', (tester) async {
      final l10n = await _l10n(tester);

      for (final (phase, expected) in [
        (SessionPhase.thinking, l10n.sessionStateThinking),
        (SessionPhase.speaking, l10n.sessionStateSpeaking),
        (SessionPhase.starting, l10n.sessionStateStarting),
      ]) {
        await tester.pumpWidget(host(live(phase: phase)));
        expect(find.text(expected), findsOneWidget, reason: '$phase');
      }
    });
  });

  group('R7.1.1 — red means the microphone is hot, and nothing else', () {
    testWidgets('capturing only while listening and unmuted', (tester) async {
      await tester.pumpWidget(host(live(phase: SessionPhase.listening)));
      expect(waveformIn(tester)?.mode, WaveformMode.capturing);
    });

    testWidgets('muted while listening is NOT capturing', (tester) async {
      // The diegetic claim in R7.1.1 is that "a user should be able to tell
      // from across the room whether the mic is hot". Painting red over a muted
      // microphone would make that claim false in the one case where being
      // wrong matters.
      await tester.pumpWidget(
        host(live(phase: SessionPhase.listening, isMuted: true)),
      );
      expect(waveformIn(tester)?.mode, isNot(WaveformMode.capturing));
    });

    testWidgets('speaking and thinking are never capturing', (tester) async {
      for (final phase in [SessionPhase.speaking, SessionPhase.thinking]) {
        await tester.pumpWidget(host(live(phase: phase)));
        expect(
          waveformIn(tester)?.mode,
          isNot(WaveformMode.capturing),
          reason: '$phase must not paint the live indicator',
        );
      }
    });
  });

  group('R4.2.5 — the transcript', () {
    /// Pumped as the real widget, which IS a ListView — so its children get the
    /// tight cross-axis constraint that broke Milestone 3 twice.
    Widget transcript(List<SessionTurn> turns, {String partial = ''}) =>
        MaterialApp(
          theme: ThemeData(extensions: const [AppColors.dark]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SessionTranscript(turns: turns, partialText: partial),
          ),
        );

    testWidgets('both speakers render with non-zero height', (tester) async {
      // The exact defect from Milestone 3: every AI turn laid out at zero
      // height, silently, with analyze clean and the message present in state.
      await tester.pumpWidget(
        transcript([
          turn(Speaker.partner, 'Tell me about a project you are proud of.'),
          turn(Speaker.user, 'I built a scheduling tool for my team.'),
        ]),
      );

      for (final text in [
        'Tell me about a project you are proud of.',
        'I built a scheduling tool for my team.',
      ]) {
        expect(find.text(text), findsOneWidget);
        expect(
          tester.getSize(find.text(text)).height,
          greaterThan(0),
          reason: 'a turn rendered at zero height: "$text"',
        );
      }
    });

    testWidgets('a user turn is narrower than the full width, a partner turn is not', (
      tester,
    ) async {
      // §7.4.1's asymmetry is the app's identity: "the AI is publishing, the
      // user is speaking". If both render the same width, the identity is gone
      // and nothing else would notice.
      await tester.pumpWidget(
        transcript([
          turn(Speaker.partner, 'A reasonably long partner sentence here.'),
          turn(Speaker.user, 'Short answer.'),
        ]),
      );

      final width = tester.getSize(find.byType(SessionTranscript)).width;
      final userWidth = tester
          .getSize(find.ancestor(
            of: find.text('Short answer.'),
            matching: find.byType(Container),
          ).first)
          .width;

      expect(userWidth, lessThan(width * 0.85));
    });

    testWidgets('a live partial renders and is not yet a turn', (tester) async {
      await tester.pumpWidget(
        transcript([turn(Speaker.user, 'settled')], partial: 'still hearing'),
      );
      expect(find.text('still hearing'), findsOneWidget);
      expect(find.text('settled'), findsOneWidget);
    });

    testWidgets('a low-confidence line reveals the mishearing note on tap', (
      tester,
    ) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(
        transcript([turn(Speaker.user, 'ambiguous words', confidence: 0.3)]),
      );

      expect(find.text(l10n.sessionHeardPoorly), findsNothing);
      await tester.tap(find.text('ambiguous words'));
      await tester.pump();
      expect(find.text(l10n.sessionHeardPoorly), findsOneWidget);
    });

    testWidgets('a confident line has nothing to apologise for', (tester) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(
        transcript([turn(Speaker.user, 'clear words', confidence: 0.95)]),
      );
      await tester.tap(find.text('clear words'));
      await tester.pump();
      expect(find.text(l10n.sessionHeardPoorly), findsNothing);
    });
  });

  group('R10.6 — the crisis card is persistent', () {
    testWidgets('it appears when the state carries a match', (tester) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(
        host(live(crisis: const CrisisMatch(CrisisSignal.suicidalIntent))),
      );

      expect(find.text(l10n.sessionCrisisTitle), findsOneWidget);
      expect(find.text(l10n.sessionCrisisEmergency), findsOneWidget);
      expect(find.text(l10n.sessionCrisisDirectory), findsOneWidget);
    });

    testWidgets('it offers no way to dismiss it', (tester) async {
      // "Persistent" is the requirement's own word. A close button here would
      // satisfy the letter and defeat the point.
      await tester.pumpWidget(
        host(live(crisis: const CrisisMatch(CrisisSignal.hopelessness))),
      );
      expect(
        find.descendant(
          of: find.byType(Card).evaluate().isEmpty
              ? find.byType(Column).first
              : find.byType(Card),
          matching: find.byIcon(Icons.close_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('it is absent when nothing was detected', (tester) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(host(live()));
      expect(find.text(l10n.sessionCrisisTitle), findsNothing);
    });
  });

  group('R4.2.6 — a pause names its cause and offers resume', () {
    testWidgets('each interruption has its own sentence', (tester) async {
      final l10n = await _l10n(tester);

      for (final (reason, expected) in [
        (InterruptionReason.incomingCall, l10n.sessionInterruptedCall),
        (InterruptionReason.backgrounded, l10n.sessionInterruptedBackground),
        (
          InterruptionReason.headphonesDisconnected,
          l10n.sessionInterruptedHeadphones,
        ),
        (InterruptionReason.networkLost, l10n.sessionInterruptedNetwork),
        (
          InterruptionReason.microphoneLost,
          l10n.sessionInterruptedMicrophone,
        ),
      ]) {
        await tester.pumpWidget(
          host(live(phase: SessionPhase.paused, interruption: reason)),
        );
        // §7.6: an error states its cause AND its fix. A shared "Session
        // paused" for all five would satisfy neither.
        expect(find.text(expected), findsOneWidget, reason: '$reason');
        expect(find.text(l10n.sessionNothingLost), findsOneWidget);
        expect(find.text(l10n.sessionResume), findsOneWidget);
      }
    });
  });

  group('R4.2.2 and P8 — the noisy room offers three answers', () {
    testWidgets('push to talk, typing, and carrying on unchanged', (tester) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(host(live(isEnvironmentNoisy: true)));

      expect(find.text(l10n.sessionNoisyTitle), findsOneWidget);
      expect(find.text(l10n.sessionNoisySwitch), findsOneWidget);
      // PROPOSALS P8, approved for this milestone.
      expect(find.text(l10n.sessionNoisyType), findsOneWidget);
      // R4.2.2: "never a forced switch". Carrying on must be a real, visible
      // option rather than a dismissal X.
      expect(find.text(l10n.sessionNoisyDismiss), findsOneWidget);
    });

    testWidgets('push to talk shows the hold instruction', (tester) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(
        host(live(inputMode: SessionInputMode.pushToTalk)),
      );
      expect(find.text(l10n.sessionHoldToSpeak), findsWidgets);
    });

    testWidgets('the typing fallback replaces the controls, not adds to them', (
      tester,
    ) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(host(live(isTypingFallback: true)));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l10n.sessionBackToSpeaking), findsOneWidget);
      // Mute and the mode toggle have nothing to act on while typing.
      expect(find.text(l10n.sessionMute), findsNothing);
      expect(waveformIn(tester), isNull);
    });
  });

  group('§8 and §16 — the quota is shown late, and only by the server', () {
    testWidgets('nothing is shown with a full allowance', (tester) async {
      // §16 bans manufactured scarcity. A counter visible from the first second
      // turns every sentence into a transaction.
      await tester.pumpWidget(
        host(
          live(
            usage: const SessionUsage(
              tier: 'free',
              usedSeconds: 0,
              dailyLimitSeconds: 600,
              remainingSeconds: 600,
            ),
          ),
        ),
      );
      expect(find.textContaining('minutes left'), findsNothing);
    });

    testWidgets('the warning appears inside the last two minutes', (tester) async {
      final l10n = await _l10n(tester);
      await tester.pumpWidget(
        host(
          live(
            usage: const SessionUsage(
              tier: 'free',
              usedSeconds: 510,
              dailyLimitSeconds: 600,
              remainingSeconds: 90,
            ),
          ),
        ),
      );
      // Rounded up: "1 minute left" with 90 seconds remaining is a small lie in
      // the app's favour.
      expect(find.text(l10n.sessionRemaining(2)), findsOneWidget);
    });
  });

  group('R11.5 — a failure says which failure', () {
    testWidgets('offline and device failures read differently', (tester) async {
      final l10n = await _l10n(tester);

      await tester.pumpWidget(host(live(failure: const OfflineFailure())));
      expect(find.text(l10n.sessionInterruptedNetwork), findsOneWidget);

      await tester.pumpWidget(
        host(live(failure: const DeviceFailure(capability: 'speech'))),
      );
      expect(find.text(l10n.sessionInterruptedMicrophone), findsOneWidget);
    });
  });
}

/// Resolves the ARB strings, so assertions compare against the real copy rather
/// than against a literal repeated in the test — which would be the test
/// checking the test.
Future<AppLocalizations> _l10n(WidgetTester tester) async {
  late AppLocalizations value;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          value = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return value;
}
