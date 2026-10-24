import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../storage/storage_service.dart';
import 'api_constants.dart';

/// WebSocket connection states
enum WsStatus { disconnected, connecting, connected, error }

/// Callback types
typedef OnMessageCallback = void Function(List<dynamic> messages);
typedef OnStatusCallback = void Function(WsStatus status);
typedef OnErrorCallback = void Function(String error);

class WebSocketService {
  String get _wsBaseUrl => ApiConstants.wsUrl;

  WebSocketChannel? _channel;
  WebSocket? _ioSocket;
  StreamSubscription? _subscription;
  Timer? _keepAlive;

  WsStatus _status = WsStatus.disconnected;
  WsStatus get status => _status;

  OnMessageCallback? onMessage;
  OnStatusCallback? onStatusChange;
  OnErrorCallback? onError;

  // Reconnect support
  int _channelId = 0;
  int _lastMessageId = 0;
  bool _shouldReconnect = false;
  Timer? _reconnectTimer;

  /// Connect and subscribe to a channel
  Future<void> connect({
    required int channelId,
    int lastMessageId = 0,
  }) async {
    _channelId = channelId;
    _lastMessageId = lastMessageId;
    _shouldReconnect = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_status == WsStatus.connecting || _status == WsStatus.connected) {
      debugPrint('[WS] Already connecting/connected, skipping.');
      return;
    }

    _setStatus(WsStatus.connecting);
    debugPrint('[WS] Connecting to $_wsBaseUrl ...');

    try {
      final sessionCookie = await StorageService.instance.getSessionCookie();
      final token = await StorageService.instance.getToken();
      final cookieToUse = (sessionCookie != null && sessionCookie.isNotEmpty)
          ? sessionCookie
          : token;

      final headers = <String, dynamic>{};
      if (cookieToUse != null && cookieToUse.isNotEmpty) {
        headers['Cookie'] = 'session_id=$cookieToUse';
        debugPrint('[WS] Attaching session cookie: session_id=$cookieToUse');
      } else {
        debugPrint('[WS] Warning: no session cookie/token — connecting without cookie.');
      }
      // Odoo requires Origin header — without it returns 400 "missing header: origin"
      headers['Origin'] = ApiConstants.wsOrigin;
      headers['ngrok-skip-browser-warning'] = 'true';

      // Ensure URL uses ws:// or wss:// scheme
      String wsEndpoint = _wsBaseUrl;
      if (wsEndpoint.startsWith('https://')) {
        wsEndpoint = wsEndpoint.replaceFirst('https://', 'wss://');
      } else if (wsEndpoint.startsWith('http://')) {
        wsEndpoint = wsEndpoint.replaceFirst('http://', 'ws://');
      }

      _ioSocket = await WebSocket.connect(
        wsEndpoint,
        headers: headers,
      );
      _channel = IOWebSocketChannel(_ioSocket!);

      _setStatus(WsStatus.connected);
      debugPrint('[WS] Connected successfully.');

      // Subscribe to channel
      _subscribe();

      // Listen to incoming messages
      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onStreamError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Odoo websocket_worker sends keep-alive 0x00 byte every 60s
      _keepAlive?.cancel();
      _keepAlive = Timer.periodic(const Duration(seconds: 60), (_) {
        try {
          _ioSocket?.add(Uint8List.fromList([0]));
          debugPrint('[WS] Sent keep-alive ping byte (0x00).');
        } catch (e) {
          debugPrint('[WS] Keep-alive ping failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[WS] Connection error: $e');
      _setStatus(WsStatus.error);
      onError?.call('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _subscribe() {
    final channels = <String>[];
    if (_channelId > 0) {
      channels.addAll([
        'discuss.channel_$_channelId',
        'channel_$_channelId',
      ]);
    }
    // If channels is empty, Odoo 18 auto-subscribes to user's partner channel
    final body = {
      'event_name': 'subscribe',
      'data': {
        'channels': channels,
        'last': _lastMessageId,
      },
    };
    final payload = jsonEncode(body);

    // Pretty-print the outgoing subscribe body
    final prettyPayload = const JsonEncoder.withIndent('  ').convert(body);
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ [WS] ➤ SEND BODY');
    debugPrint('│ URL : $_wsBaseUrl');
    prettyPayload.split('\n').forEach((line) => debugPrint('│ $line'));
    debugPrint('└─────────────────────────────────────────');

    _channel?.sink.add(payload);
  }

  void _onData(dynamic raw) {
    // Guard against binary keepalive ping/pong frames
    if (raw is! String) return;

    debugPrint('[WS] Raw message received: $raw');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        debugPrint('[WS] Parsed ${decoded.length} event(s).');
        for (final item in decoded) {
          if (item is Map && item['id'] != null) {
            final nid = item['id'] as int;
            if (nid > _lastMessageId) {
              _lastMessageId = nid;
            }
          }
        }
        onMessage?.call(decoded);
      } else {
        debugPrint('[WS] Unexpected message format: $decoded');
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e | raw: $raw');
    }
  }

  void _onStreamError(dynamic error) {
    debugPrint('[WS] Stream error: $error');
    _keepAlive?.cancel();
    _setStatus(WsStatus.error);
    onError?.call('Stream error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connection closed.');
    _keepAlive?.cancel();
    _setStatus(WsStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    debugPrint('[WS] Reconnecting in 3s...');
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect) _connect();
    });
  }

  void _setStatus(WsStatus s) {
    _status = s;
    onStatusChange?.call(s);
  }

  /// Disconnect and stop reconnecting
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _keepAlive?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _ioSocket?.close();
    _channel = null;
    _ioSocket = null;
    _setStatus(WsStatus.disconnected);
    debugPrint('[WS] Disconnected.');
  }
}
