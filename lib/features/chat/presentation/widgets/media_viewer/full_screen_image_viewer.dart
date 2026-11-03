import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nspl_odoo/core/theme/app_colors.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class FullScreenImageViewer extends StatelessWidget {
  final MessageAttachment attachment;

  const FullScreenImageViewer({super.key, required this.attachment});

  Future<void> _saveImage(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${attachment.filename}');
      if (attachment.data != null && attachment.data!.isNotEmpty) {
        final clean = attachment.data!.contains(',')
            ? attachment.data!.split(',').last
            : attachment.data!;
        await file.writeAsBytes(base64Decode(clean));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to ${file.path}'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFilex.open(file.path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          attachment.filename,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Save image',
            onPressed: () => _saveImage(context),
          ),
        ],
      ),
      body: Center(
        child: imageProvider != null
            ? InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
      ),
    );
  }
}
