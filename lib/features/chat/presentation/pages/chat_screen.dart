import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/message_model.dart';
import '../../data/providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const ChatScreen({super.key, required this.user});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
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

    // Load messages for this user
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadMessages(widget.user.id);
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
    if (_messageController.text.trim().isEmpty) return;

    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'currentUser',
      receiverId: widget.user.id,
      message: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );

    ref.read(chatProvider.notifier).addMessage(message);
    _messageController.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
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
    final messages = ref.watch(chatProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: 100), // Space for transparent AppBar
            Expanded(child: _buildMessagesList(messages)),
            ChatInput(controller: _messageController, onSend: _sendMessage),
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
                  border: widget.user.profilePicture != null
                      ? Border.all(
                          color: widget.user.isOnline
                              ? AppColors.purple1
                              : AppColors.grey,
                          width: 2,
                        )
                      : null,
                ),
                child: widget.user.profilePicture != null
                    ? ClipOval(
                        child: Image.network(
                          widget.user.profilePicture!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                widget.user.avatar,
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: Text(
                                widget.user.avatar,
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          widget.user.avatar,
                          style: const TextStyle(fontSize: 20),
                        ),
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
                Text(
                  widget.user.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.user.isOnline
                        ? AppColors.purple1
                        : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
      ],
    );
  }

  Widget _buildMessagesList(List<MessageModel> messages) {
    if (messages.isEmpty) {
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == 'currentUser';
        final showUserName = !isMe;

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (showUserName)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4, top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.user.isOnline
                              ? AppColors.buttonGradient
                              : const LinearGradient(
                                  colors: [AppColors.grey, AppColors.lightGrey],
                                ),
                          border: widget.user.profilePicture != null
                              ? Border.all(
                                  color: widget.user.isOnline
                                      ? AppColors.purple1
                                      : AppColors.grey,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: widget.user.profilePicture != null
                            ? ClipOval(
                                child: Image.network(
                                  widget.user.profilePicture!,
                                  width: 21,
                                  height: 21,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        widget.user.avatar,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: Text(
                                            widget.user.avatar,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              )
                            : Center(
                                child: Text(
                                  widget.user.avatar,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.user.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purple1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.user.isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple1,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              MessageBubble(message: message, isMe: isMe),
            ],
          ),
        );
      },
    );
  }
}
