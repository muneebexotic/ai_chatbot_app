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
import '../providers/themes_provider.dart';

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

  /// Get theme-aware background gradient colors
  List<Color> _getBackgroundGradient(bool isDark) {
    if (isDark) {
      return [
        AppColors.background,
        AppColors.surface,
        AppColors.background,
      ];
    } else {
      return [
        AppColors.backgroundLight,
        AppColors.surfaceVariantLight,
        AppColors.backgroundLight,
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final controller = context.watch<ForgotPasswordController>();
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = themeProvider.isDark;
        final size = MediaQuery.of(context).size;
        final isTablet = size.width > 600;

        return Scaffold(
          backgroundColor: colorScheme.background,
          resizeToAvoidBottomInset: true,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _getBackgroundGradient(isDark),
                stops: const [0.0, 0.5, 1.0],
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
                          _buildBackButton(),
                          SizedBox(height: isTablet ? 60 : 40),
                          _buildHeader(isDark),
                          const SizedBox(height: 16),
                          _buildSubtitle(isDark),
                          SizedBox(height: isTablet ? 48 : 32),
                          _buildEmailInput(controller, theme),
                          const SizedBox(height: 32),
                          _buildResetButton(controller, theme),
                          const SizedBox(height: 32),
                          if (!controller.emailSent)
                            _buildInfoCard(theme, isDark),
                          const SizedBox(height: 24),
                          _buildBackToLoginLink(theme, isDark),
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
      },
    );
  }

  /// Theme-aware back button
  Widget _buildBackButton() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: const AppBackButton(),
    );
  }

  /// Theme-aware header with animations
  Widget _buildHeader(bool isDark) {
    final headerColor = AppColors.getTextPrimary(isDark);
    
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.displayLarge('Reset', color: headerColor),
            AppText.displayLarge('Password', color: headerColor),
          ],
        ),
      ),
    );
  }

  /// Theme-aware subtitle with animation
  Widget _buildSubtitle(bool isDark) {
    final subtitleColor = AppColors.getTextSecondary(isDark);
    
    return FadeTransition(
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
        child: AppText.bodyLarge(
          'Enter your email address and we\'ll send you a link to reset your password.',
          color: subtitleColor,
        ),
      ),
    );
  }

  /// Theme-aware email input field
  Widget _buildEmailInput(ForgotPasswordController controller, ThemeData theme) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: AppInput.email(
        controller: controller.emailController,
        label: 'Email Address',
        hintText: 'Enter your email',
        validator: (value) => ValidationUtils.validateEmail(value),
      ),
    );
  }

  /// Theme-aware reset button
  Widget _buildResetButton(ForgotPasswordController controller, ThemeData theme) {
    return FadeTransition(
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
    );
  }

  /// Theme-aware info card
  Widget _buildInfoCard(ThemeData theme, bool isDark) {
    final surfaceColor = AppColors.getSurface(isDark);
    final surfaceVariantColor = AppColors.getSurfaceVariant(isDark);
    final primaryTextColor = AppColors.getTextPrimary(isDark);
    final secondaryTextColor = AppColors.getTextSecondary(isDark);
    
    return FadeTransition(
      opacity: fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: surfaceVariantColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                AppText.bodyMedium(
                  'What happens next?',
                  color: primaryTextColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppText.bodyMedium(
              '• Check your email inbox and spam folder\n'
              '• Click the reset link in the email\n'
              '• Create a new strong password\n'
              '• Log in with your new password',
              color: secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Theme-aware back to login link
  Widget _buildBackToLoginLink(ThemeData theme, bool isDark) {
    final secondaryTextColor = AppColors.getTextSecondary(isDark);
    
    return FadeTransition(
      opacity: fadeAnimation,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText.bodyMedium(
              "Remember your password? ",
              color: secondaryTextColor,
            ),
            AppButton.text(
              text: 'Back to Login',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}