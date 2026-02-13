import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/message_model.dart';

class ChatNotifier extends StateNotifier<List<MessageModel>> {
  ChatNotifier() : super([]);

  void addMessage(MessageModel message) {
    state = [...state, message];
  }

  void loadMessages(String userId) {
    // Simulate loading messages for a specific user
    state = _getDummyMessages(userId);
  }

  List<MessageModel> _getDummyMessages(String userId) {
    return [
      MessageModel(
        id: '1',
        senderId: userId,
        receiverId: 'currentUser',
        message: 'Hello! How are you?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
      ),
      MessageModel(
        id: '2',
        senderId: 'currentUser',
        receiverId: userId,
        message: 'I am good, thanks! How about you?',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 55),
        ),
        isRead: true,
      ),
      MessageModel(
        id: '3',
        senderId: userId,
        receiverId: 'currentUser',
        message: 'Doing great! Working on a new project.',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 50),
        ),
        isRead: true,
      ),
    ];
  }

  void clearMessages() {
    state = [];
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<MessageModel>>(
  (ref) => ChatNotifier(),
);
