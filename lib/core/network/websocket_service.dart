import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../storage/storage_service.dart';

/// WebSocket connection states
enum WsStatus { disconnected, connecting, connected, error }

/// Callback types
typedef OnMessageCallback = void Function(List<dynamic> messages);
typedef OnStatusCallback = void Function(WsStatus status);
typedef OnErrorCallback = void Function(String error);

class WebSocketService {
  static const String _wsBaseUrl = 'ws://192.168.29.231:8072/websocket';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

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
      final token = await StorageService.instance.getToken();

      // ── Debug: raw HTTP response before WS upgrade ──────────────────────
      await _debugHttpResponse(token);
      // ────────────────────────────────────────────────────────────────────

      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Cookie'] = 'session_id=$token';
        print('[WS] Attaching session cookie: session_id=$token');
      } else {
        print('[WS] Warning: no session token — connecting without cookie.');
      }
      // Odoo requires Origin header — without it returns 400 "missing header: origin"
      headers['Origin'] = 'http://192.168.29.231:8072';

      final ioSocket = await WebSocket.connect(
        _wsBaseUrl,
        headers: headers,
      );
      _channel = IOWebSocketChannel(ioSocket);

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
    } catch (e) {
      debugPrint('[WS] Connection error: $e');
      _setStatus(WsStatus.error);
      onError?.call('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _subscribe() {
    final body = {
      'event_name': 'subscribe',
      'data': {
        'channels': ['channel_$_channelId'],
        'last': _lastMessageId,
      },
    };
    final payload = jsonEncode(body);

    // Pretty-print the outgoing subscribe body
    final prettyPayload = const JsonEncoder.withIndent('  ').convert(body);
    print('┌─────────────────────────────────────────');
    print('│ [WS] ➤ SEND BODY');
    print('│ URL : $_wsBaseUrl');
    prettyPayload.split('\n').forEach((line) => print('│ $line'));
    print('└─────────────────────────────────────────');

    _channel?.sink.add(payload);
  }

  void _onData(dynamic raw) {
    debugPrint('[WS] Raw message received: $raw');
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is List) {
        debugPrint('[WS] Parsed ${decoded.length} event(s).');
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
    _setStatus(WsStatus.error);
    onError?.call('Stream error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connection closed.');
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
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _setStatus(WsStatus.disconnected);
    debugPrint('[WS] Disconnected.');
  }

  // ── Debug helper: fire a plain HTTP request to the WS endpoint and print
  // the raw status + headers + body so we can see exactly why 400 is returned.
  Future<void> _debugHttpResponse(String? token) async {
    try {
      final httpUrl = _wsBaseUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('wss://', 'https://');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final req = await client.getUrl(Uri.parse(httpUrl));
      req.headers.set('Upgrade', 'websocket');
      req.headers.set('Connection', 'Upgrade');
      req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
      req.headers.set('Sec-WebSocket-Version', '13');
      if (token != null && token.isNotEmpty) {
        req.headers.set('Cookie', 'session_id=$token');
      }

      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();

      print('┌─────────────────────────────────────────');
      print('│ [WS DEBUG] Raw server response');
      print('│ Status : ${resp.statusCode} ${resp.reasonPhrase}');
      print('│ Headers:');
      resp.headers.forEach((name, values) {
        print('│   $name: ${values.join(', ')}');
      });
      print('│ Body   : $body');
      print('└─────────────────────────────────────────');

      client.close();
    } catch (e) {
      print('[WS DEBUG] Could not fetch debug response: $e');
    }
  }
}
