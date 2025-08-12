import 'package:flutter/material.dart';

import '../../components/ui/app_text.dart';
import '../../models/subscription_models.dart';
import '../../utils/app_theme.dart';

/// Premium status indicator badge
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppText.bodySmall(
        'Premium',
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Reusable information card widget
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.backgroundColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            AppText.bodyLarge(
              title,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText.bodyMedium(
              subtitle,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Plan selector toggle widget
class PlanSelector extends StatelessWidget {
  final SubscriptionPlan selectedPlan;
  final ValueChanged<SubscriptionPlan> onPlanChanged;
  final String? yearlySavingsText;

  const PlanSelector({
    required this.selectedPlan,
    required this.onPlanChanged,
    this.yearlySavingsText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlanSelectorButton(
              title: 'Monthly',
              isSelected: selectedPlan == SubscriptionPlan.monthly,
              onTap: () => onPlanChanged(SubscriptionPlan.monthly),
            ),
          ),
          Expanded(
            child: _PlanSelectorButton(
              title: 'Yearly',
              isSelected: selectedPlan == SubscriptionPlan.yearly,
              onTap: () => onPlanChanged(SubscriptionPlan.yearly),
              savingsText: yearlySavingsText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual plan selector button
class _PlanSelectorButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final String? savingsText;

  const _PlanSelectorButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.savingsText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppText.bodyMedium(
              title,
              color: isSelected ? AppColors.background : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            if (savingsText != null && savingsText!.isNotEmpty)
              _buildSavingsBadge(savingsText!),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsBadge(String text) {
    return Positioned(
      top: -4,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AppText.bodySmall(
          text,
          color: AppColors.background,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Premium status display card
class PremiumStatusCard extends StatelessWidget {
  final String subscriptionStatus;

  const PremiumStatusCard({
    required this.subscriptionStatus,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildPremiumIcon(),
          const SizedBox(height: 16),
          AppText.displayMedium(
            'You\'re Premium!',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          AppText.bodyMedium(
            subscriptionStatus,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          AppText.bodySmall(
            'Enjoy unlimited access to all features!',
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumIcon() {
    return Container(
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
    );
  }
}

/// Subscription card displaying plan details and purchase button
class SubscriptionCard extends StatelessWidget {
  final SubscriptionProduct product;
  final bool isLoading;
  final VoidCallback onPurchase;
  final String? yearlySavingsText;

  const SubscriptionCard({
    required this.product,
    required this.isLoading,
    required this.onPurchase,
    this.yearlySavingsText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildPremiumIcon(),
          const SizedBox(height: 20),
          _buildPlanTitle(),
          const SizedBox(height: 8),
          _buildPricing(),
          const SizedBox(height: 8),
          _buildPeriodText(),
          if (product.plan == SubscriptionPlan.yearly && 
              yearlySavingsText != null && 
              yearlySavingsText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSavingsBadge(),
          ],
          const SizedBox(height: 32),
          const FeaturesList(),
          const SizedBox(height: 32),
          _buildPurchaseButton(),
        ],
      ),
    );
  }

  Widget _buildPremiumIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.workspace_premium, size: 32, color: AppColors.primary),
    );
  }

  Widget _buildPlanTitle() {
    return AppText.displayLarge(
      product.plan.displayName,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }

  Widget _buildPricing() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.bodyMedium(
          product.currencyCode,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(width: 4),
        AppText.displayLarge(
          _extractPriceNumber(product.price),
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _buildPeriodText() {
    return AppText.bodySmall(
      product.plan.periodText,
      color: AppColors.textSecondary,
    );
  }

  Widget _buildSavingsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.bodySmall(
        yearlySavingsText ?? '',
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
                ),
              )
            : AppText.bodyLarge(
                'Upgrade Now',
                color: AppColors.background,
                fontWeight: FontWeight.w600,
              ),
      ),
    );
  }

  String _extractPriceNumber(String price) {
    // Extract numeric part from price string
    final regex = RegExp(r'[\d,]+\.?\d*');
    final match = regex.firstMatch(price);
    return match?.group(0)?.replaceAll(',', '') ?? '0';
  }
}

/// Features list widget displaying subscription benefits
class FeaturesList extends StatelessWidget {
  const FeaturesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: SubscriptionFeature.premiumFeatures
          .map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _FeatureItem(feature: feature),
              ))
          .toList(),
    );
  }
}

/// Individual feature item widget
class _FeatureItem extends StatelessWidget {
  final SubscriptionFeature feature;

  const _FeatureItem({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getIconData(feature.iconName), color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AppText.bodyMedium(
            feature.title,
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

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'message_outlined':
        return Icons.message_outlined;
      case 'psychology_outlined':
        return Icons.psychology_outlined;
      case 'image_outlined':
        return Icons.image_outlined;
      case 'mic_outlined':
        return Icons.mic_outlined;
      case 'support_agent_outlined':
        return Icons.support_agent_outlined;
      default:
        return Icons.star_outlined;
    }
  }
}

/// Loading card placeholder
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Subscription terms and conditions widget
class SubscriptionTerms extends StatelessWidget {
  const SubscriptionTerms({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
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
    );
  }
}

/// Restore purchases button widget
class RestorePurchasesButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const RestorePurchasesButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
          ],
          AppText.bodyMedium(
            'Restore Purchases',
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}