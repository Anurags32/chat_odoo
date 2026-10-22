import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/domain/models/api_user_model.dart';
import '../../../call/data/models/call_model.dart';
import '../../../call/data/providers/call_provider.dart';
import '../../data/providers/chat_api_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../../domain/models/channel_model.dart';
import '../widgets/chat_input.dart';

class RealChatScreen extends ConsumerStatefulWidget {
  final ApiUserModel user;

  const RealChatScreen({super.key, required this.user});

  @override
  ConsumerState<RealChatScreen> createState() => _RealChatScreenState();
}

class _RealChatScreenState extends ConsumerState<RealChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    // Initialize channel and WebSocket connection
    Future.microtask(() async {
      await ref
          .read(chatApiProvider.notifier)
          .createChannel(widget.user.partnerId);

      final chatState = ref.read(chatApiProvider);
      if (chatState.channel != null) {
        final lastId = chatState.messages.isNotEmpty
            ? chatState.messages.last.id
            : 0;
        await ref.read(webSocketProvider.notifier).connect(
              channelId: chatState.channel!.id,
              lastMessageId: lastId,
            );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatApiProvider.notifier).sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _sendAttachment(MessageAttachment attachment) {
    ref.read(chatApiProvider.notifier).sendMessage(
          '',
          attachments: [attachment],
        );
    _scrollToBottom();
  }

  void _initiateCall(CallType type) {
    ref.read(callManagerProvider.notifier).startCall(
          calleePartnerId: widget.user.partnerId,
          calleeName: widget.user.name,
          callType: type,
        );
    if (type == CallType.video) {
      context.push('/video-call', extra: {'callee_name': widget.user.name, 'partner_id': widget.user.partnerId});
    } else {
      context.push('/audio-call', extra: {'callee_name': widget.user.name, 'partner_id': widget.user.partnerId});
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatApiProvider);
    final wsState = ref.watch(webSocketProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show errors
    ref.listen<ChatState>(chatApiProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(chatApiProvider.notifier).clearError();
      }
    });

    ref.listen<WebSocketState>(webSocketProvider, (previous, next) {
      final prevCount = previous?.liveMessages.length ?? 0;
      if (next.liveMessages.length > prevCount) {
        _scrollToBottom();
      }
    });

    final allMessages = _mergeMessages(chatState.messages, wsState.liveMessages);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: _buildAppBar(wsState.status, isDark),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading && allMessages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : allMessages.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No Messages Yet',
                        subtitle:
                            'Say hello to ${widget.user.name} and start your conversation!',
                      )
                    : _buildMessagesList(allMessages, isDark),
          ),

          // Typing indicator banner
          if (chatState.isPartnerTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.user.name} is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

          ChatInput(
            controller: _messageController,
            enabled: !chatState.isSending,
            onSend: _sendMessage,
            onSendAttachment: _sendAttachment,
          ),
        ],
      ),
    );
  }

  List<ChatMessageModel> _mergeMessages(
    List<ChatMessageModel> history,
    List<ChatMessageModel> live,
  ) {
    final seen = <int>{};
    final merged = <ChatMessageModel>[];
    for (final m in [...history, ...live]) {
      if (seen.add(m.id)) merged.add(m);
    }
    return merged;
  }

  PreferredSizeWidget _buildAppBar(WsStatus wsStatus, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          ref.read(chatApiProvider.notifier).clearChat();
          context.pop();
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          UserAvatarWidget(
            user: widget.user,
            radius: 19,
            showOnlineIndicator: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.user.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.user.isOnline
                        ? AppColors.online
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_outlined, size: 22),
          color: AppColors.primary,
          tooltip: 'Audio Call',
          onPressed: () => _initiateCall(CallType.audio),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined, size: 24),
          color: AppColors.accentTeal,
          tooltip: 'Video Call',
          onPressed: () => _initiateCall(CallType.video),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessagesList(List<ChatMessageModel> messages, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.isMe ?? (message.author.id != widget.user.partnerId);
        return _buildMessageBubble(message, isMe, isDark);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe, bool isDark) {
    final cleanBody = message.body.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatarWidget(
              user: widget.user,
              radius: 14,
              showOnlineIndicator: false,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe ? AppColors.buttonGradient : null,
                color: isMe
                    ? null
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (cleanBody.isNotEmpty)
                    Text(
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
                  const SizedBox(height: 4),
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
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
