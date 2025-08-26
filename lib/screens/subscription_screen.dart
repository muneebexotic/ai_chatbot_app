import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../models/subscription_models.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/app_theme.dart';
import '../utils/subscription_utils.dart';
import '../widgets/subscription/purchase_confirmation_dialog.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isRestoreLoading = false;
  bool _isInitializing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSubscription();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeSubscription() async {
    if (mounted) {
      setState(() => _isInitializing = true);
    }
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.initialize();
      debugPrint('✅ Subscription initialization completed');
    } catch (e) {
      debugPrint('❌ Subscription initialization failed: $e');
      if (mounted) {
        SubscriptionUtils.showErrorSnackBar(
          context,
          'Failed to load subscription data. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _handlePurchase() async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (!authProvider.isLoggedIn) {
      SubscriptionUtils.showErrorSnackBar(
        context,
        'Please log in to purchase subscription.',
      );
      return;
    }

    final product = subscriptionProvider.selectedProduct;
    if (product == null) {
      SubscriptionUtils.showErrorSnackBar(
        context,
        'Please select a subscription plan.',
      );
      return;
    }

    final confirmed = await PurchaseConfirmationDialog.show(
      context,
      product: product,
      yearlySavingsText: subscriptionProvider.getYearlySavingsText(),
    );

    if (!confirmed) return;

    try {
      await subscriptionProvider.purchaseSubscription();
      if (mounted) {
        SubscriptionUtils.showSuccessSnackBar(
          context,
          'Purchase successful! Welcome to Premium!',
        );
      }
    } catch (e) {
      if (mounted) {
        final message = SubscriptionUtils.parseErrorMessage(e);
        SubscriptionUtils.showErrorSnackBar(context, message);
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isRestoreLoading = true);

    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.restorePurchases();
      if (mounted) {
        SubscriptionUtils.showSuccessSnackBar(
          context,
          'Purchases restored successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        final message = SubscriptionUtils.parseErrorMessage(e);
        SubscriptionUtils.showErrorSnackBar(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoreLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, SubscriptionProvider, ThemeProvider>(
      builder: (context, authProvider, subscriptionProvider, themeProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.isDark ? AppColors.background : Colors.grey[50],
          body: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  children: [
                    _buildHeader(themeProvider, authProvider),
                    Expanded(
                      child: _buildContent(authProvider, subscriptionProvider, themeProvider),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, AuthProvider authProvider) {
    final isDark = themeProvider.isDark;
    final bgColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.surfaceVariant : Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  AppText.headlineSmall(
                    'Premium Subscription',
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  if (authProvider.isPremium)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        AppText.bodySmall(
                          'Premium Active',
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: textColor,
                size: 22,
              ),
              onPressed: themeProvider.toggleTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AuthProvider authProvider, SubscriptionProvider subscriptionProvider, ThemeProvider themeProvider) {
    if (_isInitializing) {
      return _buildLoadingState(themeProvider);
    }

    if (authProvider.isPremium) {
      return _buildPremiumContent(authProvider, themeProvider);
    }

    return _buildUpgradeContent(authProvider, subscriptionProvider, themeProvider);
  }

  Widget _buildLoadingState(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 20),
          AppText.bodyMedium(
            'Loading subscription plans...',
            color: isDark ? AppColors.textPrimary : Colors.black87,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumContent(AuthProvider authProvider, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDark;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                AppText.headlineMedium(
                  'Premium Active',
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 12),
                AppText.bodyMedium(
                  authProvider.subscriptionStatus ?? 'Enjoying unlimited access',
                  color: isDark ? AppColors.textSecondary : Colors.black54,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton.outline(
                  text: 'Manage Subscription',
                  onPressed: () => Navigator.pop(context),
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeContent(AuthProvider authProvider, SubscriptionProvider subscriptionProvider, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDark;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Usage Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText.bodySmall(
                    authProvider.usageText,
                    color: isDark ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Plan Selection
          _buildPlanSelector(subscriptionProvider, themeProvider),
          
          const SizedBox(height: 24),
          
          // Subscription Card
          Expanded(
            child: _buildSubscriptionCard(subscriptionProvider, themeProvider),
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          _buildActionButtons(subscriptionProvider),
        ],
      ),
    );
  }

  Widget _buildPlanSelector(SubscriptionProvider subscriptionProvider, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDark;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.surfaceVariant : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPlanOption(
              subscriptionProvider,
              themeProvider,
              SubscriptionPlan.monthly,
              'Monthly',
              subscriptionProvider.monthlyProduct?.price ?? '...',
              'Flexible billing',
            ),
          ),
          Expanded(
            child: _buildPlanOption(
              subscriptionProvider,
              themeProvider,
              SubscriptionPlan.yearly,
              'Yearly',
              subscriptionProvider.yearlyProduct?.price ?? '...',
              subscriptionProvider.getYearlySavingsText().isNotEmpty 
                ? subscriptionProvider.getYearlySavingsText()
                : 'Best value',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    SubscriptionPlan plan,
    String title,
    String price,
    String subtitle,
  ) {
    final isDark = themeProvider.isDark;
    final isSelected = subscriptionProvider.selectedPlan == plan;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final subtitleColor = isDark ? AppColors.textSecondary : Colors.black54;
    
    return GestureDetector(
      onTap: () => subscriptionProvider.selectPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        ),
        child: Column(
          children: [
            AppText.bodyMedium(
              title,
              color: isSelected ? AppColors.primary : textColor,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: 4),
            AppText.bodyLarge(
              price,
              color: isSelected ? AppColors.primary : textColor,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
            AppText.bodySmall(
              subtitle,
              color: isSelected ? AppColors.primary : subtitleColor,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionProvider subscriptionProvider, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDark;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;

    if (subscriptionProvider.error != null || !subscriptionProvider.hasAllProducts) {
      return _buildErrorCard(subscriptionProvider, themeProvider);
    }

    if (!subscriptionProvider.isInitialized || subscriptionProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    final isYearly = subscriptionProvider.selectedPlan == SubscriptionPlan.yearly;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            (isDark ? AppColors.primary.withOpacity(0.05) : AppColors.primary.withOpacity(0.02)),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primary).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with plan info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Column(
              children: [
                if (isYearly) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText.bodySmall(
                      '50% OFF',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AppText.headlineMedium(
                  isYearly ? 'Yearly Pro' : 'Monthly Pro',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                AppText.bodyLarge(
                  subscriptionProvider.selectedProduct?.price ?? '...',
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
                AppText.bodySmall(
                  isYearly ? 'per year' : 'per month',
                  color: Colors.white.withOpacity(0.8),
                ),
              ],
            ),
          ),
          
          // Features list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.bodyMedium(
                    isYearly ? 'Everything in Free & Monthly Pro:' : 'Premium Features:',
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildFeaturesList(textColor, isYearly),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(Color textColor, bool isYearly) {
    final features = isYearly ? [
      'Unlimited conversations',
      'All AI personalities',
      'Unlimited image generation',
      'Unlimited voice interactions',
      'Priority customer support',
      'Advanced AI models',
      'Custom conversation settings',
      'Export conversation history',
    ] : [
      'Unlimited conversations',
      'All AI personalities', 
      'Priority support',
      'Advanced features',
    ];

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText.bodySmall(
                  features[index],
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorCard(SubscriptionProvider subscriptionProvider, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDark;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          AppText.bodyMedium(
            'Unable to load plans',
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          AppText.bodySmall(
            subscriptionProvider.error ?? 'Please try again',
            color: isDark ? AppColors.textSecondary : Colors.black54,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          AppButton.outline(
            text: 'Retry',
            onPressed: () async {
              try {
                await subscriptionProvider.refreshProducts();
              } catch (e) {
                if (mounted) {
                  SubscriptionUtils.showErrorSnackBar(
                    context,
                    'Failed to refresh: ${e.toString()}',
                  );
                }
              }
            },
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SubscriptionProvider subscriptionProvider) {
    return Column(
      children: [
        AppButton.primary(
          text: subscriptionProvider.isLoading ? 'Processing...' : 'Subscribe Now',
          onPressed: subscriptionProvider.isLoading ? null : _handlePurchase,
          isFullWidth: true,
          isLoading: subscriptionProvider.isLoading,
        ),
        const SizedBox(height: 12),
        AppButton.text(
          text: _isRestoreLoading ? 'Restoring...' : 'Restore Purchases',
          onPressed: _isRestoreLoading ? null : _handleRestorePurchases,
          isLoading: _isRestoreLoading,
        ),
      ],
    );
  }
}