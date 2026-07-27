import 'package:flutter/widgets.dart';

/// Spacing, on a 4dp base grid (PRD §7.3).
///
/// The set is deliberately small. If a layout seems to need 14 or 20, the
/// answer is almost always a different structure, not a new token.
abstract final class Space {
  const Space._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

/// Corner radii (PRD §7.3).
abstract final class Radii {
  const Radii._();

  /// Buttons, inputs, chips.
  static const Radius control = Radius.circular(10);

  /// Cards and list rows.
  static const Radius card = Radius.circular(18);

  /// Bottom sheets and dialogs.
  static const Radius sheet = Radius.circular(28);

  /// Pills and the waveform button. Large enough to always read as fully
  /// round at any realistic control height.
  static const Radius full = Radius.circular(999);

  static const BorderRadius controlAll = BorderRadius.all(control);
  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius sheetAll = BorderRadius.all(sheet);
  static const BorderRadius fullAll = BorderRadius.all(full);
}

/// Motion (PRD §7.7).
///
/// R7.7.1: motion exists to communicate audio state and nothing else. Before
/// animating something, be able to say which state change it expresses.
///
/// Every duration here must be routed through [durationFor] so that
/// reduce-motion is honoured (R7.7.4) — that is not optional politeness, it is
/// an accessibility requirement in §11.6.
abstract final class Motion {
  const Motion._();

  /// State feedback: a press, a toggle, a level change.
  static const Duration feedback = Duration(milliseconds: 120);

  /// Standard transitions between surfaces.
  static const Duration transition = Duration(milliseconds: 220);

  /// The session screen entry (R7.7.2) — the one place to spend animation
  /// effort. It expands from the pressed control; it does not slide in.
  static const Duration sessionEntry = Duration(milliseconds: 380);

  /// What every duration collapses to under reduce-motion.
  static const Duration reduced = Duration(milliseconds: 100);

  /// The single emphasis curve for the whole app (R7.7.1). Defined once,
  /// used everywhere. Do not introduce a second one.
  static const Curve emphasis = Cubic(0.22, 1, 0.36, 1);

  /// Reduce-motion substitutes a plain fade; an emphasis curve on a 100ms
  /// fade reads as a stutter.
  static const Curve reducedCurve = Curves.linear;

  /// The correct duration for [intended], given the OS setting.
  ///
  /// ```dart
  /// AnimatedContainer(duration: Motion.durationFor(context, Motion.transition))
  /// ```
  static Duration durationFor(BuildContext context, Duration intended) =>
      MediaQuery.disableAnimationsOf(context) ? reduced : intended;

  /// The correct curve, given the OS setting.
  static Curve curveFor(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? reducedCurve : emphasis;

  /// Whether motion should be suppressed. Read this before animating
  /// *position* at all — R7.7.4 requires that nothing moves under
  /// reduce-motion, and a shorter duration is not the same as not moving.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// Minimum touch target (§11.6). Anything interactive must meet this, even
/// when the painted control looks smaller.
abstract final class Touch {
  const Touch._();

  static const double minTarget = 48;
}
