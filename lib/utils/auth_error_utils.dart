class AuthErrorUtils {
  static String getMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email address.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'Failed to send reset email. Please try again.';
  }
}
