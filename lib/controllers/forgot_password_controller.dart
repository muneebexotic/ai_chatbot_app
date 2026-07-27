import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_error_utils.dart';

class ForgotPasswordController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool emailSent = false;

  /// [auth] is passed in rather than read from the tree: a controller that
  /// calls `Provider.of` on a context it was handed is the same F3 shape as
  /// a service doing it, just one layer up.
  Future<void> resetPassword(BuildContext context, AuthProvider auth) async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading = true;
    notifyListeners();

    try {
      await auth.sendPasswordResetEmail(emailController.text.trim());
      emailSent = true;
      isLoading = false;
      notifyListeners();

      // The user can leave this screen while the reset email is in flight.
      // The state above is still worth setting; the context is not usable.
      if (!context.mounted) return;
      _showSnackBar(context,
        message: 'Password reset email sent! Check your inbox.',
        icon: Icons.check_circle,
        color: Colors.green,
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) Navigator.pop(context);
      });
    } catch (e) {
      isLoading = false;
      notifyListeners();

      if (!context.mounted) return;
      _showSnackBar(
        context,
        message: AuthErrorUtils.getMessage(e.toString()),
        icon: Icons.error,
        color: Colors.red,
      );
    }
  }

  void _showSnackBar(BuildContext context,
      {required String message, required IconData icon, required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
