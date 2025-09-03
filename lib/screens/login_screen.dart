import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Internal imports
import '../providers/auth_provider.dart';
import '../controllers/login_controller.dart';
import '../mixins/login_animations_mixin.dart';
import '../constants/login_constants.dart';
import '../utils/validation_utils.dart';
import '../l10n/generated/app_localizations.dart';

// UI Components
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/social_button.dart';
import '../components/ui/app_back_button.dart';

/// Theme-aware login screen with form validation and authentication
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
      // Remove hardcoded background color - let theme handle it
      resizeToAvoidBottomInset: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.background,
            colorScheme.surface,
            colorScheme.background,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.displayLarge(
              AppLocalizations.of(context).welcomeBack,
              color: colorScheme.onBackground, // Theme-aware
            ),
            AppText.displayLarge(
              AppLocalizations.of(context).backText,
              color: colorScheme.onBackground, // Theme-aware
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
          label: AppLocalizations.of(context).email,
          hintText: AppLocalizations.of(context).emailHint,
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
                label: AppLocalizations.of(context).password,
                hintText: AppLocalizations.of(context).passwordHint,
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
          text: AppLocalizations.of(context).forgotPassword,
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
                text: AppLocalizations.of(context).login,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText.bodyMedium(
              AppLocalizations.of(context).dontHaveAccount,
              color: colorScheme.onBackground.withOpacity(0.7), // Theme-aware
            ),
            AppButton.text(
              text: AppLocalizations.of(context).signUp,
              onPressed: _loginController.navigateToSignup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: fadeAnimation,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outline.withOpacity(0.3), // Theme-aware
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText.bodyMedium(
              AppLocalizations.of(context).orContinueWith,
              color: colorScheme.onBackground.withOpacity(0.5), // Theme-aware
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outline.withOpacity(0.3), // Theme-aware
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).padding.bottom,
      color: colorScheme.background, // Theme-aware
    );
  }
}