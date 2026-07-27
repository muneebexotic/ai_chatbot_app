import 'dart:math' as math;

import 'package:flutter/material.dart';

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
/// [amplitudes] is a rolling window of normalised loudness in `0.0..1.0`,
/// oldest first. It comes from one of three places, and the painter neither
/// knows nor cares which:
///
/// * **Live capture** — `speech_to_text`'s `onSoundLevelChange`, normalised.
///   That callback reports roughly `-2..10` on Android, so the caller maps it;
///   the mapping lives with the caller because it is platform-specific and
///   this class must stay pure.
/// * **Playback** — the stored per-bar envelope of a past session.
/// * **Idle** — an empty list. The painter then synthesises a calm wave from
///   [phase] alone, so callers never special-case "no data".
///
/// ## Performance
///
/// R11.2 requires a steady 60fps and repaint via a painter driven by a single
/// ticker, never by rebuilding widgets per frame. This class holds no state
/// and allocates no objects per frame beyond the `Paint` it must; [shouldRepaint]
/// compares cheaply.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.amplitudes,
    required this.mode,
    required this.phase,
    required this.signalColor,
    required this.liveColor,
    required this.mutedColor,
    this.barCount = 48,
    this.reduceMotion = false,
    this.progress,
  });

  /// Rolling amplitude window, oldest first, each `0.0..1.0`. May be empty.
  final List<double> amplitudes;

  final WaveformMode mode;

  /// Monotonically increasing animation phase in radians, from the owning
  /// ticker. Only used for synthesised motion (idle/speaking).
  final double phase;

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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;
    final slot = size.width / barCount;
    // Half the slot for the bar, half for the gap, and never thinner than a
    // physical hairline or it disappears on low-density screens.
    final barWidth = math.max(1.0, slot * 0.5);
    final maxAmplitude = centerY;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < barCount; i++) {
      final t = barCount == 1 ? 0.0 : i / (barCount - 1);
      final amplitude = _amplitudeAt(i, t);

      // Keep a visible floor so the component never reads as broken or empty.
      final barHeight = math.max(2.0, amplitude * maxAmplitude);
      final x = slot * i + slot / 2;

      paint.color = _colorFor(t);

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  /// Normalised amplitude for bar [i], where [t] is its position `0..1`.
  double _amplitudeAt(int i, double t) {
    if (amplitudes.isNotEmpty) {
      // Map bar index onto the amplitude window. Nearest-sample rather than
      // interpolated: interpolation smooths away the transients that make a
      // voice look like a voice.
      final index = ((amplitudes.length - 1) * t).round().clamp(
        0,
        amplitudes.length - 1,
      );
      return amplitudes[index].clamp(0.0, 1.0);
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
        math.sin(t * math.pi * 3 - phase) * 0.6 +
        math.sin(t * math.pi * 5.3 - phase * 1.7) * 0.4;

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

  @override
  bool shouldRepaint(covariant WaveformPainter old) =>
      old.phase != phase ||
      old.mode != mode ||
      old.progress != progress ||
      old.barCount != barCount ||
      old.reduceMotion != reduceMotion ||
      old.signalColor != signalColor ||
      old.liveColor != liveColor ||
      old.mutedColor != mutedColor ||
      !identical(old.amplitudes, amplitudes);

  @override
  bool shouldRebuildSemantics(covariant WaveformPainter oldDelegate) => false;
}
