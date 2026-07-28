import 'package:flutter/material.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/tokens/app_metrics.dart';
import 'package:ai_chatbot_app/design/tokens/app_typography.dart';
import 'package:ai_chatbot_app/design/waveform/waveform_painter.dart';
import 'package:ai_chatbot_app/l10n/app_localizations.dart';

export 'package:ai_chatbot_app/design/waveform/waveform_painter.dart'
    show WaveformMode;

/// The app's signature element (PRD §7.5), and the only visualization style it
/// has.
///
/// Owns exactly one [Ticker] via [SingleTickerProviderStateMixin] and drives
/// [WaveformPainter] through it. R11.2 requires repaint via a painter on a
/// single ticker rather than a widget rebuild per frame — so this widget's
/// `build` runs once per configuration change, not once per frame. The
/// [AnimatedBuilder] listens to the controller and only the [CustomPaint]
/// subtree is re-laid-out.
///
/// The ticker is stopped whenever motion would be pointless — static mode, or
/// reduce-motion — which is also what keeps R11.4's battery budget reachable
/// during a 20-minute session.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    this.amplitudes = const [],
    this.mode = WaveformMode.idle,
    this.barCount = 48,
    this.progress,
    this.height = 96,
    this.semanticLabel,
  });

  /// Normalised loudness, oldest first. See [WaveformPainter] for the sources.
  final List<double> amplitudes;

  final WaveformMode mode;
  final int barCount;

  /// Playback position `0..1` when used as a scrubber.
  final double? progress;

  final double height;

  /// §11.6 requires every meaningful element to be labelled. Pass null only
  /// when the waveform is purely decorative and something adjacent already
  /// announces the state.
  final String? semanticLabel;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Duration sets the period of the synthesised idle wave. It repeats
    // rather than resetting, so phase is continuous and the wave never jumps.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _syncTicker();
  }

  /// Runs the ticker only when it changes what is on screen. A repeating
  /// controller nobody can see is pure battery cost.
  void _syncTicker() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shouldAnimate =
        !reduceMotion && widget.mode != WaveformMode.static_;

    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final isCapturing = widget.mode == WaveformMode.capturing;

    final painter = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: WaveformPainter(
              amplitudes: widget.amplitudes,
              mode: widget.mode,
              phase: _controller.value * 2 * 3.141592653589793,
              signalColor: colors.signal,
              liveColor: colors.live,
              mutedColor: colors.line,
              barCount: widget.barCount,
              reduceMotion: reduceMotion,
              progress: widget.progress,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      // Announced to screen readers, and it changes when the mic opens or
      // closes — §11.6 requires the session screen to announce state changes.
      // The mic being live is the one state a non-sighted user cannot infer
      // any other way.
      label: isCapturing
          ? AppLocalizations.of(context)
                .waveformLiveSemantics(widget.semanticLabel ?? '')
                .trim()
          : widget.semanticLabel,
      liveRegion: isCapturing,
      // The bars are a per-frame readout; describing them frame by frame would
      // be noise. The label above carries the meaning.
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The TEXT channel of the live indicator (WCAG 1.4.1). Together with
          // the record dot drawn by the painter, this means the microphone
          // state is legible without perceiving colour at all — which matters
          // for red-green colourblind users, in bright sunlight, and on a
          // washed-out screen. See the long note in WaveformPainter.paint.
          if (isCapturing)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xxs),
              child: Text(
                AppLocalizations.of(context).waveformLive,
                style: AppTypography.micro.copyWith(
                  color: colors.live,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          painter,
        ],
      ),
    );
  }
}
