import 'package:flutter/material.dart';
import '../../features/auth/domain/models/api_user_model.dart';
import 'base64_avatar.dart';

class UserAvatarWidget extends StatelessWidget {
  final ApiUserModel user;
  final double radius;
  final bool showOnlineIndicator;

  const UserAvatarWidget({
    super.key,
    required this.user,
    this.radius = 20,
    this.showOnlineIndicator = true,
  });

  Color _getStatusColor() {
    switch (user.imStatus) {
      case 'online':
        return Colors.green;
      case 'away':
        return Colors.orange;
      case 'offline':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Base64Avatar(
          base64String: user.avatar,
          radius: radius,
          fallbackText: user.name,
          backgroundColor: Colors.blue,
        ),
        if (showOnlineIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
