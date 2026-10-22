import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/websocket_service.dart';
import '../../domain/models/channel_model.dart';
import '../../../call/data/providers/call_provider.dart';
import 'chat_api_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────

class WebSocketState {
  final WsStatus status;
  final List<ChatMessageModel> liveMessages; // messages received via WS
  final String? error;

  const WebSocketState({
    this.status = WsStatus.disconnected,
    this.liveMessages = const [],
    this.error,
  });

  WebSocketState copyWith({
    WsStatus? status,
    List<ChatMessageModel>? liveMessages,
    String? error,
  }) {
    return WebSocketState(
      status: status ?? this.status,
      liveMessages: liveMessages ?? this.liveMessages,
      error: error,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class WebSocketNotifier extends StateNotifier<WebSocketState> {
  final Ref? _ref;
  final WebSocketService _ws = WebSocketService();
  Timer? _typingTimer;

  WebSocketNotifier([this._ref]) : super(const WebSocketState()) {
    _ws.onStatusChange = (s) {
      if (mounted) state = state.copyWith(status: s);
    };
    _ws.onError = (e) {
      if (mounted) state = state.copyWith(error: e);
    };
    _ws.onMessage = _handleMessages;
  }

  /// Connect to a channel by its numeric ID
  Future<void> connect({required int channelId, int lastMessageId = 0}) async {
    // Reset live messages for new chat
    state = const WebSocketState();
    await _ws.connect(channelId: channelId, lastMessageId: lastMessageId);
  }

  Future<void> disconnect() async {
    _typingTimer?.cancel();
    await _ws.disconnect();
    state = const WebSocketState();
  }

  void clearError() => state = state.copyWith(error: null);

  // ── Private ──────────────────────────────────────────────────────────────

  void _handleMessages(List<dynamic> events) {
    for (final event in events) {
      try {
        final map = event as Map<String, dynamic>;
        final message = map['message'] as Map<String, dynamic>?;
        if (message == null) continue;

        final type = message['type'] as String?;
        debugPrint('[WS] Event type: $type');

        if (type == 'webrtc_call') {
          final payload = message['payload'] as Map<String, dynamic>?;
          final ref = _ref;
          if (payload != null && ref != null) {
            final eventName = payload['event'] as String? ?? '';
            ref.read(callManagerProvider.notifier).handleBusEvent(eventName, payload);
          }
        } else if (type == 'discuss.channel/new_message') {
          // Real-time new message
          _processNewMessage(message['payload'] as Map<String, dynamic>?);
        } else if (type == 'mail.message/insert' || type == 'mail.record/insert') {
          // Fallback message event
          _processInsertEvent(message['payload'] as Map<String, dynamic>?);
        } else if (type != null && type.contains('typing')) {
          // Typing indicator event
          _processTypingEvent(message['payload'] as Map<String, dynamic>?);
        }
      } catch (e) {
        debugPrint('[WS] Error processing event: $e | event: $event');
      }
    }
  }

  void _processTypingEvent(Map<String, dynamic>? payload) {
    if (_ref == null) return;
    _ref.read(chatApiProvider.notifier).setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _ref.read(chatApiProvider.notifier).setTyping(false);
      }
    });
  }

  /// Handles: discuss.channel/new_message
  void _processNewMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final mailMessages = data['mail.message'] as List<dynamic>?;
    if (mailMessages == null || mailMessages.isEmpty) return;

    final newMsgs = <ChatMessageModel>[];
    for (final m in mailMessages) {
      try {
        final msg = _parseMailMessage(m as Map<String, dynamic>);
        if (msg != null) {
          newMsgs.add(msg);
          _ref?.read(chatApiProvider.notifier).addIncomingMessage(msg);
        }
      } catch (e) {
        debugPrint('[WS] Failed to parse new_message: $e');
      }
    }

    if (newMsgs.isNotEmpty && mounted) {
      state = state.copyWith(
        liveMessages: [...state.liveMessages, ...newMsgs],
      );
    }
  }

  void _processInsertEvent(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final mailMessages = payload['mail.message'] as List<dynamic>?;
    if (mailMessages != null) {
      final newMsgs = <ChatMessageModel>[];
      for (final m in mailMessages) {
        try {
          final msg = _parseMailMessage(m as Map<String, dynamic>);
          if (msg != null) {
            newMsgs.add(msg);
            _ref?.read(chatApiProvider.notifier).addIncomingMessage(msg);
          }
        } catch (e) {
          debugPrint('[WS] Failed to parse mail.message: $e');
        }
      }
      if (newMsgs.isNotEmpty && mounted) {
        state = state.copyWith(
          liveMessages: [...state.liveMessages, ...newMsgs],
        );
      }
    }
  }

  ChatMessageModel? _parseMailMessage(Map<String, dynamic> m) {
    final id = m['id'] as int?;
    final body = m['body'] as String? ?? '';
    final date = m['date'] as String? ?? DateTime.now().toIso8601String();

    final authorRaw = m['author'] as Map<String, dynamic>?;
    final authorId = authorRaw?['id'] as int? ?? 0;
    final authorName = authorRaw?['name'] as String? ?? 'User $authorId';

    if (id == null) return null;

    return ChatMessageModel(
      id: id,
      body: body,
      date: date,
      author: MessageAuthor(id: authorId, name: authorName),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _ws.disconnect();
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final webSocketProvider =
    StateNotifierProvider.autoDispose<WebSocketNotifier, WebSocketState>(
  (ref) => WebSocketNotifier(ref),
);
