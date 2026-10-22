import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/storage_service.dart';
import '../services/chat_api_service.dart';
import '../../domain/models/channel_model.dart';

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService();
});

// Chat state
class ChatState {
  final bool isLoading;
  final bool isSending;
  final bool isPartnerTyping;
  final ChannelModel? channel;
  final List<ChatMessageModel> messages;
  final String? error;

  ChatState({
    this.isLoading = false,
    this.isSending = false,
    this.isPartnerTyping = false,
    this.channel,
    this.messages = const [],
    this.error,
  });

  ChatState copyWith({
    bool? isLoading,
    bool? isSending,
    bool? isPartnerTyping,
    ChannelModel? channel,
    List<ChatMessageModel>? messages,
    String? error,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isPartnerTyping: isPartnerTyping ?? this.isPartnerTyping,
      channel: channel ?? this.channel,
      messages: messages ?? this.messages,
      error: error,
    );
  }
}

// Chat provider
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatApiService _chatApiService;

  ChatNotifier(this._chatApiService) : super(ChatState());

  Future<void> createChannel(int partnerId) async {
    // 1. Try loading cached messages first for offline instant access
    final cached = await StorageService.instance.getCachedMessages(partnerId);
    if (cached != null && cached.isNotEmpty) {
      final cachedMsgs = cached
          .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
          .toList();
      state = state.copyWith(messages: cachedMsgs);
    }

    state = state.copyWith(isLoading: state.messages.isEmpty, error: null);

    final response = await _chatApiService.createChannel(partnerId: partnerId);

    if (response.success && response.data != null) {
      final channel = response.data!.channel;
      state = state.copyWith(
        isLoading: false,
        channel: channel,
        messages: channel.messages,
        error: null,
      );

      // Cache channel messages
      await StorageService.instance.cacheMessages(
        partnerId,
        channel.messages.map((m) => m.toJson()).toList(),
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: state.messages.isNotEmpty
            ? null // If cached messages exist, don't show blocking error
            : (response.message ?? 'Failed to connect to chat'),
      );
    }
  }

  void addIncomingMessage(ChatMessageModel msg) {
    // Prevent duplicate messages
    if (state.messages.any((m) => m.id == msg.id)) return;

    final updated = [...state.messages, msg];
    state = state.copyWith(messages: updated);

    if (state.channel != null) {
      StorageService.instance.cacheMessages(
        state.channel!.partnerId,
        updated.map((m) => m.toJson()).toList(),
      );
    }
  }

  void setTyping(bool typing) {
    state = state.copyWith(isPartnerTyping: typing);
  }

  Future<bool> sendMessage(String body, {List<MessageAttachment>? attachments}) async {
    if (state.channel == null) {
      state = state.copyWith(error: 'No active channel');
      return false;
    }

    state = state.copyWith(isSending: true, error: null);

    final response = await _chatApiService.sendMessage(
      channelId: state.channel!.id,
      body: body,
      attachments: attachments,
    );

    if (response.success && response.data != null) {
      List<ChatMessageModel> updatedMessages = [...state.messages];
      if (response.data!.message != null) {
        updatedMessages.add(response.data!.message!);
      } else {
        // Optimistic message append if API didn't return full model
        updatedMessages.add(
          ChatMessageModel(
            id: response.data!.messageId,
            body: body,
            date: DateTime.now().toIso8601String(),
            channelId: state.channel!.id,
            author: MessageAuthor(id: 0, name: 'You'),
            isMe: true,
          ),
        );
      }

      state = state.copyWith(
        isSending: false,
        messages: updatedMessages,
        error: null,
      );

      await StorageService.instance.cacheMessages(
        state.channel!.partnerId,
        updatedMessages.map((m) => m.toJson()).toList(),
      );
      return true;
    } else {
      state = state.copyWith(
        isSending: false,
        error: response.message ?? 'Failed to send message',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearChat() {
    state = ChatState();
  }
}

final chatApiProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final chatApiService = ref.watch(chatApiServiceProvider);
  return ChatNotifier(chatApiService);
});
