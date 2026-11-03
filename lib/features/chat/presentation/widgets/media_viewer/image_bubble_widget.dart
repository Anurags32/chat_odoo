import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nspl_odoo/core/theme/app_colors.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';
import 'full_screen_image_viewer.dart';

class ImageBubbleWidget extends StatelessWidget {
  final MessageAttachment attachment;
  final bool isMe;

  const ImageBubbleWidget({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (attachment.data != null && attachment.data!.isNotEmpty) {
      try {
        final clean = attachment.data!.contains(',')
            ? attachment.data!.split(',').last
            : attachment.data!;
        imageProvider = MemoryImage(base64Decode(clean));
      } catch (_) {}
    } else if (attachment.url != null && attachment.url!.isNotEmpty) {
      imageProvider = NetworkImage(attachment.url!);
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(attachment: attachment),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 240,
            maxHeight: 240,
            minWidth: 140,
            minHeight: 140,
          ),
          color: Colors.black12,
          child: imageProvider != null
              ? Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: AppColors.grey),
                        SizedBox(height: 6),
                        Text(
                          'Unavailable Image',
                          style: TextStyle(fontSize: 12, color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
