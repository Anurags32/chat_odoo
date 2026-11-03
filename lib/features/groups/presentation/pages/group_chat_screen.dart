import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../chat/domain/models/channel_model.dart';
import '../../../chat/presentation/widgets/chat_input.dart';
import '../../../chat/presentation/widgets/message_bubble.dart';
import '../../data/providers/group_api_provider.dart';
import '../../domain/models/group_model.dart';
import 'view_members_screen.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';
  bool _showScrollToBottom = false;
  ChatMessageModel? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    Future.microtask(() {
      ref.read(groupMessagesProvider.notifier).loadMessages(widget.group.channelId);
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
    final shouldShow = _scrollController.offset > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final reply = _replyingToMessage;
    setState(() => _replyingToMessage = null);

    final success = await ref.read(groupMessagesProvider.notifier).sendMessage(
          channelId: widget.group.channelId,
          body: text,
        );

    if (success) {
      _scrollToBottom();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send group message'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _sendAttachment(MessageAttachment attachment, {String? caption}) async {
    setState(() => _replyingToMessage = null);

    final success = await ref.read(groupMessagesProvider.notifier).sendMessage(
          channelId: widget.group.channelId,
          body: caption ?? '',
          attachments: [attachment],
        );

    if (success) {
      _scrollToBottom();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send attachment'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
    final messagesState = ref.watch(groupMessagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chatMessages = messagesState.messages.map((m) => m.toChatMessageModel()).toList();

    final filteredMessages = _searchQuery.isEmpty
        ? chatMessages
        : chatMessages
            .where((m) =>
                m.cleanBody.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Reverse for reverse: true (index 0 is newest at bottom)
    final reversedMessages = filteredMessages.reversed.toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: _buildAppBar(isDark),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: messagesState.isLoading && chatMessages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : filteredMessages.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.group_outlined,
                            title: _searchQuery.isNotEmpty
                                ? 'No Messages Found'
                                : 'No Group Messages Yet',
                            subtitle: _searchQuery.isNotEmpty
                                ? 'No messages match "$_searchQuery"'
                                : 'Send the first message to ${widget.group.name}!',
                          )
                        : _buildReverseMessagesList(reversedMessages, isDark),
              ),
              ChatInput(
                controller: _messageController,
                enabled: !messagesState.isSending,
                replyingToMessage: _replyingToMessage,
                onCancelReply: () => setState(() => _replyingToMessage = null),
                onSend: _sendMessage,
                onSendAttachment: _sendAttachment,
              ),
            ],
          ),

          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.small(
                heroTag: 'group_scroll_to_bottom_fab',
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                elevation: 4,
                onPressed: _scrollToBottom,
                child: const Icon(
                  Icons.keyboard_double_arrow_down_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
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
            hintText: 'Search in group...',
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
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ViewMembersScreen(group: widget.group),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.buttonGradient,
              ),
              child: Center(
                child: Text(
                  widget.group.avatar ?? '👥',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
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
                    '${widget.group.memberCount} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 22),
          tooltip: 'Search group messages',
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          icon: const Icon(Icons.group_outlined, size: 22),
          tooltip: 'Group Info',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ViewMembersScreen(group: widget.group),
              ),
            );
          },
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
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDateSeparator(msgDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            MessageBubble(
              message: message,
              isMe: message.isMe ?? false,
              showSenderName: true,
              onReply: () => setState(() => _replyingToMessage = message),
            ),
          ],
        );
      },
    );
  }
}
