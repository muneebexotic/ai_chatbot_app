import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:speakwise/design/waveform/amplitude_window.dart';

/// What the waveform is currently expressing.
///
/// The mode drives colour and behaviour together, because in this app they
/// mean the same thing: amber is the app talking or waiting, red is the
/// microphone being live (R7.1.1).
enum WaveformMode {
  /// Nothing happening. A calm, slow oscillation — this is also the app's
  /// loading state. R7.5.2 and §16: never a spinner where the waveform can
  /// idle instead.
  idle,

  /// The microphone is capturing. The ONLY mode that paints [live] red.
  capturing,

  /// Thinking, or the AI is speaking. Amber, driven by output amplitude when
  /// available and by a gentle idle wave when not.
  speaking,

  /// A finished recording rendered as a static shape: report timelines and
  /// history row thumbnails. Each session's shape is unique, which is what
  /// makes history feel personal (R7.5.2).
  static_,
}

/// The single waveform renderer for the entire app (PRD §7.5).
///
/// R7.5.3 requires this to be one `CustomPainter` with a documented amplitude
/// source, so that every use — the live session visual, the record button, the
/// loading state, the playback scrubber, the history thumbnail, the app icon
/// shape — is literally the same code. **Never add a second visualization
/// style.**
///
/// ## Amplitude source
///
/// [amplitudes] is an [AmplitudeWindow] of normalised loudness in `0.0..1.0`,
/// oldest first. It carries one of three things, and the painter neither knows
/// nor cares which:
///
/// * **Live capture** — `speech_to_text`'s `onSoundLevelChange`, normalised.
///   That callback reports roughly `-2..10` on Android, so the *caller* maps
///   it; the mapping lives in `SpeechRecognitionService` because it is
///   platform-specific and this class must stay pure.
/// * **Playback** — the stored per-bar envelope of a past session, as
///   `AmplitudeWindow.fixed`.
/// * **Idle** — a window with no data. The painter then synthesises a calm wave
///   from [phase] alone, so callers never special-case "nothing to draw".
///
/// ## Performance — this is the R11.2 mechanism, not an implementation detail
///
/// R11.2: "The waveform MUST repaint via a `CustomPainter` driven by a single
/// ticker, **never by rebuilding widgets per frame**."
///
/// Both [phase] and [amplitudes] are `Listenable`s, and they are handed to
/// `CustomPainter`'s `repaint:` constructor argument. A painter built that way
/// is repainted by the framework when the listenable fires, marking only the
/// `RenderCustomPaint` dirty — no `setState`, no element rebuild, no new
/// painter object, and no new `List` per frame.
///
/// The previous version wrapped the `CustomPaint` in an `AnimatedBuilder` and
/// passed a `double phase` and a `List<double>`. That rebuilt a widget and
/// allocated a painter sixty times a second, which is the exact thing the
/// requirement names. Reading the values through listenables at paint time is
/// what removes it.
///
/// Consequence worth stating: [phase] and [amplitudes] are read inside [paint],
/// so they must not be captured into local fields at construction, and
/// [shouldRepaint] does not compare them — the `repaint:` listenable already
/// covers changes to their *values*, and comparing a mutable buffer by identity
/// would always say "unchanged".
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.amplitudes,
    required this.mode,
    required this.phase,
    required this.signalColor,
    required this.liveColor,
    required this.mutedColor,
    this.barCount = 48,
    this.reduceMotion = false,
    this.progress,
  }) : super(repaint: Listenable.merge([phase, amplitudes]));

  /// Rolling amplitude window. Read at paint time, never copied.
  final AmplitudeWindow amplitudes;

  final WaveformMode mode;

  /// The owning ticker, as a listenable `0..1`. Converted to radians in
  /// [paint]. Only used for synthesised motion (idle/speaking).
  final Animation<double> phase;

  final Color signalColor;
  final Color liveColor;
  final Color mutedColor;

  /// How many bars to draw. Fewer on small targets like a history thumbnail.
  final int barCount;

  /// When true, no synthesised motion is drawn at all: R7.7.4 requires the
  /// waveform to become a static level bar rather than an amplitude
  /// animation, and requires that nothing animates position.
  final bool reduceMotion;

  /// Playback position in `0.0..1.0` for scrubber use. Bars before this point
  /// paint at full colour, bars after paint muted.
  final double? progress;

  Color get _activeColor =>
      mode == WaveformMode.capturing ? liveColor : signalColor;

  /// Radius of the record dot drawn while capturing. Zero in every other mode.
  ///
  /// This is the **shape** channel of the live-microphone indicator. See
  /// [paint] for why colour alone is not sufficient.
  static const double recordDotRadius = 5.0;
  static const double _recordDotGap = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;

    // ── The live-microphone indicator is NOT colour alone ──────────────────
    //
    // R7.1.1 requires a user to tell from across the room whether the mic is
    // hot, and WCAG 1.4.1 forbids colour as the only carrier of that state.
    // `signal` amber and `live` red differ almost entirely in hue: for a
    // red-green colourblind user, in bright sunlight, or on a washed-out
    // screen they are close to indistinguishable. (Their WCAG contrast ratio
    // against each other is 1.19:1 in light mode — a luminance measure, and
    // the wrong test for two accents, but it does show they carry no
    // brightness difference to fall back on.)
    //
    // So capturing gets three simultaneous channels:
    //   1. colour  — `live` red                     (this file)
    //   2. shape   — a solid record dot appears      (this file, below)
    //   3. text    — a "LIVE" label                  (Waveform widget)
    //
    // Motion is deliberately NOT one of them. R7.7.4 disables animation under
    // reduce-motion, so a motion-only second channel disappears for exactly
    // the users most likely to need it. The dot and the label are static
    // facts; the pulse is decoration on top.
    var barsLeft = 0.0;
    if (mode == WaveformMode.capturing) {
      final dotPaint = Paint()
        ..color = liveColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(recordDotRadius, centerY),
        recordDotRadius,
        dotPaint,
      );
      barsLeft = recordDotRadius * 2 + _recordDotGap;
    }

    final barsWidth = size.width - barsLeft;
    if (barsWidth <= 0) return;
    final slot = barsWidth / barCount;
    // Half the slot for the bar, half for the gap, and never thinner than a
    // physical hairline or it disappears on low-density screens.
    final barWidth = math.max(1.0, slot * 0.5);
    final maxAmplitude = centerY;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..style = PaintingStyle.stroke;

    // Read once per frame, not once per bar.
    final radians = phase.value * 2 * math.pi;

    for (var i = 0; i < barCount; i++) {
      final t = barCount == 1 ? 0.0 : i / (barCount - 1);
      final amplitude = _amplitudeAt(t, radians);

      // Keep a visible floor so the component never reads as broken or empty —
      // but a floor proportional to the height, not a fixed 2.0.
      //
      // A fixed floor is invisible at the 96dp session size and total at the
      // 24dp loading size: idle amplitude tops out at 0.22, so on a 24dp
      // waveform every bar computed between 0.24 and 2.64 and `max(2.0, …)`
      // flattened almost all of them to exactly 2.0. The chat "thinking"
      // indicator drew fourteen identical bars — a pulsing block where §7.5.2
      // asks for "a calm idle oscillation". Found by looking at it on a phone;
      // the maths reads fine either way.
      final floor = math.max(1.0, size.height * 0.03);
      final barHeight = math.max(floor, amplitude * maxAmplitude);
      final x = barsLeft + slot * i + slot / 2;

      paint.color = _colorFor(t);

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  /// Normalised amplitude for the bar at position [t] (`0..1`).
  double _amplitudeAt(double t, double radians) {
    if (amplitudes.hasData) {
      // Nearest-sample rather than interpolated: interpolation across bars
      // smooths away the transients that make a voice look like a voice. The
      // smoothing that does happen is temporal and lives in AmplitudeWindow,
      // where it is one exponential step per frame toward the real reading.
      return amplitudes.sample(t).clamp(0.0, 1.0);
    }

    // No data. Static modes get a flat level bar; R7.7.4 requires the same
    // when reduce-motion is on.
    if (reduceMotion || mode == WaveformMode.static_) {
      return 0.18;
    }

    // Synthesised idle wave. Two summed sines at incommensurate frequencies so
    // the pattern does not visibly repeat, plus an envelope that tapers the
    // ends — a wave that runs flat into the edges looks clipped.
    final envelope = math.sin(t * math.pi);
    final wave =
        math.sin(t * math.pi * 3 - radians) * 0.6 +
        math.sin(t * math.pi * 5.3 - radians * 1.7) * 0.4;

    final scale = switch (mode) {
      WaveformMode.idle => 0.22,
      WaveformMode.speaking => 0.5,
      WaveformMode.capturing => 0.5,
      WaveformMode.static_ => 0.18,
    };

    return (wave.abs() * envelope * scale).clamp(0.02, 1.0);
  }

  Color _colorFor(double t) {
    final p = progress;
    if (p != null && t > p) return mutedColor;
    return _activeColor;
  }

  /// Only the *configuration* is compared here.
  ///
  /// [phase] and [amplitudes] are deliberately absent: their changing values
  /// already drive repaints through the `repaint:` listenable passed to the
  /// superclass, and comparing a mutable buffer by identity would report
  /// "unchanged" on every frame while its contents moved. Comparing them by
  /// value would allocate, per frame, to answer a question already answered.
  @override
  bool shouldRepaint(covariant WaveformPainter old) =>
      old.mode != mode ||
      old.progress != progress ||
      old.barCount != barCount ||
      old.reduceMotion != reduceMotion ||
      old.signalColor != signalColor ||
      old.liveColor != liveColor ||
      old.mutedColor != mutedColor ||
      !identical(old.phase, phase) ||
      !identical(old.amplitudes, amplitudes);

  @override
  bool shouldRebuildSemantics(covariant WaveformPainter oldDelegate) => false;
}
