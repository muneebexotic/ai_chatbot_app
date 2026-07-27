
import 'package:flutter/material.dart';

/// Type tokens (PRD §7.2).
///
/// Three families, each shipped as a single variable font. Weight is applied
/// through [FontVariation] rather than by shipping separate cuts — see the
/// `fonts:` block in `pubspec.yaml` for why.
///
/// ## The weight rule is a legibility rule, not a taste one
///
/// R7.2.2: **Newsreader 300 is permitted ONLY at 30sp and above, and nothing
/// below 20sp is ever lighter than 400.** Hairline weights at small sizes on
/// low-density Android screens are a legibility failure, and R7.2.2 says this
/// rule overrides any general advice to use extreme weights. [_serif] asserts
/// it in debug builds so the rule is enforced by the compiler-adjacent tooling
/// rather than by memory.
///
/// ## Scale
///
/// display 56 / 40 / 30 · title 24 / 20 · body 17 / 15 · label 13 · micro 11.
/// R7.2.1: the jump from body to display is deliberate and large. Do not fill
/// the gap with intermediate sizes — if something needs 26sp, it probably
/// wants a different hierarchy.
abstract final class AppTypography {
  const AppTypography._();

  static const String serifFamily = 'Newsreader';
  static const String uiFamily = 'GeneralSans';
  static const String monoFamily = 'GeistMono';

  // ── Display: Newsreader. Session headlines and report numbers. ──────────
  static TextStyle get display1 => _serif(56, 300, height: 1.05);
  static TextStyle get display2 => _serif(40, 300, height: 1.1);
  static TextStyle get display3 => _serif(30, 300, height: 1.15);

  // ── Title ────────────────────────────────────────────────────────────────
  static TextStyle get title1 => _serif(24, 400, height: 1.25);
  static TextStyle get title2 => _ui(20, 500, height: 1.3);

  // ── AI transcript. The app's typographic signature (R7.4.1). ────────────
  /// AI turns: full-width typeset paragraphs, never bubbles.
  static TextStyle get transcriptAi => _serif(17, 400, height: 1.55);

  /// User turns: compact, right-aligned, in the UI face. The asymmetry is the
  /// identity — the AI is publishing, the user is speaking.
  static TextStyle get transcriptUser => _ui(15, 450, height: 1.45);

  // ── Body and UI ─────────────────────────────────────────────────────────
  static TextStyle get body1 => _ui(17, 400, height: 1.5);
  static TextStyle get body2 => _ui(15, 400, height: 1.45);
  static TextStyle get label => _ui(13, 500, height: 1.3, tracking: 0.1);
  static TextStyle get micro => _ui(11, 500, height: 1.25, tracking: 0.4);

  /// Button text. Slightly heavier so it reads as a target, not a caption.
  static TextStyle get button => _ui(15, 550, height: 1.2, tracking: 0.1);

  // ── Data: Geist Mono. Timers, durations, counts, pace, dates. ───────────
  /// The elapsed timer on the session screen.
  static TextStyle get dataLarge => _mono(40, 400, height: 1.0);

  /// Metric values on report cards.
  static TextStyle get dataMedium => _mono(20, 450, height: 1.15);

  /// Inline figures, timestamps, dates.
  static TextStyle get dataSmall => _mono(13, 450, height: 1.2);

  static TextStyle _serif(
    double size,
    int weight, {
    double? height,
    double? tracking,
  }) {
    assert(
      !(size < 30 && weight < 400),
      'R7.2.2: Newsreader 300 is permitted only at 30sp and above. '
      'Got ${size}sp at weight $weight. Light serif at small sizes is '
      'illegible on low-density Android screens.',
    );
    return _build(serifFamily, size, weight, height, tracking);
  }

  static TextStyle _ui(
    double size,
    int weight, {
    double? height,
    double? tracking,
  }) {
    assert(
      !(size < 20 && weight < 400),
      'R7.2.2: nothing below 20sp is ever lighter than 400. '
      'Got ${size}sp at weight $weight.',
    );
    return _build(uiFamily, size, weight, height, tracking);
  }

  static TextStyle _mono(
    double size,
    int weight, {
    double? height,
    double? tracking,
  }) {
    assert(
      !(size < 20 && weight < 400),
      'R7.2.2: nothing below 20sp is ever lighter than 400. '
      'Got ${size}sp at weight $weight.',
    );
    return _build(monoFamily, size, weight, height, tracking);
  }

  static TextStyle _build(
    String family,
    double size,
    int weight,
    double? height,
    double? tracking,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    letterSpacing: tracking,
    // Both are needed. `fontVariations` drives the variable axis and does the
    // actual work; `fontWeight` keeps Flutter's fallback and any synthetic
    // bolding consistent when the variable font is unavailable.
    fontVariations: [FontVariation('wght', weight.toDouble())],
    fontWeight: _nearestFontWeight(weight),
  );

  static FontWeight _nearestFontWeight(int weight) => switch (weight) {
    < 350 => FontWeight.w300,
    < 450 => FontWeight.w400,
    < 550 => FontWeight.w500,
    < 650 => FontWeight.w600,
    _ => FontWeight.w700,
  };

  /// The Material [TextTheme], so stock widgets inherit the right faces
  /// instead of falling back to Roboto — which §7 bans by name.
  static TextTheme textTheme(Color ink, Color muted) => TextTheme(
    displayLarge: display1.copyWith(color: ink),
    displayMedium: display2.copyWith(color: ink),
    displaySmall: display3.copyWith(color: ink),
    headlineMedium: title1.copyWith(color: ink),
    headlineSmall: title2.copyWith(color: ink),
    titleLarge: title2.copyWith(color: ink),
    bodyLarge: body1.copyWith(color: ink),
    bodyMedium: body2.copyWith(color: ink),
    bodySmall: label.copyWith(color: muted),
    labelLarge: button.copyWith(color: ink),
    labelMedium: label.copyWith(color: muted),
    labelSmall: micro.copyWith(color: muted),
  );
}
