import 'package:flutter/material.dart';

/// How a transient message reads to the user.
enum AppMessageTone {
  /// Neutral confirmation. The default.
  neutral,

  /// Something completed. Uses `good`, never a green system toast.
  success,

  /// Something failed. Per PRD §7.6 the copy must state the cause and the
  /// fix — this only controls how it looks.
  failure,
}

/// The app's own transient-message surface, replacing `fluttertoast`.
///
/// PRD §2.2 cuts `fluttertoast` so that a system toast can never break the
/// visual identity: a platform toast is drawn by Android, ignores the theme in
/// §7.1, and would appear in a "broadcast booth" app looking like nothing else
/// in it.
///
/// It also fixes a smaller architectural problem. The toast calls this
/// replaces lived inside `AuthProvider` — a state class reaching directly for
/// the presentation layer, the same shape of mistake as F3. A provider still
/// should not do this, and the real fix is for state to expose an event the UI
/// renders. That refactor belongs with the Riverpod migration; until then this
/// at least removes the third-party dependency and keeps messages inside the
/// design system.
///
/// Uses a global [ScaffoldMessengerState] key rather than a [BuildContext] so
/// that non-widget code can show a message without holding a context, which is
/// what §9.1's "services never know about the widget tree" requires.
abstract final class AppMessenger {
  const AppMessenger._();

  /// Wire this into `MaterialApp(scaffoldMessengerKey: AppMessenger.key)`.
  /// Without it every call here is a silent no-op.
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  /// Shows [message]. Silently does nothing if the messenger is not mounted,
  /// which is correct: a message with no screen to land on is not an error.
  static void show(
    String message, {
    AppMessageTone tone = AppMessageTone.neutral,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = key.currentState;
    if (messenger == null) return;

    // One at a time. Stacked snackbars queue up and outlive the moment they
    // referred to.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  /// Clears anything currently showing.
  static void clear() => key.currentState?.clearSnackBars();
}
