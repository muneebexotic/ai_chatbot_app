import 'package:flutter/material.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/tokens/app_metrics.dart';
import 'package:ai_chatbot_app/design/tokens/app_typography.dart';

/// Assembles the tokens into Material themes (PRD §7).
///
/// Dark is the default — the product is used in headphones, often at night —
/// and light is a designed counterpart rather than an inversion.
///
/// Two things this theme does that a stock Flutter theme does not:
///
/// * **Elevation is a 1dp `line` border, not a shadow** (§7.3). Every
///   `elevation` here is 0 on purpose. The single soft shadow the design
///   permits is reserved for sheets and the floating session control, and is
///   applied by those widgets, not globally.
/// * **`live` red never enters the theme.** It is not the error colour, not
///   the destructive colour, and not an accent. It appears only where the
///   microphone is capturing, which is a decision individual widgets make —
///   see [AppColors] for why.
abstract final class KalaamTheme {
  const KalaamTheme._();

  static ThemeData get dark => _build(AppColors.dark);
  static ThemeData get light => _build(AppColors.light);

  static ThemeData _build(AppColors c) {
    final isDark = c.brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.signal,
      onPrimary: isDark ? const Color(0xFF0A0B0D) : Colors.white,
      secondary: c.signal,
      onSecondary: isDark ? const Color(0xFF0A0B0D) : Colors.white,
      // Errors use ink-on-surface plus specific copy (§7.6: state the cause
      // and the fix). Deliberately NOT `live` — see the class doc.
      error: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
      onError: isDark ? const Color(0xFF0A0B0D) : Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.muted,
      outline: c.line,
      outlineVariant: c.line,
    );

    final textTheme = AppTypography.textTheme(c.ink, c.muted);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,

      // MUST be set explicitly. Left to its default, Material 3 resolves
      // `primaryColor` to `colorScheme.surface` in dark mode and
      // `colorScheme.primary` only in light — see `primarySurfaceColor` in
      // the framework's ThemeData constructor. The result is a theme that is
      // correct in light and silently inverts in dark: 61 call sites across
      // this app read `Theme.of(context).primaryColor`, and in dark every one
      // of them was painting #141619 on a #0A0B0D background.
      //
      // Verified on a device, not in the contrast table — the table checks the
      // nine tokens, and this value is not one of them. It cost the app every
      // primary button, the Settings icon column, the theme switch itself, and
      // legibility of the user's own messages. Locked by a test in
      // test/design/theme_test.dart.
      primaryColor: c.signal,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: textTheme,
      // Stops any stray widget falling back to Roboto, which §7 bans by name.
      fontFamily: AppTypography.uiFamily,

      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title2.copyWith(color: c.ink),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardAll,
          side: BorderSide(color: c.line),
        ),
      ),

      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.signal,
          foregroundColor: isDark ? const Color(0xFF0A0B0D) : Colors.white,
          disabledBackgroundColor: c.surfaceRaised,
          disabledForegroundColor: c.muted,
          elevation: 0,
          // §11.6: 48dp minimum touch target, everywhere.
          minimumSize: const Size(64, Touch.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          textStyle: AppTypography.button,
          shape: const RoundedRectangleBorder(borderRadius: Radii.controlAll),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line),
          minimumSize: const Size(64, Touch.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          textStyle: AppTypography.button,
          shape: const RoundedRectangleBorder(borderRadius: Radii.controlAll),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.signal,
          minimumSize: const Size(48, Touch.minTarget),
          textStyle: AppTypography.button,
          shape: const RoundedRectangleBorder(borderRadius: Radii.controlAll),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        hintStyle: AppTypography.body2.copyWith(color: c.muted),
        labelStyle: AppTypography.label.copyWith(color: c.muted),
        border: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: c.signal, width: 2),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radii.sheet),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.sheetAll,
          side: BorderSide(color: c.line),
        ),
        titleTextStyle: AppTypography.title1.copyWith(color: c.ink),
        contentTextStyle: AppTypography.body2.copyWith(color: c.ink),
      ),

      // The app's own transient message surface (AppMessenger). Squared-off
      // and bordered so it reads as part of the app, not as a system toast —
      // which is the whole reason §2.2 cuts fluttertoast.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: AppTypography.body2.copyWith(color: c.ink),
        actionTextColor: c.signal,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.controlAll,
          side: BorderSide(color: c.line),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.ink,
        minVerticalPadding: Space.sm,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardAll),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.signal : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.signal.withValues(alpha: 0.3)
              : c.surfaceRaised,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.signal,
        linearTrackColor: c.surfaceRaised,
      ),

      iconTheme: IconThemeData(color: c.ink, size: 22),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
