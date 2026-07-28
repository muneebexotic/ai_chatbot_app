import 'package:flutter/material.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/design/waveform/amplitude_window.dart';
import 'package:speakwise/design/waveform/waveform_painter.dart';
import 'package:speakwise/l10n/app_localizations.dart';

export 'package:speakwise/design/waveform/amplitude_window.dart'
    show AmplitudeWindow;
export 'package:speakwise/design/waveform/waveform_painter.dart'
    show WaveformMode;

/// The app's signature element (PRD §7.5), and the only visualization style it
/// has.
///
/// Owns exactly one [Ticker] via [SingleTickerProviderStateMixin] and drives
/// [WaveformPainter] through it.
///
/// ## How R11.2 is actually satisfied
///
/// R11.2 requires repaint "via a `CustomPainter` driven by a single ticker,
/// never by rebuilding widgets per frame". The painter receives the animation
/// controller and the [AmplitudeWindow] as `Listenable`s and passes them to
/// `CustomPainter`'s `repaint:` argument, so the framework repaints it directly
/// and **this widget's `build` runs once per configuration change** — a theme
/// change, a mode change — rather than once per frame.
///
/// The earlier version used an `AnimatedBuilder`, which rebuilt the
/// `CustomPaint` widget and allocated a fresh `WaveformPainter` on every one of
/// those sixty frames. It satisfied "driven by a ticker" and violated "never by
/// rebuilding widgets per frame", which is the half of the sentence that
/// carries the cost.
///
/// The ticker also advances the amplitude window one easing step per frame, so
/// a microphone that reports ten to twenty levels per second still renders as
/// continuous motion at sixty (R7.5.1).
///
/// The ticker stops whenever motion would be pointless — static mode, or
/// reduce-motion — which is what keeps R11.4's battery budget reachable across
/// a 20-minute session.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    this.amplitudes,
    this.mode = WaveformMode.idle,
    this.barCount = 48,
    this.progress,
    this.height = 96,
    this.semanticLabel,
  });

  /// The live or fixed amplitude source.
  ///
  /// Null means "no data": the painter synthesises its idle wave, which is what
  /// every loading state and every unstarted session wants. Callers never have
  /// to special-case it.
  final AmplitudeWindow? amplitudes;

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

  /// Used when the caller passes none, so the painter always has a window to
  /// read and never needs a null check inside `paint`.
  late final AmplitudeWindow _idle = AmplitudeWindow.fixed(const []);

  AmplitudeWindow get _window => widget.amplitudes ?? _idle;

  @override
  void initState() {
    super.initState();
    // Duration sets the period of the synthesised idle wave. It repeats
    // rather than resetting, so phase is continuous and the wave never jumps.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // The single ticker R11.2 names. It drives the synthesised phase AND the
    // amplitude easing, so a live waveform never needs a second one.
    _controller.addListener(_advanceAmplitude);
  }

  void _advanceAmplitude() => _window.advance();

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
    _controller.removeListener(_advanceAmplitude);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final isCapturing = widget.mode == WaveformMode.capturing;

    // No AnimatedBuilder. The painter holds the controller and the window as
    // listenables and repaints itself; this subtree is built once per
    // configuration change (R11.2). The RepaintBoundary keeps that repaint from
    // dirtying the transcript scrolling beside it.
    final painter = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: WaveformPainter(
            amplitudes: _window,
            mode: widget.mode,
            phase: _controller,
            signalColor: colors.signal,
            liveColor: colors.live,
            mutedColor: colors.line,
            barCount: widget.barCount,
            reduceMotion: reduceMotion,
            progress: widget.progress,
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
