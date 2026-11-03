import 'package:flutter_test/flutter_test.dart';
import 'package:nspl_odoo/core/services/notification_service.dart';

void main() {
  group('NotificationService Configuration Tests', () {
    test('Channels and Action IDs are properly configured', () {
      expect(NotificationService.chatChannelId, 'chat_messages');
      expect(NotificationService.callChannelId, 'incoming_calls');
      expect(NotificationService.actionReply, 'reply_action');
      expect(NotificationService.actionMarkRead, 'mark_read_action');
    });
  });
}

