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

/// Enhanced SignUp Screen with improved architecture and performance
/// 
/// Features:
/// - Clean separation of concerns using controller pattern
/// - Optimized animations with mixin pattern
/// - Robust error handling and logging
/// - Accessibility improvements
/// - Performance optimizations
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin, SignUpAnimationsMixin, WidgetsBindingObserver {
  
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
      onSuccess: (_) => _navigateAfterAuth(false), // Google users go to chat
      onError: _showErrorSnackBar,
    );
  }

  /// Navigate user based on their status
  void _navigateAfterAuth(bool isNewUser) {
    if (!mounted) return;
    
    final route = isNewUser ? '/photo-upload' : '/chat';
    Navigator.pushReplacementNamed(context, route);
  }

  /// Show error message to user
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: SignUpConstants.backgroundGradient,
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
                  child: _buildForm(controller),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Build the main form with optimized animations
  Widget _buildForm(SignUpController controller) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: SignUpConstants.sectionSpacing),
          _buildHeader(),
          const SizedBox(height: SignUpConstants.largeSpacing),
          _buildInputFields(controller),
          const SizedBox(height: SignUpConstants.buttonSpacing),
          _buildSignUpButton(controller),
          const SizedBox(height: SignUpConstants.sectionSpacing),
          _buildLoginLink(),
          const SizedBox(height: SignUpConstants.largeSpacing),
          _buildDivider(),
          const SizedBox(height: SignUpConstants.buttonSpacing),
          _buildGoogleButton(controller),
          const SizedBox(height: SignUpConstants.bottomSpacing),
        ],
      ),
    );
  }

  /// Optimized back button with fade animation
  Widget _buildBackButton() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: const AppBackButton(),
    );
  }

  /// Animated header with slide transition
  Widget _buildHeader() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.displayLarge(
              SignUpConstants.headerLine1,
              color: Colors.white,
            ),
            AppText.displayLarge(
              SignUpConstants.headerLine2,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  /// Input fields with staggered animations
  Widget _buildInputFields(SignUpController controller) {
    return Column(
      children: [
        _buildAnimatedInput(
          controller: controller.fullNameController,
          animation: inputAnimation1,
          inputWidget: AppInput.text(
            controller: controller.fullNameController,
            label: SignUpConstants.fullNameLabel,
            hintText: SignUpConstants.fullNameHint,
            prefixIcon: Icons.person_outline,
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
          inputWidget: Consumer<SignUpController>(
            builder: (context, ctrl, _) {
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

  /// Helper method for animated inputs
  Widget _buildAnimatedInput({
    required TextEditingController controller,
    required Animation<Offset> animation,
    required Widget inputWidget,
  }) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: animation,
        child: inputWidget,
      ),
    );
  }

  /// Sign up button with loading state
  Widget _buildSignUpButton(SignUpController controller) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: buttonAnimation,
        child: AppButton.primary(
          text: SignUpConstants.signUpButtonText,
          onPressed: controller.isLoading ? () {} : _handleSignUp,
          isFullWidth: true,
          isLoading: controller.isLoading,
          size: AppButtonSize.large,
        ),
      ),
    );
  }

  /// Login link
  Widget _buildLoginLink() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppText.bodyMedium(
              SignUpConstants.loginPrompt,
              color: AppColors.textSecondary,
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

  /// Divider with text
  Widget _buildDivider() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.textTertiary.withOpacity(0.3),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppText.bodyMedium(
              SignUpConstants.dividerText,
              color: AppColors.textTertiary,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.textTertiary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Google sign up button
  Widget _buildGoogleButton(SignUpController controller) {
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