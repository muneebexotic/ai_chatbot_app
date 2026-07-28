import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/waveform/waveform.dart';
import 'package:ai_chatbot_app/l10n/app_localizations.dart';

/// The live-microphone state must be perceivable without colour.
///
/// R7.1.1 requires a user to tell from across the room whether the mic is hot.
/// WCAG 1.4.1 forbids colour being the only carrier of that information, and
/// `signal` amber and `live` red differ almost purely in hue — so a red-green
/// colourblind user, or anyone in bright sunlight, gets nothing from the
/// colour change alone.
///
/// These tests assert the channels that survive when colour does not.
///
/// ## Hosting
///
/// The delegates are not optional here. Since R11.7 the LIVE label comes from
/// the ARB rather than from a literal, so a host without them throws on build —
/// which is the right failure: a widget that renders copy needs localizations,
/// and discovering that in a test is cheaper than discovering it on a device.
Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [AppColors.dark]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// The expected label, read from the ARB rather than repeated here.
///
/// Asserting `find.text('LIVE')` against a literal would pass while the app
/// showed something else entirely — the test would be checking the test.
Future<String> _liveLabel(WidgetTester tester) async {
  late String label;
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) {
          label = AppLocalizations.of(context).waveformLive;
          return const SizedBox();
        },
      ),
    ),
  );
  return label;
}

void main() {
  group('live-microphone indicator (R7.1.1, WCAG 1.4.1)', () {
    testWidgets('shows a text label while capturing', (tester) async {
      final live = await _liveLabel(tester);
      await tester.pumpWidget(
        _host(const Waveform(mode: WaveformMode.capturing)),
      );
      expect(find.text(live), findsOneWidget);
    });

    testWidgets('shows no label in any non-capturing mode', (tester) async {
      final live = await _liveLabel(tester);
      for (final mode in [
        WaveformMode.idle,
        WaveformMode.speaking,
        WaveformMode.static_,
      ]) {
        await tester.pumpWidget(_host(Waveform(mode: mode)));
        await tester.pump();
        expect(
          find.text(live),
          findsNothing,
          reason: '$mode must not claim the microphone is live',
        );
      }
    });

    testWidgets('label survives reduce-motion', (tester) async {
      final live = await _liveLabel(tester);
      // The important one. R7.7.4 disables animation, so if the second channel
      // were motion it would vanish for exactly the users who most need a
      // non-colour cue. Shape and text are static facts.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _host(const Waveform(mode: WaveformMode.capturing)),
        ),
      );
      expect(find.text(live), findsOneWidget);
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
