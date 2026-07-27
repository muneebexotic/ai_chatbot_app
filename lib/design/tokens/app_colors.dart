import 'package:flutter/material.dart';

/// Colour tokens for the "broadcast booth" direction (PRD §7.1).
///
/// Dark is the default mode — the product is used in headphones, often at
/// night. Light is a designed counterpart, not an inversion.
///
/// Two rules matter more than the values themselves:
///
/// * **`signal` amber is the brand.** Active states, primary actions, the
///   waveform at rest, highlights in the report.
/// * **`live` red appears ONLY while the microphone is capturing.** R7.1.1
///   calls this diegetic and it is: a user should be able to tell from across
///   the room whether the mic is hot. Never use [live] decoratively, for
///   errors, or for destructive actions. If you need "danger", you need
///   [AppColors.of(context).ink] and better copy.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.signal,
    required this.live,
    required this.good,
    required this.brightness,
  });

  /// Page background — the furthest-back surface.
  final Color bg;

  /// Cards, sheets, and anything sitting on [bg].
  final Color surface;

  /// One step nearer: user message bubbles, pressed states, inputs.
  final Color surfaceRaised;

  /// Primary text and icons.
  final Color ink;

  /// Secondary text, timestamps, inactive icons. Passes AA for body text.
  final Color muted;

  /// Hairline borders. Elevation is a 1dp [line] border, not a shadow
  /// (§7.3) — the only shadow in the app is on sheets and the floating
  /// session control.
  final Color line;

  /// Brand accent. Rationed: no screen is more than 10% accent by area
  /// (R7.1.2).
  final Color signal;

  /// Recording only. See the class doc.
  final Color live;

  /// Positive deltas in the report, improvement indicators.
  final Color good;

  final Brightness brightness;

  /// PRD §7.1, dark column. The default mode.
  static const AppColors dark = AppColors(
    bg: Color(0xFF0A0B0D),
    surface: Color(0xFF141619),
    surfaceRaised: Color(0xFF1C1F24),
    ink: Color(0xFFEDEEF0),
    muted: Color(0xFF8A9099),
    line: Color(0xFF22262B),
    signal: Color(0xFFFFB627),
    live: Color(0xFFFF3B2F),
    good: Color(0xFF3DD68C),
    brightness: Brightness.dark,
  );

  /// PRD §7.1, light column. Note [signal] and [live] are *darker* here rather
  /// than lighter — amber on white fails contrast otherwise, and R7.1.3
  /// requires AA in both modes.
  static const AppColors light = AppColors(
    bg: Color(0xFFEEF0F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF6F8FA),
    ink: Color(0xFF101215),
    muted: Color(0xFF5C636B),
    line: Color(0xFFDCE0E4),
    signal: Color(0xFF8A5A00),
    live: Color(0xFFD62B1F),
    good: Color(0xFF0F7A4C),
    brightness: Brightness.light,
  );

  /// Reads the tokens off the ambient theme.
  ///
  /// Prefer this to referencing [dark] or [light] directly — a widget that
  /// names one mode explicitly will be wrong in the other.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? muted,
    Color? line,
    Color? signal,
    Color? live,
    Color? good,
    Brightness? brightness,
  }) => AppColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    signal: signal ?? this.signal,
    live: live ?? this.live,
    good: good ?? this.good,
    brightness: brightness ?? this.brightness,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      live: Color.lerp(live, other.live, t)!,
      good: Color.lerp(good, other.good, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}
