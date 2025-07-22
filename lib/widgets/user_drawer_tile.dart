import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class UserDrawerTile extends StatelessWidget {
  const UserDrawerTile({super.key});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = Provider.of<AuthProvider>(context).userPhotoUrl;
    final username = Provider.of<AuthProvider>(context).displayName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/settings');
        },
        borderRadius: BorderRadius.circular(24),
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
                        placeholderBuilder: (_) =>
                            const CircleAvatar(radius: 16),
                      ),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : const AssetImage('assets/images/user_avatar.png')
                              as ImageProvider,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.settings, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
