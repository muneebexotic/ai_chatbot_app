import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Internal imports
import '../providers/auth_provider.dart';
import '../controllers/login_controller.dart';
import '../mixins/login_animations_mixin.dart';
import '../constants/login_constants.dart';
import '../utils/validation_utils.dart';
import '../utils/app_theme.dart';

// UI Components
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/social_button.dart';
import '../components/ui/app_back_button.dart';

/// Login screen with form validation and authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin, LoginAnimationsMixin {
  // Controllers
  late final LoginController _loginController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeControllers() {
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _formKey = GlobalKey<FormState>();

    // Initialize login controller with auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _loginController = LoginController(
      authProvider: authProvider,
      context: context,
    );
  }

  void _initializeAnimations() {
    initializeLoginAnimations();
  }

  void _startAnimations() {
    startLoginAnimations();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _loginController.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      _loginController.navigateToChat();
    } else if (_loginController.errorMessage != null) {
      _loginController.showErrorSnackBar(_loginController.errorMessage!);
    }
  }

  Future<void> _handleGoogleLogin() async {
    final success = await _loginController.loginWithGoogle();

    if (!mounted) return;

    if (success) {
      _loginController.navigateToChat();
    } else if (_loginController.errorMessage != null) {
      _loginController.showErrorSnackBar(_loginController.errorMessage!);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginController.dispose();
    disposeLoginAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(LoginConstants.primaryBackgroundColor),
      resizeToAvoidBottomInset: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: _buildGradientDecoration(),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _buildScrollableContent(),
            ),
            _buildBottomPadding(),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildGradientDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(LoginConstants.primaryBackgroundColor),
          Color(LoginConstants.secondaryBackgroundColor),
          Color(LoginConstants.primaryBackgroundColor),
        ],
        stops: [0.0, 0.5, 1.0],
      ),
    );
  }

  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LoginConstants.screenPadding),
      child: AnimatedBuilder(
        animation: animationController,
        builder: (context, child) => _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: LoginConstants.titleTopSpacing),
          _buildTitle(),
          const SizedBox(height: LoginConstants.titleBottomSpacing),
          _buildEmailInput(),
          const SizedBox(height: LoginConstants.inputSpacing),
          _buildPasswordInput(),
          const SizedBox(height: LoginConstants.forgotPasswordSpacing),
          _buildForgotPasswordButton(),
          const SizedBox(height: LoginConstants.loginButtonSpacing),
          _buildLoginButton(),
          const SizedBox(height: LoginConstants.signUpLinkSpacing),
          _buildSignUpLink(),
          const SizedBox(height: LoginConstants.dividerSpacing),
          _buildDivider(),
          const SizedBox(height: LoginConstants.socialButtonSpacing),
          _buildGoogleSignInButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: AppBackButton(
        onPressed: _loginController.navigateToWelcome,
      ),
    );
  }

  Widget _buildTitle() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.displayLarge(
              LoginConstants.titleLine1,
              color: Colors.white,
            ),
            AppText.displayLarge(
              LoginConstants.titleLine2,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInput() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: emailSlideAnimation,
        child: AppInput.email(
          controller: _emailController,
          label: LoginConstants.emailLabel,
          hintText: LoginConstants.emailHint,
          validator: ValidationUtils.validateEmail,
        ),
      ),
    );
  }

  Widget _buildPasswordInput() {
    return ChangeNotifierProvider.value(
      value: _loginController,
      child: Consumer<LoginController>(
        builder: (context, controller, child) {
          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: passwordSlideAnimation,
              child: AppInput.password(
                controller: _passwordController,
                label: LoginConstants.passwordLabel,
                hintText: LoginConstants.passwordHint,
                obscureText: controller.obscurePassword,
                onToggleVisibility: controller.togglePasswordVisibility,
                validator: ValidationUtils.validatePassword,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: AppButton.text(
          text: LoginConstants.forgotPasswordText,
          onPressed: _loginController.navigateToForgotPassword,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ChangeNotifierProvider.value(
      value: _loginController,
      child: Consumer<LoginController>(
        builder: (context, controller, child) {
          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: buttonSlideAnimation,
              child: AppButton.primary(
                text: LoginConstants.loginButtonText,
                onPressed: _handleLogin,
                isFullWidth: true,
                isLoading: controller.isLoading,
                size: AppButtonSize.large,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSignUpLink() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppText.bodyMedium(
              LoginConstants.signUpPrompt,
              color: AppColors.textSecondary,
            ),
            AppButton.text(
              text: LoginConstants.signUpText,
              onPressed: _loginController.navigateToSignup,
            ),
          ],
        ),
      ),
    );
  }

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
              LoginConstants.dividerText,
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

  Widget _buildGoogleSignInButton() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: SocialButton.google(
          onPressed: _handleGoogleLogin,
        ),
      ),
    );
  }

  Widget _buildBottomPadding() {
    return Container(
      height: MediaQuery.of(context).padding.bottom,
      color: const Color(LoginConstants.primaryBackgroundColor),
    );
  }
}