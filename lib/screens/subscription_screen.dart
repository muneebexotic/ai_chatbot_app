import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  String _selectedPlan = PaymentService.monthlySubscriptionId;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final paymentService = authProvider.paymentService;

      setState(() {
        _products = paymentService.products;
      });

      // Wait a bit and retry if products are empty
      if (_products.isEmpty) {
        await Future.delayed(Duration(seconds: 2));
        setState(() {
          _products = paymentService.products;
        });
      }

      if (!areProductsLoaded) {
        _showError(
          'Unable to load subscription plans. Please check your internet connection and try again.',
        );
      }
    } catch (e) {
      print('Failed to load products: $e');
      _showError('Failed to load subscription plans. Please try again later.');
    }
  }

  ProductDetails? get monthlyProduct {
    try {
      return _products.firstWhere(
        (p) => p.id == PaymentService.monthlySubscriptionId,
      );
    } catch (e) {
      return null; // Return null if not found
    }
  }

  ProductDetails? get yearlyProduct {
    try {
      return _products.firstWhere(
        (p) => p.id == PaymentService.yearlySubscriptionId,
      );
    } catch (e) {
      return null; // Return null if not found
    }
  }

  Future<void> _handlePurchase(String productId) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if user is authenticated
      if (!authProvider.isLoggedIn) {
        _showError('Please log in to purchase subscription.');
        return;
      }

      // Show confirmation dialog first
      final bool? confirmed = await _showPurchaseConfirmation(productId);

      if (confirmed == true) {
        // Start purchase process
        await authProvider.paymentService.purchaseSubscription(productId);
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to check if products are ready
  bool get areProductsLoaded {
    return _products.isNotEmpty &&
        monthlyProduct != null &&
        yearlyProduct != null;
  }

  Future<bool?> _showPurchaseConfirmation(String productId) async {
    final product = _products.firstWhere((p) => p.id == productId);
    final isMonthly = productId == PaymentService.monthlySubscriptionId;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppText.displayMedium(
            'Confirm Purchase',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.bodyMedium(
                'You are about to purchase:',
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyLarge(
                      isMonthly ? 'Monthly Pro Access' : 'Yearly Pro Access',
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    AppText.bodySmall(
                      product.price,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    if (!isMonthly) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: AppText.bodySmall(
                          'SAVE 50%',
                          color: AppColors.background,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppText.bodySmall(
                'This will give you access to:\n• Unlimited messages\n• All personas\n• Priority support',
                color: AppColors.textSecondary,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: AppText.bodyMedium(
                'Cancel',
                color: AppColors.textSecondary,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText.bodyMedium(
                'Purchase',
                color: AppColors.background,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background,
                  AppColors.surface,
                  AppColors.background,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              children: [
                // Custom App Bar
                SafeArea(
                  bottom: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withOpacity(0.9),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: AppText.bodyLarge(
                        'Upgrade to Premium',
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      centerTitle: true,
                      actions: [
                        if (authProvider.isPremium)
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AppText.bodySmall(
                              'Premium',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Current Status Card
                        if (!authProvider.isPremium) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(height: 12),
                                AppText.bodyLarge(
                                  'Free Plan Limits',
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                const SizedBox(height: 8),
                                AppText.bodyMedium(
                                  authProvider.usageText,
                                  color: AppColors.textSecondary,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (authProvider.isPremium) ...[
                          // Premium Status Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.1),
                                  AppColors.primary.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium,
                                    color: AppColors.background,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AppText.displayMedium(
                                  'You\'re Premium!',
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                const SizedBox(height: 8),
                                AppText.bodyMedium(
                                  authProvider.subscriptionStatus,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                AppText.bodySmall(
                                  'Enjoy unlimited access to all features!',
                                  color: AppColors.textSecondary,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Subscription Plans
                        if (!authProvider.isPremium) ...[
                          // Plan Selection Toggle
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedPlan =
                                          PaymentService.monthlySubscriptionId;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _selectedPlan ==
                                                PaymentService
                                                    .monthlySubscriptionId
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: AppText.bodyMedium(
                                        'Monthly',
                                        color:
                                            _selectedPlan ==
                                                PaymentService
                                                    .monthlySubscriptionId
                                            ? AppColors.background
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedPlan =
                                          PaymentService.yearlySubscriptionId;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _selectedPlan ==
                                                PaymentService
                                                    .yearlySubscriptionId
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AppText.bodyMedium(
                                            'Yearly',
                                            color:
                                                _selectedPlan ==
                                                    PaymentService
                                                        .yearlySubscriptionId
                                                ? AppColors.background
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          Positioned(
                                            top: -4,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: AppText.bodySmall(
                                                'SAVE 50%',
                                                color: AppColors.background,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Selected Subscription Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.1),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Premium Icon
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium,
                                    size: 32,
                                    color: AppColors.primary,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                AppText.displayLarge(
                                  _selectedPlan ==
                                          PaymentService.monthlySubscriptionId
                                      ? 'Monthly Pro'
                                      : 'Yearly Pro',
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),

                                const SizedBox(height: 8),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText.bodyMedium(
                                      _selectedPlan ==
                                              PaymentService
                                                  .monthlySubscriptionId
                                          ? (monthlyProduct?.currencyCode ??
                                                'PKR')
                                          : (yearlyProduct?.currencyCode ??
                                                'PKR'),
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    const SizedBox(width: 4),
                                    AppText.displayLarge(
                                      _selectedPlan ==
                                              PaymentService
                                                  .monthlySubscriptionId
                                          ? '59'
                                          : '360',
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                AppText.bodySmall(
                                  _selectedPlan ==
                                          PaymentService.monthlySubscriptionId
                                      ? 'per month'
                                      : 'per year',
                                  color: AppColors.textSecondary,
                                ),

                                if (_selectedPlan ==
                                    PaymentService.yearlySubscriptionId) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: AppText.bodySmall(
                                      'Save 50% vs Monthly',
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 32),

                                // Features List
                                _buildFeatureItem(
                                  'Unlimited Messages',
                                  Icons.message_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildFeatureItem(
                                  'All Personas',
                                  Icons.psychology_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildFeatureItem(
                                  'Unlimited Images',
                                  Icons.image_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildFeatureItem(
                                  'Unlimited Voice',
                                  Icons.mic_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildFeatureItem(
                                  'Priority Support',
                                  Icons.support_agent_outlined,
                                ),

                                const SizedBox(height: 32),

                                // Purchase Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _handlePurchase(_selectedPlan),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      disabledBackgroundColor: AppColors.primary
                                          .withOpacity(0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      shadowColor: AppColors.primary
                                          .withOpacity(0.3),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.background,
                                                  ),
                                            ),
                                          )
                                        : AppText.bodyLarge(
                                            'Upgrade Now',
                                            color: AppColors.background,
                                            fontWeight: FontWeight.w600,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

                        // Benefits Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 12),
                              AppText.bodyLarge(
                                'Why Choose Premium?',
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              const SizedBox(height: 8),
                              AppText.bodyMedium(
                                'Unlock the full potential of AI with unlimited access, all personas, and priority support.',
                                color: AppColors.textSecondary,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Restore Purchases Button
                        if (!authProvider.isPremium)
                          TextButton(
                            onPressed: () async {
                              try {
                                await authProvider.paymentService
                                    .restorePurchases();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Purchases restored successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                _showError('Failed to restore purchases');
                              }
                            },
                            child: AppText.bodyMedium(
                              'Restore Purchases',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        // Payment Notice
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  AppText.bodyMedium(
                                    'Subscription Terms',
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AppText.bodySmall(
                                'Subscription auto-renews unless cancelled. You can manage or cancel your subscription anytime in your Google Play account settings.',
                                color: AppColors.textSecondary,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AppText.bodyMedium(
            text,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: AppColors.primary, size: 16),
        ),
      ],
    );
  }
}
