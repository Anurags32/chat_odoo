import 'package:flutter_test/flutter_test.dart';
import 'package:nspl_odoo/features/chat/data/providers/chat_api_provider.dart';
import 'package:nspl_odoo/features/chat/data/services/chat_api_service.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';

void main() {
  group('ChatNotifier Unit Tests', () {
    test('addIncomingMessage avoids duplicates', () {
      final notifier = ChatNotifier(ChatApiService());

      final msg1 = ChatMessageModel(
        id: 1,
        body: 'Message 1',
        date: '2026-03-02T10:00:00',
        author: MessageAuthor(id: 2, name: 'Bob'),
      );

      final msg2 = ChatMessageModel(
        id: 2,
        body: 'Message 2',
        date: '2026-03-02T10:01:00',
        author: MessageAuthor(id: 2, name: 'Bob'),
      );

      notifier.addIncomingMessage(msg1);
      expect(notifier.state.messages.length, 1);

      // Attempt to add duplicate
      notifier.addIncomingMessage(msg1);
      expect(notifier.state.messages.length, 1);

      // Add distinct message
      notifier.addIncomingMessage(msg2);
      expect(notifier.state.messages.length, 2);
    });

    test('addReaction increments reaction count on target message', () {
      final notifier = ChatNotifier(ChatApiService());

      final msg = ChatMessageModel(
        id: 50,
        body: 'Great job!',
        date: '2026-03-02T10:00:00',
        author: MessageAuthor(id: 1, name: 'Alice'),
      );

      notifier.addIncomingMessage(msg);
      notifier.addReaction(50, '❤️');
      notifier.addReaction(50, '❤️');
      notifier.addReaction(50, '👍');

      final updatedMsg = notifier.state.messages.firstWhere((m) => m.id == 50);
      expect(updatedMsg.reactions['❤️'], 2);
      expect(updatedMsg.reactions['👍'], 1);
    });

    test('deleteMessage removes message from active state', () {
      final notifier = ChatNotifier(ChatApiService());

      final msg1 = ChatMessageModel(
        id: 10,
        body: 'To be deleted',
        date: '2026-03-02T10:00:00',
        author: MessageAuthor(id: 1, name: 'Alice'),
      );

      final msg2 = ChatMessageModel(
        id: 11,
        body: 'Keep me',
        date: '2026-03-02T10:01:00',
        author: MessageAuthor(id: 1, name: 'Alice'),
      );

      notifier.addIncomingMessage(msg1);
      notifier.addIncomingMessage(msg2);
      expect(notifier.state.messages.length, 2);

      notifier.deleteMessage(10);
      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.id, 11);
    });
  });
}

