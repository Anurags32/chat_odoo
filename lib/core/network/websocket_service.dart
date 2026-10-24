import 'dart:async';
import 'odoo_bus_service.dart';

/// WebSocket connection states for backward compatibility with chat
enum WsStatus { disconnected, connecting, connected, error }

/// Callback types
typedef OnMessageCallback = void Function(List<dynamic> messages);
typedef OnStatusCallback = void Function(WsStatus status);
typedef OnErrorCallback = void Function(String error);

/// Facade for WebSocketService backed by the unified OdooBusService
class WebSocketService {
  final OdooBusService _bus = OdooBusService.instance;

  StreamSubscription? _statusSub;
  StreamSubscription? _eventsSub;

  OnMessageCallback? onMessage;
  OnStatusCallback? onStatusChange;
  OnErrorCallback? onError;

  int _channelId = 0;

  WsStatus get status {
    switch (_bus.status) {
      case BusStatus.connected:
        return WsStatus.connected;
      case BusStatus.connecting:
        return WsStatus.connecting;
      case BusStatus.error:
        return WsStatus.error;
      case BusStatus.disconnected:
        return WsStatus.disconnected;
    }
  }

  WebSocketService() {
    _statusSub = _bus.statusStream.listen((busStatus) {
      onStatusChange?.call(status);
    });

    _bus.onRawMessages = (msgs) {
      onMessage?.call(msgs);
    };
  }

  /// Connect and subscribe to a channel
  Future<void> connect({
    required int channelId,
    int lastMessageId = 0,
  }) async {
    _channelId = channelId;
    if (channelId > 0) {
      _bus.addChannel('discuss.channel_$channelId');
      _bus.addChannel('channel_$channelId');
    }
    await _bus.connect();
  }

  /// Disconnect this channel's subscription
  Future<void> disconnect() async {
    if (_channelId > 0) {
      _bus.removeChannel('discuss.channel_$_channelId');
      _bus.removeChannel('channel_$_channelId');
      _channelId = 0;
    }
  }

  void dispose() {
    _statusSub?.cancel();
    _eventsSub?.cancel();
  }
}
