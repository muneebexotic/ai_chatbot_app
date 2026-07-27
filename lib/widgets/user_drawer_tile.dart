import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_theme.dart';
import '../app/providers.dart';

class UserDrawerTile extends ConsumerWidget {
  const UserDrawerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(authNotifierProvider).userPhotoUrl;
    final username = ref.watch(authNotifierProvider).displayName;
    final isDark = ref.watch(themeNotifierProvider).isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/settings');
        },
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              avatarUrl != null &&
                      (avatarUrl.contains('/svg') || avatarUrl.endsWith('.svg'))
                  ? ClipOval(
                      child: SvgPicture.network(
                        avatarUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        placeholderBuilder: (_) => CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.getSurfaceVariant(isDark),
                          child: Icon(
                            Icons.person,
                            color: AppColors.getTextSecondary(isDark),
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.getSurfaceVariant(isDark),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : const AssetImage('assets/images/user_avatar.png')
                              as ImageProvider,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              color: AppColors.getTextSecondary(isDark),
                              size: 20,
                            )
                          : null,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  username,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'GeneralSans',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.settings,
                color: AppColors.getTextSecondary(isDark),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}