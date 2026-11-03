import 'package:flutter/material.dart';
import 'package:nspl_odoo/core/theme/app_colors.dart';
import 'package:nspl_odoo/features/chat/data/services/attachment_service.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';

class VideoBubbleWidget extends StatelessWidget {
  final MessageAttachment attachment;
  final bool isMe;

  const VideoBubbleWidget({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final success = await AttachmentService.instance.openAttachment(
          attachment,
        );
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not play video'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center Play Button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            // Bottom Information Overlay
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      attachment.filename,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (attachment.formattedSize.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      attachment.formattedSize,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
