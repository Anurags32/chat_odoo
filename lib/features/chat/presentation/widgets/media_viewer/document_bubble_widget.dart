import 'package:flutter/material.dart';
import 'package:nspl_odoo/core/theme/app_colors.dart';
import 'package:nspl_odoo/features/chat/data/services/attachment_service.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';

class DocumentBubbleWidget extends StatefulWidget {
  final MessageAttachment attachment;
  final bool isMe;

  const DocumentBubbleWidget({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  State<DocumentBubbleWidget> createState() => _DocumentBubbleWidgetState();
}

class _DocumentBubbleWidgetState extends State<DocumentBubbleWidget> {
  bool _isLoading = false;

  IconData _getFileIcon() {
    final ext = widget.attachment.filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getIconColor() {
    final ext = widget.attachment.filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.green;
      case 'zip':
      case 'rar':
        return Colors.orangeAccent;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _openFile() async {
    setState(() => _isLoading = true);
    try {
      final success = await AttachmentService.instance.openAttachment(
        widget.attachment,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open document'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: _isLoading ? null : _openFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.15)
              : (isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.lightSurfaceElevated),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.2)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getIconColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(_getFileIcon(), color: _getIconColor(), size: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.attachment.filename,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe
                          ? Colors.white
                          : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.attachment.formattedSize.isNotEmpty
                        ? widget.attachment.formattedSize
                        : 'Tap to view',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe
                          ? Colors.white70
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: widget.isMe ? Colors.white70 : AppColors.grey,
              ),
          ],
        ),
      ),
    );
  }
}
