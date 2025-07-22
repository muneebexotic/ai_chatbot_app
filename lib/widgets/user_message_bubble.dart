import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class UserMessageBubble extends StatelessWidget {
  final String message;
  final VoidCallback onEdit;

  const UserMessageBubble({
    super.key,
    required this.message,
    required this.onEdit,
  });

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null &&
        (avatarUrl.contains('dicebear.com') || avatarUrl.contains('/svg'))) {
      // It's a DiceBear-style SVG URL
      return ClipOval(
        child: SvgPicture.network(
          avatarUrl,
          width: 32,
          height: 32,
          placeholderBuilder: (context) => const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
          ),
          fit: BoxFit.cover,
        ),
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Cloudinary or normal image
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
      );
    } else {
      // Default asset fallback
      return const CircleAvatar(
        radius: 16,
        backgroundImage: AssetImage('assets/images/user_avatar.png'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = Provider.of<AuthProvider>(context).userPhotoUrl;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141718),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(avatarUrl),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
