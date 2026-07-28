import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/signup_controller.dart';
import '../mixins/signup_animations_mixin.dart';
import '../constants/signup_constants.dart';
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/social_button.dart';
import '../components/ui/app_back_button.dart';
import '../utils/app_theme.dart';
import '../app/providers.dart';

/// Enhanced SignUp Screen with improved architecture, performance, and theming
///
/// Features:
/// - Clean separation of concerns using controller pattern
/// - Optimized animations with mixin pattern
/// - Robust error handling and logging
/// - Accessibility improvements
/// - Performance optimizations
/// - Theme-aware design supporting light/dark modes
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with
        TickerProviderStateMixin,
        SignUpAnimationsMixin,
        WidgetsBindingObserver {
  late final SignUpController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SignUpController(auth: ref.read(authNotifierProvider));
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
      onSuccess: _navigateAfterAuth,
      onError: _showErrorSnackBar,
    );
  }

  /// Handle Google sign up
  void _handleGoogleSignUp() {
    _controller.signUpWithGoogle(
      onSuccess: _navigateAfterAuth,
      onError: _showErrorSnackBar,
    );
  }

  /// Straight to chat, for new and returning users alike.
  ///
  /// New accounts used to land on the profile-photo screen. Milestone 2 took
  /// it off this path; Milestone 3 deleted the screen, its service, and its
  /// route. It was dead three times over:
  ///
  /// * `profiles` has no avatar column (§9.5), so nothing it collected could
  ///   be saved.
  /// * Its "Generate Avatar" option is image generation, which §2.2 cut and
  ///   §16 bans outright. The first thirty seconds of the product is the worst
  ///   possible place for a banned feature to survive.
  /// * It was still drawn in the old indigo palette, so it was the least
  ///   on-brand screen a new user could be shown first.
  void _navigateAfterAuth() {
    if (!mounted) return;
    _controller.navigateToChat();
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
    return Consumer(
      builder: (context, ref, _) {
        final themeProvider = ref.watch(themeNotifierProvider);

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = themeProvider.isDark;

        return Scaffold(
          backgroundColor: colorScheme.surface,
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
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(SignUpConstants.screenPadding),
                    child: _buildForm(_controller, theme, isDark),
                  );
                },
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
              SignUpConstants.headerLine1,
              color: headerColor,
            ),
            AppText.displayLarge(
              SignUpConstants.headerLine2,
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
            label: SignUpConstants.fullNameLabel,
            hintText: SignUpConstants.fullNameHint,
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
            label: SignUpConstants.emailLabel,
            hintText: SignUpConstants.emailHint,
            validator: controller.validateEmail,
          ),
        ),
        const SizedBox(height: SignUpConstants.inputSpacing),
        _buildAnimatedInput(
          controller: controller.passwordController,
          animation: inputAnimation3,
          inputWidget: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final ctrl = _controller;
              return AppInput.password(
                controller: ctrl.passwordController,
                label: SignUpConstants.passwordLabel,
                hintText: SignUpConstants.passwordHint,
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
          text: SignUpConstants.signUpButtonText,
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
              SignUpConstants.loginPrompt,
              color: secondaryTextColor,
            ),
            AppButton.text(
              text: SignUpConstants.loginButtonText,
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
              SignUpConstants.dividerText,
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

