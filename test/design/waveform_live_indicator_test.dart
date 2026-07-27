import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/waveform/waveform.dart';

/// The live-microphone state must be perceivable without colour.
///
/// R7.1.1 requires a user to tell from across the room whether the mic is hot.
/// WCAG 1.4.1 forbids colour being the only carrier of that information, and
/// `signal` amber and `live` red differ almost purely in hue — so a red-green
/// colourblind user, or anyone in bright sunlight, gets nothing from the
/// colour change alone.
///
/// These tests assert the channels that survive when colour does not.
Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [AppColors.dark]),
  home: Scaffold(body: child),
);

void main() {
  group('live-microphone indicator (R7.1.1, WCAG 1.4.1)', () {
    testWidgets('shows a text label while capturing', (tester) async {
      await tester.pumpWidget(
        _host(const Waveform(mode: WaveformMode.capturing)),
      );
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('shows no label in any non-capturing mode', (tester) async {
      for (final mode in [
        WaveformMode.idle,
        WaveformMode.speaking,
        WaveformMode.static_,
      ]) {
        await tester.pumpWidget(_host(Waveform(mode: mode)));
        await tester.pump();
        expect(
          find.text('LIVE'),
          findsNothing,
          reason: '$mode must not claim the microphone is live',
        );
      }
    });

    testWidgets('label survives reduce-motion', (tester) async {
      // The important one. R7.7.4 disables animation, so if the second channel
      // were motion it would vanish for exactly the users who most need a
      // non-colour cue. Shape and text are static facts.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _host(const Waveform(mode: WaveformMode.capturing)),
        ),
      );
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('announces the live state to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const Waveform(mode: WaveformMode.capturing)),
      );
      expect(
        find.bySemanticsLabel(RegExp('Microphone live')),
        findsOneWidget,
        reason:
            'A non-sighted user cannot infer the microphone state any other '
            'way (§11.6)',
      );
      handle.dispose();
    });

    testWidgets('does not announce live when idle', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const Waveform(mode: WaveformMode.idle, semanticLabel: 'Waveform')),
      );
      expect(find.bySemanticsLabel(RegExp('Microphone live')), findsNothing);
      handle.dispose();
    });

    testWidgets('renders in both themes without overflow', (tester) async {
      for (final colors in [AppColors.dark, AppColors.light]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [colors]),
            home: const Scaffold(
              body: Waveform(mode: WaveformMode.capturing),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
