import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/domain/models/api_user_model.dart';
import '../../data/providers/chat_api_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../../domain/models/channel_model.dart';

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
    );
    _animationController.forward();

    // Step 1: Create/get channel via REST, then connect WebSocket
    Future.microtask(() async {
      await ref
          .read(chatApiProvider.notifier)
          .createChannel(widget.user.partnerId);

      // Step 2: After channel is ready, connect WebSocket
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
    // WebSocket disconnects automatically via autoDispose
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatApiProvider.notifier).sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
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

    // Show REST errors
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

    // Show WS errors + auto-scroll on new message
    ref.listen<WebSocketState>(webSocketProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WS: ${next.error!}'),
            backgroundColor: Colors.orange,
          ),
        );
        ref.read(webSocketProvider.notifier).clearError();
      }

      // Auto-scroll when a new live message arrives
      final prevCount = previous?.liveMessages.length ?? 0;
      if (next.liveMessages.length > prevCount) {
        _scrollToBottom();
      }
    });

    // Merge REST messages + live WS messages (deduplicate by id)
    final allMessages = _mergeMessages(
      chatState.messages,
      wsState.liveMessages,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(wsState.status),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: 100),
            Expanded(
              child: chatState.isLoading
                  ? _buildLoadingState()
                  : allMessages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(allMessages),
            ),
            _buildChatInput(chatState.isSending),
          ],
        ),
      ),
    );
  }

  /// Merge REST history + live WS messages, deduplicate by id
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

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(WsStatus wsStatus) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          ref.read(chatApiProvider.notifier).clearChat();
          Navigator.of(context).pop();
        },
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.user.isOnline
                      ? AppColors.buttonGradient
                      : const LinearGradient(
                          colors: [AppColors.grey, AppColors.lightGrey],
                        ),
                ),
                child: UserAvatarWidget(
                  user: widget.user,
                  radius: 20,
                  showOnlineIndicator: false,
                ),
              ),
              if (widget.user.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    _wsStatusDot(wsStatus),
                    const SizedBox(width: 4),
                    Text(
                      _wsStatusLabel(wsStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: _wsStatusColor(wsStatus),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
      ],
    );
  }

  Widget _wsStatusDot(WsStatus status) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _wsStatusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _wsStatusColor(WsStatus status) {
    switch (status) {
      case WsStatus.connected:
        return AppColors.success;
      case WsStatus.connecting:
        return Colors.orange;
      case WsStatus.error:
        return AppColors.error;
      case WsStatus.disconnected:
        return AppColors.grey;
    }
  }

  String _wsStatusLabel(WsStatus status) {
    switch (status) {
      case WsStatus.connected:
        return 'Connected';
      case WsStatus.connecting:
        return 'Connecting...';
      case WsStatus.error:
        return 'Connection error';
      case WsStatus.disconnected:
        return widget.user.isOnline ? 'Online' : 'Offline';
    }
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.purple1),
          SizedBox(height: 16),
          Text(
            'Loading chat...',
            style: TextStyle(fontSize: 16, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.purple1.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: AppColors.purple1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with ${widget.user.name}!',
            style: const TextStyle(fontSize: 14, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Widget _buildMessagesList(List<ChatMessageModel> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe =
            message.isMe ?? (message.author.id != widget.user.partnerId);
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController, curve: Curves.easeIn),
          ),
          child: _buildMessageBubble(message, isMe),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    final cleanBody = message.body.replaceAll(RegExp(r'<[^>]*>'), '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.buttonGradient,
              ),
              child: UserAvatarWidget(
                user: widget.user,
                radius: 16,
                showOnlineIndicator: false,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe
                    ? AppColors.buttonGradient
                    : const LinearGradient(
                        colors: [AppColors.offWhite, AppColors.offWhite],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanBody,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? AppColors.white : AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe
                          ? AppColors.white.withValues(alpha: 0.7)
                          : AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  Widget _buildChatInput(bool isSending) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple1.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !isSending,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.buttonGradient,
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSending ? null : _sendMessage,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: AppColors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return DateFormat('HH:mm').format(date);
      if (diff.inDays == 1) {
        return 'Yesterday ${DateFormat('HH:mm').format(date)}';
      }
      return DateFormat('MMM dd, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
