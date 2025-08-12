import 'package:ai_chatbot_app/widgets/subscription_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/ui/app_text.dart';
import '../models/subscription_models.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/app_theme.dart';
import '../utils/subscription_utils.dart';
import '../widgets/subscription/purchase_confirmation_dialog.dart';

/// Premium subscription management screen
/// Handles subscription plan selection, purchasing, and status display
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isRestoreLoading = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeSubscription();
  }

  /// Initialize subscription provider and load products
  void _initializeSubscription() async {
    if (mounted) {
      setState(() => _isInitializing = true);
    }
    
    try {
      // Wait a bit to ensure providers are ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      final subscriptionProvider = context.read<SubscriptionProvider>();
      
      // Initialize subscription provider
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

  /// Handle subscription purchase flow
  Future<void> _handlePurchase() async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    // Validate user authentication
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

    // Show purchase confirmation
    final confirmed = await PurchaseConfirmationDialog.show(
      context,
      product: product,
      yearlySavingsText: subscriptionProvider.getYearlySavingsText(),
    );

    if (!confirmed) return;

    // Execute purchase
    try {
      await subscriptionProvider.purchaseSubscription();
      // Success handling is typically done through payment service callbacks
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

  /// Handle purchase restoration
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
    return Consumer2<AuthProvider, SubscriptionProvider>(
      builder: (context, authProvider, subscriptionProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: _buildBody(authProvider, subscriptionProvider),
        );
      },
    );
  }

  /// Build main body with gradient background
  Widget _buildBody(
    AuthProvider authProvider,
    SubscriptionProvider subscriptionProvider,
  ) {
    return Container(
      decoration: _buildGradientDecoration(),
      child: Column(
        children: [
          _buildAppBar(authProvider),
          Expanded(
            child: _buildScrollableContent(authProvider, subscriptionProvider),
          ),
        ],
      ),
    );
  }

  /// Build gradient background decoration
  BoxDecoration _buildGradientDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.background, AppColors.surface, AppColors.background],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  /// Build custom app bar
  Widget _buildAppBar(AuthProvider authProvider) {
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.9),
          border: Border(
            bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: AppText.bodyLarge(
            'Upgrade to Premium',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          centerTitle: true,
          actions: [if (authProvider.isPremium) const PremiumBadge()],
        ),
      ),
    );
  }

  /// Build scrollable content area
  Widget _buildScrollableContent(
    AuthProvider authProvider,
    SubscriptionProvider subscriptionProvider,
  ) {
    // Show loading while initializing
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            AppText.bodyMedium(
              'Loading subscription plans...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (authProvider.isPremium)
            _buildPremiumSection(authProvider)
          else
            _buildUpgradeSection(authProvider, subscriptionProvider),
          const SizedBox(height: 32),
          _buildBenefitsSection(),
          const SizedBox(height: 24),
          const SubscriptionTerms(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build premium user section
  Widget _buildPremiumSection(AuthProvider authProvider) {
    return PremiumStatusCard(
      subscriptionStatus: authProvider.subscriptionStatus,
    );
  }

  /// Build upgrade section for free users
  Widget _buildUpgradeSection(
    AuthProvider authProvider,
    SubscriptionProvider subscriptionProvider,
  ) {
    return Column(
      children: [
        InfoCard(
          icon: Icons.info_outline,
          title: 'Free Plan Limits',
          subtitle: authProvider.usageText,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        _buildPlanSelectorSection(subscriptionProvider),
        const SizedBox(height: 32),
        _buildSubscriptionCardSection(subscriptionProvider),
        const SizedBox(height: 32),
        _buildRestorePurchasesSection(),
      ],
    );
  }

  /// Build plan selector section
  Widget _buildPlanSelectorSection(SubscriptionProvider subscriptionProvider) {
    return PlanSelector(
      selectedPlan: subscriptionProvider.selectedPlan,
      onPlanChanged: subscriptionProvider.selectPlan,
      yearlySavingsText: subscriptionProvider.getYearlySavingsText(),
    );
  }

  /// Build subscription card section
  Widget _buildSubscriptionCardSection(
    SubscriptionProvider subscriptionProvider,
  ) {
    // Show error if there's an issue
    if (subscriptionProvider.error != null) {
      return _buildErrorCard(subscriptionProvider);
    }

    // Show loading while initializing or loading
    if (!subscriptionProvider.isInitialized || subscriptionProvider.isLoading) {
      return const LoadingCard();
    }

    // Check if we have all required products
    if (!subscriptionProvider.hasAllProducts) {
      return _buildErrorCard(subscriptionProvider);
    }

    final selectedProduct = subscriptionProvider.selectedProduct;
    if (selectedProduct == null) {
      return _buildErrorCard(subscriptionProvider);
    }

    return SubscriptionCard(
      product: selectedProduct,
      isLoading: subscriptionProvider.isLoading,
      onPurchase: _handlePurchase,
      yearlySavingsText:
          subscriptionProvider.selectedPlan == SubscriptionPlan.yearly
          ? subscriptionProvider.getYearlySavingsText()
          : null,
    );
  }

  /// Build error card with retry option
  Widget _buildErrorCard(SubscriptionProvider subscriptionProvider) {
    final errorMessage = subscriptionProvider.error ?? 
        'Unable to load subscription plans. Please try again.';
    
    return InfoCard(
      icon: Icons.error_outline,
      title: 'Unable to Load Plans',
      subtitle: errorMessage,
      color: AppColors.error,
      onTap: () async {
        // Retry loading products
        try {
          await subscriptionProvider.refreshProducts();
        } catch (e) {
          if (mounted) {
            SubscriptionUtils.showErrorSnackBar(
              context, 
              'Failed to refresh products: ${e.toString()}',
            );
          }
        }
      },
    );
  }

  /// Build restore purchases section
  Widget _buildRestorePurchasesSection() {
    return RestorePurchasesButton(
      onPressed: _handleRestorePurchases,
      isLoading: _isRestoreLoading,
    );
  }

  /// Build benefits section
  Widget _buildBenefitsSection() {
    return InfoCard(
      icon: Icons.star_rounded,
      title: 'Why Choose Premium?',
      subtitle:
          'Unlock the full potential of AI with unlimited access, all personas, and priority support.',
      color: AppColors.primary,
      backgroundColor: AppColors.primary.withOpacity(0.05),
    );
  }
}