import 'package:flutter/material.dart';

import '../../components/ui/app_text.dart';
import '../../models/subscription_models.dart';
import '../../utils/app_theme.dart';

/// Purchase confirmation dialog widget
class PurchaseConfirmationDialog extends StatelessWidget {
  final SubscriptionProduct product;
  final String? yearlySavingsText;

  const PurchaseConfirmationDialog({
    required this.product,
    this.yearlySavingsText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: AppText.displayMedium(
        'Confirm Purchase',
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.bodyMedium(
              'You are about to purchase:',
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            _buildPurchaseDetails(),
            const SizedBox(height: 16),
            _buildBenefitsList(),
          ],
        ),
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
  }

  Widget _buildPurchaseDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.bodyLarge(
            product.plan.displayName,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 4),
          AppText.bodySmall(
            product.price,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          if (product.plan == SubscriptionPlan.yearly && 
              yearlySavingsText != null && 
              yearlySavingsText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: AppText.bodySmall(
                yearlySavingsText!,
                color: AppColors.background,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    return AppText.bodySmall(
      'This will give you access to:\n'
      '• Unlimited messages and conversations\n'
      '• All AI personas and personalities\n'
      '• Unlimited image generation\n'
      '• Unlimited voice interactions\n'
      '• Priority customer support',
      color: AppColors.textSecondary,
    );
  }

  /// Show the purchase confirmation dialog
  static Future<bool> show(
    BuildContext context, {
    required SubscriptionProduct product,
    String? yearlySavingsText,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PurchaseConfirmationDialog(
        product: product,
        yearlySavingsText: yearlySavingsText,
      ),
    ) ?? false;
  }
}