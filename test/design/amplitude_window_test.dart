import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/waveform/waveform.dart';
import 'package:speakwise/design/waveform/waveform_painter.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// Capturing mode renders the LIVE label from the ARB (R11.7), so a host
/// without delegates throws on build. Same harness as
/// `waveform_live_indicator_test.dart`.
Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [AppColors.dark]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// R7.5.1 ("animating from real microphone amplitude at 60fps") and R11.2
/// ("MUST repaint via a `CustomPainter` driven by a single ticker, never by
/// rebuilding widgets per frame").
///
/// The second half of that sentence is the part that had never been tested, and
/// the part the previous implementation broke: an `AnimatedBuilder` around the
/// `CustomPaint` rebuilt a widget and allocated a painter sixty times a second.
/// It looked correct, it satisfied "driven by a ticker", and nothing in the
/// suite could tell. The last group here is the executable version of the rule.
void main() {
  group('AmplitudeWindow — the rolling buffer', () {
    test('a new window has no data, so the painter draws its idle wave', () {
      final window = AmplitudeWindow(capacity: 8);
      expect(window.hasData, isFalse);
      expect(window.sample(0.5), 0);
    });

    test('push does not take effect until advance', () {
      // Deliberate: the reading becomes visible on the next ticker frame, so
      // repaints stay on the ticker's rhythm instead of being scheduled by the
      // microphone's callback rate.
      final window = AmplitudeWindow(capacity: 8, smoothing: 1);
      window.push(1);
      expect(window.hasData, isFalse);

      window.advance();
      expect(window.hasData, isTrue);
      expect(window.sample(1), closeTo(1, 0.0001));
    });

    test('samples ease toward the target rather than jumping', () {
      // A microphone reporting 15 levels a second drawn raw at 60fps steps
      // visibly, which reads as a dropped frame rather than a quiet moment.
      final window = AmplitudeWindow(capacity: 64, smoothing: 0.5);
      window.push(1);

      window.advance();
      final first = window.sample(1);
      window.advance();
      final second = window.sample(1);

      expect(first, closeTo(0.5, 0.0001));
      expect(second, closeTo(0.75, 0.0001));
      expect(second, greaterThan(first));
    });

    test('the newest sample is at t=1 and the oldest at t=0', () {
      final window = AmplitudeWindow(capacity: 4, smoothing: 1);
      // Fill it with a rising ramp.
      for (final level in [0.1, 0.2, 0.3, 0.4]) {
        window.push(level);
        window.advance();
      }
      expect(window.sample(0), closeTo(0.1, 0.0001));
      expect(window.sample(1), closeTo(0.4, 0.0001));
    });

    test('it wraps without losing order once full', () {
      // The ring is the whole point; an off-by-one in the wrap would show as a
      // waveform that jumps back in time once every capacity frames.
      final window = AmplitudeWindow(capacity: 3, smoothing: 1);
      for (final level in [0.1, 0.2, 0.3, 0.4, 0.5]) {
        window.push(level);
        window.advance();
      }
      // Only the last three survive, oldest first.
      expect(window.toList(3), [
        closeTo(0.3, 0.0001),
        closeTo(0.4, 0.0001),
        closeTo(0.5, 0.0001),
      ]);
    });

    test('a settled silent window stops notifying', () {
      // Note what this does and does not buy. While the Waveform's ticker runs
      // it notifies every frame anyway, so this saves nothing there. It matters
      // wherever a window outlives its animation — a paused session, a
      // backgrounded one (R4.2.6), or reduce-motion, where the ticker is
      // stopped and a silent window must not keep asking for frames on its own.
      final window = AmplitudeWindow(capacity: 4, smoothing: 1);
      window.push(0);
      // Fill it so the "settled" test can apply.
      for (var i = 0; i < 8; i++) {
        window.advance();
      }
      expect(window.advance(), isFalse);

      // A real reading wakes it up again.
      window.push(0.8);
      expect(window.advance(), isTrue);
    });

    test('reset clears it, so a paused session stops showing the last sound', () {
      final window = AmplitudeWindow(capacity: 4, smoothing: 1);
      window.push(0.9);
      window.advance();
      expect(window.hasData, isTrue);

      window.reset();
      expect(window.hasData, isFalse);
      expect(window.sample(1), 0);
    });

    test('out-of-range levels are clamped, not trusted', () {
      // Platform sound levels are documented ranges, not guarantees.
      final window = AmplitudeWindow(capacity: 4, smoothing: 1);
      window.push(5);
      window.advance();
      expect(window.sample(1), 1.0);
    });
  });

  group('AmplitudeWindow.fixed — marks and stored envelopes', () {
    test('reads its values and never notifies', () {
      final window = AmplitudeWindow.fixed([0.2, 0.5, 0.9]);
      expect(window.isFixed, isTrue);
      expect(window.hasData, isTrue);
      expect(window.sample(0), 0.2);
      expect(window.sample(1), 0.9);

      var notified = false;
      window.addListener(() => notified = true);
      window.push(1);
      expect(window.advance(), isFalse);
      window.reset();
      expect(notified, isFalse);
    });

    test('an empty fixed window has no data', () {
      final window = AmplitudeWindow.fixed(const []);
      expect(window.hasData, isFalse);
      expect(window.sample(0.5), 0);
    });
  });

  group('R11.2 — the waveform does not rebuild a widget per frame', () {
    /// The painter currently mounted, by identity.
    ///
    /// A rebuild constructs a new `WaveformPainter`. So if this object is the
    /// same across frames, `build` did not run — which is the property R11.2
    /// asks for, stated in the only terms a test can observe.
    WaveformPainter painterIn(WidgetTester tester) {
      final paints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((p) => p.painter is WaveformPainter);
      expect(paints, hasLength(1));
      return paints.first.painter! as WaveformPainter;
    }

    testWidgets('the painter object survives sixty frames of animation', (
      tester,
    ) async {
      final window = AmplitudeWindow(capacity: 32);

      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Waveform(
              amplitudes: window,
              mode: WaveformMode.capturing,
              height: 96,
            ),
          ),
        ),
      );

      final first = painterIn(tester);

      for (var frame = 0; frame < 60; frame++) {
        window.push(frame.isEven ? 0.8 : 0.2);
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        identical(painterIn(tester), first),
        isTrue,
        reason:
            'A new WaveformPainter means Waveform.build ran again. R11.2 '
            'forbids a per-frame widget rebuild; the painter must be driven by '
            'its repaint: listenable instead.',
      );
    });

    testWidgets('the single ticker advances the amplitude window', (
      tester,
    ) async {
      // The other half of the same design: one ticker drives the synthesised
      // phase AND the amplitude easing, so a live waveform never needs a
      // second one.
      final window = AmplitudeWindow(capacity: 32, smoothing: 0.5);

      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Waveform(amplitudes: window, mode: WaveformMode.capturing),
          ),
        ),
      );

      window.push(1);
      expect(window.hasData, isFalse, reason: 'not until a frame elapses');

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        window.hasData,
        isTrue,
        reason:
            'The Waveform ticker must call advance(); without it the window '
            'only moves when something else happens to pump it.',
      );
    });

    testWidgets('a rebuild with the same window keeps the same window identity', (
      tester,
    ) async {
      // shouldRepaint compares the window by identity, so a caller that
      // constructs a new AmplitudeWindow in build() would defeat it. This pins
      // the contract that callers hold theirs.
      final window = AmplitudeWindow(capacity: 16);

      Widget build(WaveformMode mode) =>
          _host(Scaffold(body: Waveform(amplitudes: window, mode: mode)));

      await tester.pumpWidget(build(WaveformMode.idle));
      final before = painterIn(tester).amplitudes;

      await tester.pumpWidget(build(WaveformMode.capturing));
      expect(identical(painterIn(tester).amplitudes, before), isTrue);
    });
  });
}
