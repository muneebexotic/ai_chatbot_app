import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../constants/login_constants.dart';
import '../utils/app_theme.dart';

/// Controller to handle login screen business logic
class LoginController extends ChangeNotifier {
  final AuthProvider _authProvider;
  final BuildContext _context;

  LoginController({
    required AuthProvider authProvider,
    required BuildContext context,
  })  : _authProvider = authProvider,
        _context = context;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  String? get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Validates email format
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return LoginConstants.emailRequiredError;
    }
    if (!RegExp(LoginConstants.emailRegexPattern).hasMatch(value)) {
      return LoginConstants.emailValidationError;
    }
    return null;
  }

  /// Validates password
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return LoginConstants.passwordRequiredError;
    }
    if (value.length < LoginConstants.minPasswordLength) {
      return LoginConstants.passwordLengthError;
    }
    return null;
  }

  /// Performs login with email and password
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      await _authProvider.login(email.trim(), password.trim());
      await _waitForUserDataReady();

      if (_authProvider.isLoggedIn && _authProvider.currentUser != null) {
        _setLoading(false);
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Performs Google sign-in
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      await _authProvider.signInWithGoogle();
      await _waitForUserDataReady();

      if (_authProvider.isLoggedIn && _authProvider.currentUser != null) {
        _setLoading(false);
        return true;
      }
      return false;
    } catch (e) {
      _setError('${LoginConstants.googleSignInError}: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Waits for both auth state and user data to be ready
  Future<void> _waitForUserDataReady() async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < LoginConstants.userDataTimeout) {
      if (_authProvider.isLoggedIn && _authProvider.currentUser != null) {
        await Future.delayed(LoginConstants.settlementDelay);
        return;
      }
      await Future.delayed(LoginConstants.checkInterval);
    }

    debugPrint(
      '${LoginConstants.userDataTimeoutWarning}. Auth: ${_authProvider.isLoggedIn}, User: ${_authProvider.currentUser != null}',
    );
  }

  /// Shows error snackbar
  void showErrorSnackBar(String message) {
    if (!_contextMounted) return;

    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Navigates to chat screen
  void navigateToChat() {
    if (!_contextMounted) return;
    Navigator.pushReplacementNamed(_context, LoginConstants.chatRoute);
  }

  /// Navigates to signup screen
  void navigateToSignup() {
    if (!_contextMounted) return;
    Navigator.pushNamed(_context, LoginConstants.signupRoute);
  }

  /// Navigates to forgot password screen
  void navigateToForgotPassword() {
    if (!_contextMounted) return;
    Navigator.pushNamed(_context, LoginConstants.forgotPasswordRoute);
  }

  /// Navigates back to welcome screen
  void navigateToWelcome() {
    if (!_contextMounted) return;
    Navigator.pushReplacementNamed(_context, LoginConstants.welcomeRoute);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  bool get _contextMounted {
    try {
      return _context.mounted;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}