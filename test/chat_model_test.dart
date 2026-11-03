import 'package:flutter_test/flutter_test.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';

void main() {
  group('ChatMessageModel & MessageAttachment Tests', () {
    test('Parses ChatMessageModel from Odoo JSON with HTML body', () {
      final json = {
        'id': 101,
        'body': '<p>Hello <b>World</b>!</p>',
        'date': '2026-03-02T10:00:00',
        'channel_id': 16,
        'author': {'id': 3, 'name': 'Mitchell Admin'},
        'is_me': true,
        'attachments': [
          {
            'id': 45,
            'filename': 'photo.jpg',
            'mimetype': 'image/jpeg',
            'data': 'aGVsbG8=',
            'file_size': 1024,
          }
        ],
        'reactions': {'❤️': 2, '👍': 1},
        'delivery_status': 'read',
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.id, 101);
      expect(msg.cleanBody, 'Hello World!');
      expect(msg.author.name, 'Mitchell Admin');
      expect(msg.isMe, isTrue);
      expect(msg.attachments.length, 1);
      expect(msg.attachments.first.isImage, isTrue);
      expect(msg.attachments.first.isVideo, isFalse);
      expect(msg.attachments.first.formattedSize, '1.0 KB');
      expect(msg.reactions['❤️'], 2);
      expect(msg.deliveryStatus, 'read');
    });

    test('Identifies voice note and document MIME types properly', () {
      final voice = MessageAttachment(
        filename: 'note.m4a',
        mimetype: 'audio/m4a',
      );
      expect(voice.isAudio, isTrue);
      expect(voice.isImage, isFalse);

      final pdf = MessageAttachment(
        filename: 'invoice.pdf',
        mimetype: 'application/pdf',
        fileSize: 2048576,
      );
      expect(pdf.isPdf, isTrue);
      expect(pdf.isDocument, isTrue);
      expect(pdf.formattedSize, '2.0 MB');
    });

    test('Message copyWith updates reactions and reply headers', () {
      final original = ChatMessageModel(
        id: 1,
        body: 'Original',
        date: '2026-03-02T10:00:00',
        author: MessageAuthor(id: 1, name: 'Alice'),
      );

      final updated = original.copyWith(
        replyToText: 'Quoted text',
        replyToAuthor: 'Bob',
        reactions: {'🔥': 1},
      );

      expect(updated.replyToText, 'Quoted text');
      expect(updated.replyToAuthor, 'Bob');
      expect(updated.reactions['🔥'], 1);
      expect(updated.body, 'Original');
    });
  });
}

