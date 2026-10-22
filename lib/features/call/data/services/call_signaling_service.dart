import 'package:flutter/foundation.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_constants.dart';
import '../models/call_model.dart';
import '../models/ice_server_model.dart';

class CallSignalingService {
  final DioClient _dio = DioClient.instance;

  /// Fetch ICE servers (STUN + Coturn HMAC credentials)
  Future<List<IceServerModel>> fetchIceServers() async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcIceServers,
        data: {'jsonrpc': '2.0', 'params': {}},
      );

      final result = _unwrapResult(response.data);
      if (result != null && result['ice_servers'] is List) {
        final list = result['ice_servers'] as List;
        return list.map((item) => IceServerModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[Signaling] Failed to fetch ICE servers: $e. Falling back to default STUN.');
    }

    // Default fallback public STUN
    return [
      IceServerModel(urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']),
    ];
  }

  /// Register FCM / APNs VoIP push token
  Future<bool> registerDevice({
    required String platform,
    String? deviceId,
    String? fcmToken,
    String? voipToken,
  }) async {
    if (fcmToken != null && fcmToken.isNotEmpty) {
      try {
        final response = await _dio.post(
          ApiConstants.saveFcmToken,
          data: {'fcm_token': fcmToken},
        );
        final data = response.data;
        return data is Map && (data['success'] == true || data['status'] == 'success');
      } catch (e) {
        debugPrint('[Signaling] Failed to register FCM token with database: $e');
        return false;
      }
    }
    return true;
  }

  /// Start a 1-to-1 audio or video call
  Future<CallModel?> startCall({
    required int calleePartnerId,
    required CallType callType,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcCallStart,
        data: {
          'jsonrpc': '2.0',
          'params': {
            'callee_partner_id': calleePartnerId,
            'call_type': callType == CallType.video ? 'video' : 'audio',
          },
        },
      );

      final result = _unwrapResult(response.data);
      if (result != null && result['call'] != null) {
        return CallModel.fromJson(result['call'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[Signaling] Error starting call: $e');
    }
    return null;
  }

  /// Accept incoming call
  Future<CallModel?> acceptCall(int callId) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcCallAccept,
        data: {
          'jsonrpc': '2.0',
          'params': {'call_id': callId},
        },
      );

      final result = _unwrapResult(response.data);
      if (result != null && result['call'] != null) {
        return CallModel.fromJson(result['call'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[Signaling] Error accepting call: $e');
    }
    return null;
  }

  /// Reject incoming call
  Future<bool> rejectCall(int callId, {String reason = 'rejected'}) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcCallReject,
        data: {
          'jsonrpc': '2.0',
          'params': {'call_id': callId, 'reason': reason},
        },
      );
      final result = _unwrapResult(response.data);
      return result != null && result['status'] == 'success';
    } catch (e) {
      debugPrint('[Signaling] Error rejecting call: $e');
      return false;
    }
  }

  /// Cancel outgoing call before answer
  Future<bool> cancelCall(int callId) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcCallCancel,
        data: {
          'jsonrpc': '2.0',
          'params': {'call_id': callId},
        },
      );
      final result = _unwrapResult(response.data);
      return result != null && result['status'] == 'success';
    } catch (e) {
      debugPrint('[Signaling] Error cancelling call: $e');
      return false;
    }
  }

  /// End ongoing call
  Future<bool> endCall(int callId, {String reason = 'normal'}) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcCallEnd,
        data: {
          'jsonrpc': '2.0',
          'params': {'call_id': callId, 'reason': reason},
        },
      );
      final result = _unwrapResult(response.data);
      return result != null && result['status'] == 'success';
    } catch (e) {
      debugPrint('[Signaling] Error ending call: $e');
      return false;
    }
  }

  /// Relay WebRTC SDP offer, answer, or ICE candidate via Odoo bus
  Future<bool> sendSignal({
    required int callId,
    required String type, // 'offer', 'answer', or 'candidate'
    required dynamic payload,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcSignal,
        data: {
          'jsonrpc': '2.0',
          'params': {
            'call_id': callId,
            'type': type,
            'payload': payload,
          },
        },
      );
      final result = _unwrapResult(response.data);
      return result != null && result['status'] == 'success';
    } catch (e) {
      debugPrint('[Signaling] Error relaying signal ($type): $e');
      return false;
    }
  }

  /// Fetch call history
  Future<List<CallModel>> fetchHistory({int limit = 30, int offset = 0}) async {
    try {
      final response = await _dio.post(
        ApiConstants.webrtcCallHistory,
        data: {
          'jsonrpc': '2.0',
          'params': {'limit': limit, 'offset': offset},
        },
      );

      final result = _unwrapResult(response.data);
      if (result != null && result['calls'] is List) {
        final list = result['calls'] as List;
        return list.map((item) => CallModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[Signaling] Error fetching call history: $e');
    }
    return [];
  }

  /// Helper to extract standard Odoo JSON-RPC result
  dynamic _unwrapResult(dynamic data) {
    if (data is Map) {
      if (data.containsKey('result')) {
        return data['result'];
      }
      if (data.containsKey('error')) {
        debugPrint('[Signaling] Odoo server error: ${data['error']}');
      }
    }
    return data;
  }
}
