import 'package:ai_chatbot_app/screens/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
import 'personas_screen.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.displayName;
    final userEmail = authProvider.email;
    final photoUrl = authProvider.userPhotoUrl;

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
                    'Settings',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  centerTitle: true,
                ),
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Profile Section
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
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: photoUrl == null
                                ? Icon(Icons.person, size: 36, color: AppColors.primary)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText.displayMedium(
                                userName,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              const SizedBox(height: 4),
                              AppText.bodyMedium(
                                userEmail,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Account Information Section
                  _buildSection(
                    'Account Information',
                    [
                      _buildInfoTile('Email', userEmail, Icons.email_outlined),
                      _buildInfoTile('Phone number', '+923103535835', Icons.phone_outlined),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Preferences Section
                  _buildSection(
                    'Preferences',
                    [
                      _buildOptionTile(
                        Icons.workspace_premium_rounded, 
                        'Upgrade to Plus', 
                        'Unlock premium features',
                        () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                        },
                      ),
                      _buildOptionTile(
                        Icons.person_pin_circle, 
                        'Personalization', 
                        'Customize your experience',
                        () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonaScreen()));
                        },
                      ),
                      _buildOptionTile(
                        Icons.data_usage_rounded, 
                        'Data Controls', 
                        'Manage your data',
                        () {},
                      ),
                      _buildOptionTile(
                        Icons.graphic_eq_rounded, 
                        'Voice', 
                        'Voice settings and preferences',
                        () {},
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Security & Support Section
                  _buildSection(
                    'Security & Support',
                    [
                      _buildOptionTile(
                        Icons.lock_outline, 
                        'Security', 
                        'Privacy and security settings',
                        () {},
                      ),
                      _buildOptionTile(
                        Icons.info_outline, 
                        'About', 
                        'App information and version',
                        () {},
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Sign Out Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final confirmed = await _showSignOutDialog(context);
                          if (confirmed == true) {
                            await authProvider.logout();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                              (route) => false,
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.logout,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText.bodyLarge(
                                    'Sign out',
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  AppText.bodySmall(
                                    'Sign out from your account',
                                    color: AppColors.error.withOpacity(0.7),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppColors.error,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildOptionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyLarge(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 2),
                    AppText.bodySmall(
                      subtitle,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.bodySmall(
                  label,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 4),
                AppText.bodyLarge(
                  value,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSignOutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText.displayMedium('Sign Out', color: AppColors.textPrimary),
        content: AppText.bodyMedium(
          'Are you sure you want to sign out of your account?',
          color: AppColors.textSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: AppText.bodyMedium('Cancel', color: AppColors.textSecondary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium('Sign Out', color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}