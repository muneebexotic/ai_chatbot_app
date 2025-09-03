import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/signup_controller.dart';
import '../mixins/signup_animations_mixin.dart';
import '../constants/signup_constants.dart';
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/social_button.dart';
import '../components/ui/app_back_button.dart';
import '../utils/app_theme.dart';
import '../providers/themes_provider.dart';
import '../l10n/generated/app_localizations.dart';

/// Enhanced SignUp Screen with improved architecture, performance, and theming
///
/// Features:
/// - Clean separation of concerns using controller pattern
/// - Optimized animations with mixin pattern
/// - Robust error handling and logging
/// - Accessibility improvements
/// - Performance optimizations
/// - Theme-aware design supporting light/dark modes
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with
        TickerProviderStateMixin,
        SignUpAnimationsMixin,
        WidgetsBindingObserver {
  late final SignUpController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SignUpController();
    initializeAnimations();
    startAnimations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    disposeAnimations();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes for better UX
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAuthState();
    }
  }

  /// Handle sign up with email and password
  void _handleSignUp() {
    if (!_controller.validateForm()) return;

    _controller.signUpWithEmail(
      onSuccess: (isNewUser) => _navigateAfterAuth(isNewUser),
      onError: _showErrorSnackBar,
    );
  }

  /// Handle Google sign up
  void _handleGoogleSignUp() {
    _controller.signUpWithGoogle(
      onSuccess: (_) => _navigateAfterAuth(false),
      onError: _showErrorSnackBar,
    );
  }

  /// Navigate user based on their status
  void _navigateAfterAuth(bool isNewUser) {
    if (!mounted) return;

    if (isNewUser) {
      _controller.navigateToPhotoUpload();
    } else {
      _controller.navigateToChat();
    }
  }

  /// Show error message to user with theme-aware styling
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SignUpConstants.borderRadius),
        ),
        duration: SignUpConstants.errorDisplayDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = themeProvider.isDark;

        return Scaffold(
          backgroundColor: colorScheme.background,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: SignUpConstants.getBackgroundGradient(isDark),
                stops: SignUpConstants.gradientStops,
              ),
            ),
            child: SafeArea(
              child: ChangeNotifierProvider.value(
                value: _controller,
                child: Consumer<SignUpController>(
                  builder: (context, controller, _) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(SignUpConstants.screenPadding),
                      child: _buildForm(controller, theme, isDark),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build the main form with optimized animations and theme support
  Widget _buildForm(SignUpController controller, ThemeData theme, bool isDark) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(theme),
          const SizedBox(height: SignUpConstants.sectionSpacing),
          _buildHeader(theme, isDark),
          const SizedBox(height: SignUpConstants.largeSpacing),
          _buildInputFields(controller, theme),
          const SizedBox(height: SignUpConstants.buttonSpacing),
          _buildSignUpButton(controller, theme),
          const SizedBox(height: SignUpConstants.sectionSpacing),
          _buildLoginLink(theme),
          const SizedBox(height: SignUpConstants.largeSpacing),
          _buildDivider(theme),
          const SizedBox(height: SignUpConstants.buttonSpacing),
          _buildGoogleButton(controller, theme),
          const SizedBox(height: SignUpConstants.bottomSpacing),
        ],
      ),
    );
  }

  /// Theme-aware back button with fade animation
  Widget _buildBackButton(ThemeData theme) {
    return FadeTransition(
      opacity: fadeAnimation, 
      child: const AppBackButton()
    );
  }

  /// Animated header with slide transition and theme-aware colors
  Widget _buildHeader(ThemeData theme, bool isDark) {
    final headerColor = AppColors.getTextPrimary(isDark);
    
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.displayLarge(
              AppLocalizations.of(context).createYour,
              color: headerColor,
            ),
            AppText.displayLarge(
              AppLocalizations.of(context).account,
              color: headerColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Input fields with staggered animations and theme support
  Widget _buildInputFields(SignUpController controller, ThemeData theme) {
    return Column(
      children: [
        _buildAnimatedInput(
          controller: controller.fullNameController,
          animation: inputAnimation1,
          inputWidget: AppInput.text(
            controller: controller.fullNameController,
            label: AppLocalizations.of(context).fullName,
            hintText: AppLocalizations.of(context).fullNameHint,
            prefixIcon: Icon(
              Icons.person_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            validator: controller.validateFullName,
          ),
        ),
        const SizedBox(height: SignUpConstants.inputSpacing),
        _buildAnimatedInput(
          controller: controller.emailController,
          animation: inputAnimation2,
          inputWidget: AppInput.email(
            controller: controller.emailController,
            label: AppLocalizations.of(context).email,
            hintText: AppLocalizations.of(context).emailHint,
            validator: controller.validateEmail,
          ),
        ),
        const SizedBox(height: SignUpConstants.inputSpacing),
        _buildAnimatedInput(
          controller: controller.passwordController,
          animation: inputAnimation3,
          inputWidget: Consumer<SignUpController>(
            builder: (context, ctrl, _) {
              return AppInput.password(
                controller: ctrl.passwordController,
                label: AppLocalizations.of(context).password,
                hintText: AppLocalizations.of(context).passwordHint,
                obscureText: ctrl.obscurePassword,
                onToggleVisibility: ctrl.togglePasswordVisibility,
                validator: ctrl.validatePassword,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Helper method for animated inputs with theme awareness
  Widget _buildAnimatedInput({
    required TextEditingController controller,
    required Animation<Offset> animation,
    required Widget inputWidget,
  }) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(position: animation, child: inputWidget),
    );
  }

  /// Theme-aware sign up button with loading state
  Widget _buildSignUpButton(SignUpController controller, ThemeData theme) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: buttonAnimation,
        child: AppButton.primary(
          text: AppLocalizations.of(context).signUp,
          onPressed: controller.isLoading ? null : _handleSignUp,
          isFullWidth: true,
          isLoading: controller.isLoading,
          size: AppButtonSize.large,
        ),
      ),
    );
  }

  /// Theme-aware login link
  Widget _buildLoginLink(ThemeData theme) {
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    
    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText.bodyMedium(
              AppLocalizations.of(context).alreadyHaveAccount,
              color: secondaryTextColor,
            ),
            AppButton.text(
              text: AppLocalizations.of(context).signIn,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Theme-aware divider with text
  Widget _buildDivider(ThemeData theme) {
    final dividerColor = theme.colorScheme.outlineVariant;
    final textColor = theme.colorScheme.onSurfaceVariant;
    
    return FadeTransition(
      opacity: fadeAnimation,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: dividerColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText.bodyMedium(
              AppLocalizations.of(context).orContinueWith,
              color: textColor,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Theme-aware Google sign up button
  Widget _buildGoogleButton(SignUpController controller, ThemeData theme) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: SocialButton.google(
          onPressed: controller.isLoading ? () {} : _handleGoogleSignUp,
        ),
      ),
    );
  }
}

