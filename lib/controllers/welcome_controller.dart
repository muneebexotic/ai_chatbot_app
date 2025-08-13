import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/welcome_screen_constants.dart';
import '../utils/app_theme.dart';

class WelcomeController {
  final BuildContext context;
  bool _isLoading = false;

  WelcomeController(this.context);

  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  Future<void> handleGoogleSignIn({
    required VoidCallback onLoadingChanged,
  }) async {
    _setLoading(true);
    onLoadingChanged();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await authProvider.signInWithGoogle();
      
      if (authProvider.isLoggedIn && context.mounted) {
        Navigator.pushReplacementNamed(
          context,
          WelcomeScreenConstants.chatRoute,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(_formatErrorMessage(e.toString()));
      }
    } finally {
      _setLoading(false);
      onLoadingChanged();
    }
  }

  void navigateToLogin() {
    Navigator.pushNamed(context, WelcomeScreenConstants.loginRoute);
  }

  void navigateToSignUp() {
    Navigator.pushNamed(context, WelcomeScreenConstants.signupRoute);
  }

  String _formatErrorMessage(String error) {
    // Here you can implement more sophisticated error message formatting
    // For example, mapping specific error codes to user-friendly messages
    if (error.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    } else if (error.contains('cancelled')) {
      return 'Sign-in was cancelled.';
    } else {
      return 'Google Sign-In failed. Please try again.';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            WelcomeScreenConstants.snackBarBorderRadius,
          ),
        ),
      ),
    );
  }
}