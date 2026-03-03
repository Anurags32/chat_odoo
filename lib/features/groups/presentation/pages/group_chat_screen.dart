import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/group_model.dart';
import '../../data/providers/group_api_provider.dart';
import '../widgets/group_message_bubble.dart';
import '../../../chat/presentation/widgets/chat_input.dart';
import 'view_members_screen.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
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

    Future.microtask(() {
      ref.read(groupMessagesProvider.notifier).loadMessages(widget.group.channelId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final success = await ref.read(groupMessagesProvider.notifier).sendMessage(
      channelId: widget.group.channelId,
      body: messageText,
    );

    if (success) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(groupMessagesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: 100), // Space for transparent AppBar
            Expanded(child: _buildMessagesList(messagesState)),
            ChatInput(
              controller: _messageController,
              onSend: _sendMessage,
              enabled: !messagesState.isSending,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
            child: Center(
              child: Text(
                widget.group.avatar ?? '👥',
                style: const TextStyle(fontSize: 20),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${widget.group.memberCount} members',
                  style: const TextStyle(fontSize: 12, color: AppColors.purple1),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'info':
                _showGroupInfo();
                break;
              case 'members':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ViewMembersScreen(group: widget.group),
                  ),
                );
                break;
              case 'leave':
                _leaveGroup();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.purple1),
                  SizedBox(width: 12),
                  Text('Group Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'members',
              child: Row(
                children: [
                  Icon(Icons.people_outline, color: AppColors.purple1),
                  SizedBox(width: 12),
                  Text('View Members'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'leave',
              child: Row(
                children: [
                  Icon(Icons.exit_to_app, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('Leave Group'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesList(GroupMessagesState messagesState) {
    if (messagesState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple1),
        ),
      );
    }

    if (messagesState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              messagesState.error!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(groupMessagesProvider.notifier).loadMessages(widget.group.channelId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (messagesState.messages.isEmpty) {
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
            const Text(
              'Start the conversation!',
              style: TextStyle(fontSize: 14, color: AppColors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messagesState.messages.length,
      itemBuilder: (context, index) {
        final message = messagesState.messages[index];

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
          ),
          child: GroupMessageBubble(message: message),
        );
      },
    );
  }

  void _showGroupInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(widget.group.avatar ?? '👥', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.group.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.group.description != null)
              Text(
                widget.group.description!,
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 16),
            Text(
              'Created: ${_formatDate(DateTime.now())}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Members: ${widget.group.memberCount}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: Text('Are you sure you want to leave "${widget.group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  Navigator.of(context).pop(); // Close dialog
                  
                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple1),
                      ),
                    ),
                  );

                  // Call leave group API
                  final success = await ref.read(groupApiProvider.notifier).leaveGroup(widget.group.channelId);

                  if (mounted) {
                    Navigator.of(context).pop(); // Close loading
                    Navigator.of(context).pop(); // Close chat screen

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'You left the group' : 'Failed to leave group'),
                        backgroundColor: success ? AppColors.purple1 : AppColors.error,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'Leave',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
