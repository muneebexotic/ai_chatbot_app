import 'package:flutter/material.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
// import 'services/payment_service.dart'; // Uncomment when you create the service

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // final PaymentService _paymentService = PaymentService(); // Uncomment when ready
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
  }

  Future<void> _initializePaymentService() async {
    try {
      // await _paymentService.initialize(); // Uncomment when ready
      
      // Set up callbacks
      // _paymentService.onPurchaseResult = (success, message) {
      //   _showPurchaseResult(success, message);
      // };
      
      // _paymentService.onSubscriptionStatusChanged = (isSubscribed) {
      //   // Handle subscription status change
      //   if (isSubscribed) {
      //     Navigator.of(context).pop(); // Go back or navigate to premium features
      //   }
      // };
    } catch (e) {
      print('Failed to initialize payment service: $e');
      _showError('Payment service unavailable. Please try again later.');
    }
  }

  Future<void> _handleClaimOffer() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Show confirmation dialog first
      final bool? confirmed = await _showPurchaseConfirmation();
      
      if (confirmed == true) {
        // Start purchase process
        // await _paymentService.purchaseSubscription(); // Uncomment when ready
        
        // For now, show a placeholder message
        _showError('Payment service integration in progress. Please complete the setup first.');
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool?> _showPurchaseConfirmation() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppText.displayMedium(
            'Confirm Purchase',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          content: AppText.bodyMedium(
            'You are about to purchase Monthly Subscription for \$12. This will give you access to all premium features.',
            color: AppColors.textSecondary,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showPurchaseResult(bool success, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppText.displayMedium(
            success ? 'Success!' : 'Purchase Failed',
            color: success ? AppColors.primary : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
          content: AppText.bodyMedium(
            message,
            color: AppColors.textSecondary,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText.bodyMedium(
                'OK',
                color: AppColors.textPrimary,
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
                    icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: AppText.bodyLarge(
                    'Subscription',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  centerTitle: true,
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Most Popular Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AppText.bodySmall(
                        'Most Popular',
                        color: AppColors.background,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Subscription Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                            'Monthly',
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText.bodyMedium(
                                '\$',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              AppText.displayLarge(
                                '12',
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          AppText.bodySmall(
                            'per month',
                            color: AppColors.textSecondary,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Features List
                          _buildFeatureItem('1000 AI Messages', Icons.message_outlined),
                          const SizedBox(height: 20),
                          _buildFeatureItem('Secure Your Data', Icons.security_outlined),
                          const SizedBox(height: 20),
                          _buildFeatureItem('Daily Updates', Icons.update_outlined),
                          const SizedBox(height: 20),
                          _buildFeatureItem('Unlimited Access', Icons.all_inclusive_outlined),
                          const SizedBox(height: 20),
                          _buildFeatureItem('Next Level AI', Icons.psychology_outlined),
                          
                          const SizedBox(height: 32),
                          
                          // Claim Offer Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleClaimOffer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: AppColors.primary.withOpacity(0.3),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.background,
                                        ),
                                      ),
                                    )
                                  : AppText.bodyLarge(
                                      'Claim Offer',
                                      color: AppColors.background,
                                      fontWeight: FontWeight.w600,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Benefits Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
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
                            'Unlock the full potential of AI with advanced features, priority support, and unlimited access.',
                            color: AppColors.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Payment Notice
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
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
                                'Payment Notice',
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AppText.bodySmall(
                            'Balance must be paid in full within the time limit indicated in the Payment Notice. Subscription auto-renews monthly.',
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
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 16,
          ),
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
          child: Icon(
            Icons.check,
            color: AppColors.primary,
            size: 16,
          ),
        ),
      ],
    );
  }
}