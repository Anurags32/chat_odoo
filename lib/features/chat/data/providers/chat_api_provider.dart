import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_api_service.dart';
import '../../domain/models/channel_model.dart';

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService();
});

// Chat state
class ChatState {
  final bool isLoading;
  final bool isSending;
  final ChannelModel? channel;
  final List<ChatMessageModel> messages;
  final String? error;

  ChatState({
    this.isLoading = false,
    this.isSending = false,
    this.channel,
    this.messages = const [],
    this.error,
  });

  ChatState copyWith({
    bool? isLoading,
    bool? isSending,
    ChannelModel? channel,
    List<ChatMessageModel>? messages,
    String? error,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
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
    state = state.copyWith(isLoading: true, error: null);

    final response = await _chatApiService.createChannel(partnerId: partnerId);

    if (response.success && response.data != null) {
      state = state.copyWith(
        isLoading: false,
        channel: response.data!.channel,
        messages: response.data!.channel.messages,
        error: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.message ?? 'Failed to create channel',
      );
    }
  }

  Future<void> sendMessage(String body, {List<MessageAttachment>? attachments}) async {
    if (state.channel == null) {
      state = state.copyWith(error: 'No channel selected');
      return;
    }

    state = state.copyWith(isSending: true, error: null);

    final response = await _chatApiService.sendMessage(
      channelId: state.channel!.id,
      body: body,
      attachments: attachments,
    );

    if (response.success && response.data != null) {
      // If message object is returned, add it to the list
      if (response.data!.message != null) {
        final updatedMessages = [...state.messages, response.data!.message!];
        state = state.copyWith(
          isSending: false,
          messages: updatedMessages,
          error: null,
        );
      } else {
        // Just mark as sent successfully
        state = state.copyWith(
          isSending: false,
          error: null,
        );
      }
    } else {
      state = state.copyWith(
        isSending: false,
        error: response.message ?? 'Failed to send message',
      );
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
