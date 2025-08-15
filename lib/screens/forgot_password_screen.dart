import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/forgot_password_controller.dart';
import '../mixins/forgot_password_animations_mixin.dart';
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/app_back_button.dart';
import '../utils/app_theme.dart';
import '../utils/validation_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin, ForgotPasswordAnimationsMixin {
  @override
  void initState() {
    super.initState();
    initAnimations();
    animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ForgotPasswordController>();
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 500 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48 : 24,
                  vertical: isTablet ? 48 : 24,
                ),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: const AppBackButton(),
                      ),
                      SizedBox(height: isTablet ? 60 : 40),
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText.displayLarge('Reset', color: Colors.white),
                              AppText.displayLarge('Password', color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animationController,
                              curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                            ),
                          ),
                          child: const AppText.bodyLarge(
                            'Enter your email address and we\'ll send you a link to reset your password.',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 48 : 32),
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: AppInput.email(
                          controller: controller.emailController,
                          label: 'Email Address',
                          hintText: 'Enter your email',
                          validator: (value) => ValidationUtils.validateEmail(value),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: AppButton.primary(
                          text: controller.emailSent
                              ? 'Email Sent!'
                              : 'Send Reset Email',
                          onPressed: controller.emailSent
                              ? null
                              : () => controller.resetPassword(context),
                          isFullWidth: true,
                          isLoading: controller.isLoading,
                          size: AppButtonSize.large,
                          icon: controller.emailSent
                              ? Icons.check
                              : Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!controller.emailSent)
                        FadeTransition(
                          opacity: fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.surfaceVariant.withOpacity(0.3),
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: AppColors.primary, size: 20),
                                    SizedBox(width: 8),
                                    AppText.bodyMedium(
                                      'What happens next?',
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                AppText.bodyMedium(
                                  '• Check your email inbox and spam folder\n'
                                  '• Click the reset link in the email\n'
                                  '• Create a new strong password\n'
                                  '• Log in with your new password',
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppText.bodyMedium(
                                "Remember your password? ",
                                color: AppColors.textSecondary,
                              ),
                              AppButton.text(
                                text: 'Back to Login',
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
