import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chatbot_app/design/theme/kalaam_theme.dart';
import 'package:ai_chatbot_app/design/waveform/waveform.dart';
import 'package:ai_chatbot_app/features/chat/domain/chat_message.dart';
import 'package:ai_chatbot_app/features/chat/presentation/widgets/ai_turn.dart';
import 'package:ai_chatbot_app/features/chat/presentation/widgets/user_turn.dart';
import 'package:ai_chatbot_app/l10n/app_localizations.dart';

/// Widget tests for the chat surface (PRD §7.4, §14).
///
/// ## Why these exist, specifically
///
/// Both defects below shipped to a device and were found by looking at a
/// screenshot, which is the third milestone running that this has happened
/// (CRITIQUE W2.1). Both are also **layout** bugs, which is the category unit
/// tests structurally cannot see and the category Flutter makes easiest to
/// write: constraints flow down, sizes flow up, and getting either direction
/// wrong produces something that compiles, analyses clean, and renders nothing.
///
/// The important property of these tests is that they pump the widgets inside a
/// **`ListView`**, because that is where both bugs lived. A `ListView` hands its
/// items a tight cross-axis constraint and an unbounded main-axis one, and
/// neither widget behaved correctly under that pair. Testing them in a bare
/// `Scaffold` would have passed while the app showed a blank screen.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: KalaamTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // The real parent. Not a Scaffold, not a Center.
    home: Scaffold(body: ListView(children: [child])),
  );

  ChatMessage assistant(String content, {bool streaming = false}) => ChatMessage(
    id: 'a1',
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime(2026),
    isStreaming: streaming,
  );

  group('AiTurn (R7.4.1)', () {
    testWidgets('the reply is actually visible', (tester) async {
      // THE REGRESSION. The first version used
      // `Row(crossAxisAlignment: stretch)` to hold the signal rule beside the
      // text. `stretch` takes a tight cross-axis constraint from the Row's own
      // height, and a Row in a vertical ListView has no bounded height to take
      // it from — so every AI turn laid out at zero height. The message was in
      // state, the server had stored it, `flutter analyze` was clean, and the
      // screen was blank.
      await tester.pumpWidget(
        host(AiTurn(message: assistant('Design a system that scales.'))),
      );

      final size = tester.getSize(find.byType(AiTurn));
      expect(
        size.height,
        greaterThan(16),
        reason: 'an AI turn that lays out at zero height renders nothing',
      );
      expect(find.textContaining('Design a system'), findsOneWidget);
    });

    testWidgets('a streaming turn withholds the trailing partial word', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AiTurn(message: assistant('Tell me about inter', streaming: true))),
      );
      expect(find.textContaining('Tell me about'), findsOneWidget);
      expect(find.textContaining('inter'), findsNothing);
    });

    testWidgets('the turn is full width, unlike the user bubble', (
      tester,
    ) async {
      // R7.4.1's asymmetry is the identity: "the AI is publishing, the user is
      // speaking". If the two ever render at the same width the design reads
      // as two chat bubbles in different fonts, which is what every other app
      // ships and what R0.5.6 exists to prevent.
      // Two separate list items, exactly as the transcript builds them. A
      // `Column` would hand both children *loose* width constraints and let
      // each shrink to its content, which is not the situation either widget
      // is ever in — and the difference is the whole point of the assertion.
      await tester.pumpWidget(
        MaterialApp(
          theme: KalaamTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                AiTurn(message: assistant('A reasonably long assistant reply.')),
                UserTurn(
                  message: ChatMessage(
                    id: 'u1',
                    role: ChatRole.user,
                    content: 'A reasonably long assistant reply.',
                    createdAt: DateTime(2026),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final ai = tester.getSize(find.byType(AiTurn)).width;
      final user = tester.getSize(find.byType(UserTurn)).width;
      // The painted bubble, not the row it sits in. `UserTurn` fills the row
      // and aligns a capped-width box inside it, so measuring the outer widget
      // would compare two full-width rows and prove nothing.
      final userBubble = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(UserTurn),
                  matching: find.byType(Container),
                )
                .first,
          )
          .width;

      expect(ai, equals(user), reason: 'both occupy the full row');
      expect(
        userBubble,
        lessThan(ai * 0.85),
        reason: 'the user bubble must stay visibly narrower than the AI column',
      );
    });

    testWidgets('long unbroken text does not overflow', (tester) async {
      // CRITIQUE F3: fenced code clipped mid-word at the right edge in both
      // modes with no way to scroll. It was left standing because §7.4 was
      // going to rewrite this surface; this is the rewrite, so it is asserted.
      await tester.pumpWidget(
        host(
          AiTurn(
            message: assistant(
              '```\nsession 04 · 6m 12s · fillers 7/min · pace 118wpm · '
              'talk-time 62% · vocabulary 0.41\n```',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the thinking indicator (§16, R7.5.2)', () {
    testWidgets('is a compact waveform, not a full-width bar', (tester) async {
      // THE SECOND REGRESSION. `SizedBox(width: 72)` inside a ListView item
      // does nothing: the item's cross-axis constraint is TIGHT, and SizedBox
      // enforces its own constraints within the incoming ones, so 72 clamps
      // back up to the viewport width. On device it drew fourteen fat amber
      // pills across the whole screen.
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 72,
              child: Waveform(mode: WaveformMode.idle, height: 24, barCount: 14),
            ),
          ),
        ),
      );

      final width = tester.getSize(find.byType(Waveform)).width;
      expect(
        width,
        closeTo(72, 1),
        reason:
            'the loading state must stay small; a full-width amber bar is not '
            'a waveform idling, it is a progress bar wearing its clothes',
      );
    });

    testWidgets('no CircularProgressIndicator reaches the chat surface', (
      tester,
    ) async {
      // §16 bans a spinner anywhere the waveform can idle instead. Asserted at
      // the widget level rather than trusted to code review, because the
      // easiest way to reintroduce one is to accept a Material default.
      await tester.pumpWidget(
        host(AiTurn(message: assistant('anything', streaming: true))),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
