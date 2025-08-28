import 'package:ai_chatbot_app/screens/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Add this import
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/themes_provider.dart'; // Add theme provider import
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
import 'personas_screen.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context); // Add theme provider
    final userName = authProvider.displayName;
    final userEmail = authProvider.email;
    final photoUrl = authProvider.userPhotoUrl;

    // Use theme-aware colors
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundColor,
              surfaceColor,
              backgroundColor,
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
                  color: backgroundColor.withOpacity(0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: primaryColor.withOpacity(0.1),
                    ),
                  ),
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: textPrimaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: AppText.bodyLarge(
                    'Settings',
                    color: textPrimaryColor,
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
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.1),
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
                              color: primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: _buildUserAvatar(photoUrl, primaryColor, themeProvider.isDark),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText.displayMedium(
                                userName,
                                color: textPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              const SizedBox(height: 4),
                              AppText.bodyMedium(
                                userEmail,
                                color: textSecondaryColor,
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
                    context,
                    'Account Information',
                    [
                      _buildInfoTile(context, 'Email', userEmail, Icons.email_outlined),
                      _buildInfoTile(context, 'Phone number', '+923103535835', Icons.phone_outlined),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Appearance Section - NEW
                  _buildSection(
                    context,
                    'Appearance',
                    [
                      _buildThemeToggleTile(context, themeProvider),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Preferences Section
                  _buildSection(
                    context,
                    'Preferences',
                    [
                      _buildOptionTile(
                        context,
                        Icons.workspace_premium_rounded, 
                        'Upgrade to Plus', 
                        'Unlock premium features',
                        () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                        },
                      ),
                      _buildOptionTile(
                        context,
                        Icons.person_pin_circle, 
                        'Personalization', 
                        'Customize your experience',
                        () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonaScreen()));
                        },
                      ),
                      _buildOptionTile(
                        context,
                        Icons.data_usage_rounded, 
                        'Data Controls', 
                        'Manage your data',
                        () {},
                      ),
                      _buildOptionTile(
                        context,
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
                    context,
                    'Security & Support',
                    [
                      _buildOptionTile(
                        context,
                        Icons.lock_outline, 
                        'Security', 
                        'Privacy and security settings',
                        () {},
                      ),
                      _buildOptionTile(
                        context,
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

  // NEW: Build user avatar with SVG support
  Widget _buildUserAvatar(String? photoUrl, Color primaryColor, bool isDark) {
    if (photoUrl != null && (photoUrl.contains('/svg') || photoUrl.endsWith('.svg'))) {
      // Handle SVG avatars (like DiceBear)
      return ClipOval(
        child: SvgPicture.network(
          photoUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => CircleAvatar(
            radius: 32,
            backgroundColor: primaryColor.withOpacity(0.1),
            child: Icon(
              Icons.person,
              size: 36,
              color: primaryColor,
            ),
          ),
        ),
      );
    } else {
      // Handle regular images and fallback
      return CircleAvatar(
        radius: 32,
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : const AssetImage('assets/images/user_avatar.png') as ImageProvider,
        backgroundColor: primaryColor.withOpacity(0.1),
        child: photoUrl == null || photoUrl.isEmpty
            ? Icon(Icons.person, size: 36, color: primaryColor)
            : null,
      );
    }
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final primaryColor = Theme.of(context).primaryColor;
    final textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: AppText.bodyMedium(
            title,
            color: textSecondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.1)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  // NEW: Theme toggle tile
  Widget _buildThemeToggleTile(BuildContext context, ThemeProvider themeProvider) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.bodyLarge(
                  'Appearance',
                  color: textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 2),
                AppText.bodySmall(
                  themeProvider.isDark ? 'Dark mode' : 'Light mode',
                  color: textSecondaryColor,
                ),
              ],
            ),
          ),
          Switch(
            value: themeProvider.isDark,
            onChanged: (value) => themeProvider.toggleTheme(),
            activeColor: primaryColor,
            activeTrackColor: primaryColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final textTertiaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
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
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 2),
                    AppText.bodySmall(
                      subtitle,
                      color: textSecondaryColor,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: textTertiaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, IconData icon) {
    final primaryColor = Theme.of(context).primaryColor;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
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
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 4),
                AppText.bodyLarge(
                  value,
                  color: textPrimaryColor,
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
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText.displayMedium('Sign Out', color: textPrimaryColor),
        content: AppText.bodyMedium(
          'Are you sure you want to sign out of your account?',
          color: textSecondaryColor,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: AppText.bodyMedium('Cancel', color: textSecondaryColor),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium('Sign Out', color: Colors.white),
          ),
        ],
      ),
    );
  }
}