import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/design/theme/speakwise_theme.dart';
import 'package:speakwise/design/tokens/app_colors.dart';

/// Guards the values widgets actually read off [ThemeData], as opposed to the
/// nine tokens `contrast_test.dart` already checks.
///
/// ## Why this file exists
///
/// `AppColors` passed every contrast assertion while the app was, in dark
/// mode, painting primary buttons, the Settings icon column, the theme switch,
/// and the user's own chat bubbles in `#141619` on a `#0A0B0D` background.
/// None of that was visible to the token test, because the failing colour was
/// never a token: Material 3 resolves an unset `ThemeData.primaryColor` to
/// `colorScheme.surface` in dark and `colorScheme.primary` in light, so the
/// theme was correct in one mode and inverted in the other.
///
/// The lesson generalised: a token being correct is not the same as the theme
/// built from it being correct. Assert on the assembled [ThemeData].
void main() {
  group('SpeakWiseTheme derived colours', () {
    for (final entry in {
      'dark': (theme: SpeakWiseTheme.dark, tokens: AppColors.dark),
      'light': (theme: SpeakWiseTheme.light, tokens: AppColors.light),
    }.entries) {
      final mode = entry.key;
      final theme = entry.value.theme;
      final c = entry.value.tokens;

      test('$mode: primaryColor is signal, not the M3 default', () {
        expect(
          theme.primaryColor,
          c.signal,
          reason:
              'Material 3 defaults primaryColor to colorScheme.surface in dark '
              'mode. 61 call sites read Theme.of(context).primaryColor; if this '
              'is not signal, every one of them paints a surface colour on a '
              'background colour.',
        );
      });

      test('$mode: primaryColor is visible against the scaffold', () {
        final ratio = _contrast(theme.primaryColor, theme.scaffoldBackgroundColor);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason:
              '$mode primaryColor on scaffoldBackgroundColor is '
              '${ratio.toStringAsFixed(2)}:1, below the 3:1 floor for UI '
              'boundaries (R7.1.3). A primary action must be findable.',
        );
      });

      test('$mode: onPrimary is readable on primaryColor', () {
        // Chat bubbles, filled buttons, and the avatar all paint onPrimary
        // text on a primaryColor fill.
        final ratio = _contrast(theme.colorScheme.onPrimary, theme.primaryColor);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$mode onPrimary on primaryColor is '
              '${ratio.toStringAsFixed(2)}:1, below the 4.5:1 body-text floor.',
        );
      });

      test('$mode: the token extension survives onto the theme', () {
        expect(theme.extension<AppColors>(), same(c));
      });

      test('$mode: scaffold background is bg, not surface', () {
        // M3 also defaults scaffoldBackgroundColor to colorScheme.surface,
        // which would flatten bg and surface into one another.
        expect(theme.scaffoldBackgroundColor, c.bg);
        expect(theme.scaffoldBackgroundColor, isNot(c.surface));
      });
    }
  });
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
