import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/base64_avatar.dart';
import '../../domain/models/channel_model.dart';
import 'media_viewer/document_bubble_widget.dart';
import 'media_viewer/image_bubble_widget.dart';
import 'media_viewer/video_bubble_widget.dart';
import 'media_viewer/voice_note_bubble_widget.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool showSenderName;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final Function(String emoji)? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.onReply,
    this.onDelete,
    this.onReact,
  });

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reactions Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥'].map((
                    emoji,
                  ) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onReact?.call(emoji);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),

              // Action List
              ListTile(
                leading: const Icon(
                  Icons.reply_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply?.call();
                },
              ),
              if (message.cleanBody.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.cleanBody));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.forward_rounded),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forward selected')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Delete Message',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    switch (message.deliveryStatus) {
      case 'sending':
        return const Icon(
          Icons.access_time_rounded,
          size: 13,
          color: Colors.white70,
        );
      case 'sent':
        return const Icon(Icons.check_rounded, size: 14, color: Colors.white70);
      case 'delivered':
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.white70,
        );
      case 'read':
      default:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.lightBlueAccent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanBody = message.cleanBody;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left Sender Avatar for Group Messages
            if (!isMe && showSenderName) ...[
              Base64Avatar(
                base64String: message.author.avatar,
                fallbackText: message.author.name,
                radius: 14,
              ),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppColors.buttonGradient : null,
                      color: isMe
                          ? null
                          : (isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.lightSurfaceElevated),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: isMe
                          ? null
                          : Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Group Sender Name
                        if (!isMe && showSenderName) ...[
                          Text(
                            message.author.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Reply Quote Box
                        if (message.replyToText != null &&
                            message.replyToText!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black.withValues(alpha: 0.15)
                                  : (isDark
                                        ? Colors.black26
                                        : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.replyToAuthor != null)
                                  Text(
                                    message.replyToAuthor!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isMe
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                  ),
                                Text(
                                  message.replyToText!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white70
                                        : AppColors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Attachments Renderer
                        if (message.attachments.isNotEmpty) ...[
                          ...message.attachments.map((att) {
                            if (att.isImage) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ImageBubbleWidget(
                                  attachment: att,
                                  isMe: isMe,
                                ),
                              );
                            } else if (att.isVideo) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: VideoBubbleWidget(
                                  attachment: att,
                                  isMe: isMe,
                                ),
                              );
                            } else if (att.isAudio) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: VoiceNoteBubbleWidget(
                                  attachment: att,
                                  isMe: isMe,
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: DocumentBubbleWidget(
                                  attachment: att,
                                  isMe: isMe,
                                ),
                              );
                            }
                          }),
                        ],

                        // Text Body
                        if (cleanBody.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              cleanBody,
                              style: TextStyle(
                                fontSize: 15,
                                color: isMe
                                    ? Colors.white
                                    : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                                height: 1.35,
                              ),
                            ),
                          ),

                        const SizedBox(height: 4),

                        // Timestamp & Read Receipt ticks
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildStatusIcon(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Emoji Reactions floating badge
                  if (message.reactions.isNotEmpty)
                    Positioned(
                      bottom: -10,
                      right: isMe ? null : 8,
                      left: isMe ? 8 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: message.reactions.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Text(
                                '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('h:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
