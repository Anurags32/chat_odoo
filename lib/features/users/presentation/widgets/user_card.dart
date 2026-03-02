import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/domain/models/user_model.dart';

class UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const UserCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: AppColors.buttonGradient,
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(child: _buildUserInfo()),
                _buildTrailingIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: user.isOnline
                ? AppColors.buttonGradient
                : const LinearGradient(
                    colors: [AppColors.grey, AppColors.lightGrey],
                  ),
            border: user.profilePicture != null
                ? Border.all(
                    color: user.isOnline ? AppColors.purple1 : AppColors.grey,
                    width: 2,
                  )
                : null,
          ),
          child: user.profilePicture != null
              ? ClipOval(
                  child: Image.network(
                    user.profilePicture!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to emoji avatar if image fails to load
                      return Center(
                        child: Text(
                          user.avatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Text(
                          user.avatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Text(
                    user.avatar,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
        ),
        if (user.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.isOnline ? user.status : 'Last seen ${user.lastSeen}',
          style: TextStyle(
            fontSize: 14,
            color: user.isOnline ? AppColors.purple1 : AppColors.grey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTrailingIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.purple1.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chat_bubble_outline,
        color: AppColors.purple1,
        size: 20,
      ),
    );
  }
}
