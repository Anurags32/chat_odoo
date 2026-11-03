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
import '../widgets/message_bubble.dart';

class RealChatScreen extends ConsumerStatefulWidget {
  final ApiUserModel user;

  const RealChatScreen({super.key, required this.user});

  @override
  ConsumerState<RealChatScreen> createState() => _RealChatScreenState();
}

class _RealChatScreenState extends ConsumerState<RealChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';
  bool _showScrollToBottom = false;
  int _unreadCountScrolledUp = 0;
  ChatMessageModel? _replyingToMessage;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    // Initialize channel and WebSocket connection
    Future.microtask(() async {
      await ref.read(chatApiProvider.notifier).createChannel(
            widget.user.partnerId,
            channelId: widget.user.channelId,
          );

      final chatState = ref.read(chatApiProvider);
      if (chatState.channel != null) {
        final lastId = chatState.messages.isNotEmpty
            ? chatState.messages.last.id
            : 0;
        await ref
            .read(webSocketProvider.notifier)
            .connect(channelId: chatState.channel!.id, lastMessageId: lastId);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final shouldShow = offset > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
        if (!shouldShow) _unreadCountScrolledUp = 0;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _unreadCountScrolledUp = 0);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatApiProvider.notifier).sendMessage(
          text,
          replyToText: _replyingToMessage?.cleanBody,
          replyToAuthor: _replyingToMessage?.author.name,
          replyToId: _replyingToMessage?.id,
        );

    _messageController.clear();
    setState(() => _replyingToMessage = null);
    _scrollToBottom();
  }

  void _sendAttachment(MessageAttachment attachment, {String? caption}) {
    ref.read(chatApiProvider.notifier).sendMessage(
          caption ?? '',
          attachments: [attachment],
          replyToText: _replyingToMessage?.cleanBody,
          replyToAuthor: _replyingToMessage?.author.name,
          replyToId: _replyingToMessage?.id,
        );
    setState(() => _replyingToMessage = null);
    _scrollToBottom();
  }

  void _initiateCall(CallType type) {
    final chatState = ref.read(chatApiProvider);
    final channelId = chatState.channel?.id ?? widget.user.channelId;
    ref.read(callManagerProvider.notifier).startCall(
          channelId: channelId,
          calleePartnerId: widget.user.partnerId,
          calleeName: widget.user.name,
          callType: type,
        );
    if (type == CallType.video) {
      context.push(
        '/video-call',
        extra: {
          'callee_name': widget.user.name,
          'partner_id': widget.user.partnerId,
          'channel_id': channelId,
        },
      );
    } else {
      context.push(
        '/audio-call',
        extra: {
          'callee_name': widget.user.name,
          'partner_id': widget.user.partnerId,
          'channel_id': channelId,
        },
      );
    }
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

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatApiProvider);
    final wsState = ref.watch(webSocketProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<WebSocketState>(webSocketProvider, (previous, next) {
      final prevCount = previous?.liveMessages.length ?? 0;
      if (next.liveMessages.length > prevCount) {
        if (_scrollController.hasClients && _scrollController.offset < 150) {
          _scrollToBottom();
        } else {
          setState(() => _unreadCountScrolledUp++);
        }
      }
    });

    final allMessages = _mergeMessages(chatState.messages, wsState.liveMessages);

    final filteredMessages = _searchQuery.isEmpty
        ? allMessages
        : allMessages
            .where((m) =>
                m.cleanBody.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Invert list for reverse: true (index 0 is newest, rendered at bottom)
    final reversedMessages = filteredMessages.reversed.toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: _buildAppBar(wsState.status, isDark),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: chatState.isLoading && allMessages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : filteredMessages.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: _searchQuery.isNotEmpty
                                ? 'No Messages Found'
                                : 'No Messages Yet',
                            subtitle: _searchQuery.isNotEmpty
                                ? 'No messages match "$_searchQuery"'
                                : 'Say hello to ${widget.user.name} and start your conversation!',
                          )
                        : _buildReverseMessagesList(reversedMessages, isDark),
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
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              ChatInput(
                controller: _messageController,
                enabled: !chatState.isSending,
                replyingToMessage: _replyingToMessage,
                onCancelReply: () => setState(() => _replyingToMessage = null),
                onSend: _sendMessage,
                onSendAttachment: _sendAttachment,
              ),
            ],
          ),

          // Floating Scroll-To-Bottom button with Unread Badge
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.small(
                heroTag: 'scroll_to_bottom_fab',
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                elevation: 4,
                onPressed: _scrollToBottom,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.keyboard_double_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    if (_unreadCountScrolledUp > 0)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_unreadCountScrolledUp',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  PreferredSizeWidget _buildAppBar(WsStatus wsStatus, bool isDark) {
    if (_isSearching) {
      return AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontSize: 16,
          ),
          decoration: const InputDecoration(
            hintText: 'Search in conversation...',
            border: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      );
    }

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
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.user.isOnline ? 'online' : 'last seen recently',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.user.isOnline
                        ? AppColors.online
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 22),
          tooltip: 'Search messages',
          onPressed: () => setState(() => _isSearching = true),
        ),
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

  Widget _buildReverseMessagesList(
    List<ChatMessageModel> reversedMessages,
    bool isDark,
  ) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final message = reversedMessages[index];
        final isMe = message.isMe ?? (message.author.id != widget.user.partnerId);

        // Check if date header should be shown (since reversed, check next index which is chronologically older)
        DateTime? msgDate;
        try {
          msgDate = DateTime.parse(message.date);
        } catch (_) {}

        bool showDateHeader = false;
        if (msgDate != null) {
          if (index == reversedMessages.length - 1) {
            showDateHeader = true;
          } else {
            try {
              final olderMsgDate =
                  DateTime.parse(reversedMessages[index + 1].date);
              if (!_isSameDay(msgDate, olderMsgDate)) {
                showDateHeader = true;
              }
            } catch (_) {}
          }
        }

        return Column(
          children: [
            if (showDateHeader && msgDate != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDateSeparator(msgDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            MessageBubble(
              message: message,
              isMe: isMe,
              onReply: () => setState(() => _replyingToMessage = message),
              onDelete: () =>
                  ref.read(chatApiProvider.notifier).deleteMessage(message.id),
              onReact: (emoji) => ref
                  .read(chatApiProvider.notifier)
                  .addReaction(message.id, emoji),
            ),
          ],
        );
      },
    );
  }
}
