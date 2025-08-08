import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
import '../screens/subscription_screen.dart';

class PersonaScreen extends StatelessWidget {
  const PersonaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, AuthProvider>(
      builder: (context, settingsProvider, authProvider, child) {
        final isPremium = authProvider.isPremium;
        final availablePersonas = settingsProvider.getAvailablePersonas(isPremium);

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
                        'Bot Persona',
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      centerTitle: true,
                      actions: [
                        if (!isPremium)
                          IconButton(
                            icon: Icon(Icons.star, color: AppColors.primary),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SubscriptionScreen(),
                              ),
                            ),
                            tooltip: 'Upgrade to Premium',
                          ),
                      ],
                    ),
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.psychology,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppText.displayMedium(
                                        'Choose Your AI Persona',
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      const SizedBox(height: 4),
                                      AppText.bodyMedium(
                                        isPremium 
                                          ? 'Access all personas with your Premium subscription'
                                          : 'Free users have access to ${availablePersonas.length} personas',
                                        color: isPremium 
                                          ? AppColors.success 
                                          : AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Personas Section
                      _buildSection(
                        'Available Personas',
                        SettingsProvider.availablePersonas.map((persona) => 
                          _buildPersonaTile(
                            _getPersonaIcon(persona['id']),
                            persona['name'],
                            settingsProvider.getPersonaDescription(persona['id']),
                            persona['id'],
                            persona['isPremium'] ?? false,
                            settingsProvider.persona,
                            settingsProvider,
                            authProvider,
                            context,
                          ),
                        ).toList(),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Premium Banner (only for free users)
                      if (!isPremium) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.1),
                                AppColors.secondary.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        AppText.bodyMedium(
                                          'Unlock More Personas',
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        const SizedBox(height: 4),
                                        AppText.bodySmall(
                                          'Get ${settingsProvider.premiumPersonaCount} additional personas with Premium',
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SubscriptionScreen(),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: AppText.bodyMedium(
                                    'Upgrade to Premium',
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // Info Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText.bodyMedium(
                                    'Persona Effects',
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  const SizedBox(height: 4),
                                  AppText.bodySmall(
                                    'Your chosen persona will influence the AI\'s tone, style, and approach to conversations. You can change this anytime.',
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getPersonaIcon(String personaId) {
    switch (personaId) {
      case 'Default':
        return Icons.psychology_outlined;
      case 'Friendly Assistant':
        return Icons.sentiment_very_satisfied;
      case 'Strict Teacher':
        return Icons.school;
      case 'Wise Philosopher':
        return Icons.auto_stories;
      case 'Sarcastic Developer':
        return Icons.code;
      case 'Motivational Coach':
        return Icons.fitness_center;
      default:
        return Icons.psychology_outlined;
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: AppText.bodyMedium(
            title,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonaTile(
    IconData icon,
    String title,
    String description,
    String value,
    bool isPremiumPersona,
    String currentPersona,
    SettingsProvider settingsProvider,
    AuthProvider authProvider,
    BuildContext context,
  ) {
    final bool isSelected = currentPersona == value;
    final bool isPremiumUser = authProvider.isPremium;
    final bool canAccess = !isPremiumPersona || isPremiumUser;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (!canAccess) {
            // Show premium dialog
            _showPremiumDialog(context);
          } else {
            try {
              await settingsProvider.setPersona(value, isPremium: isPremiumUser);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    e.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(fontFamily: 'Poppins'),
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
        child: Opacity(
          opacity: canAccess ? 1.0 : 0.6,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected 
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                    if (isPremiumPersona && !isPremiumUser)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star,
                            color: AppColors.background,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText.bodyLarge(
                              title,
                              color: isSelected 
                                  ? AppColors.primary
                                  : (canAccess ? AppColors.textPrimary : AppColors.textSecondary),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isPremiumPersona && !isPremiumUser)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: AppText.bodySmall(
                                'PRO',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AppText.bodySmall(
                        description,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (canAccess)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        width: 2,
                      ),
                      color: isSelected 
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: AppColors.background,
                          )
                        : null,
                  )
                else
                  Icon(
                    Icons.lock_outline,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.star, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            AppText.displayMedium(
              'Premium Required',
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.bodyMedium(
              'This persona requires a Premium subscription.',
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.bodyMedium(
                    'Premium includes:',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 8),
                  AppText.bodySmall(
                    '• All personas unlocked\n• Unlimited messages\n• Unlimited images & voice\n• Priority support',
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: AppText.bodyMedium(
              'Later',
              color: AppColors.textSecondary,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium(
              'Upgrade',
              color: AppColors.background,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}