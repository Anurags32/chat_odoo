import 'package:dio/dio.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../config.dart';
import 'rtc_logger.dart';

class OdooApi {
  String _baseUrl;
  String? _sessionCookie;
  int? _uid;
  int? _partnerId;
  String? _userName;

  late Dio _dio;

  OdooApi({String? baseUrl})
    : _baseUrl = _sanitizeUrl(baseUrl ?? CallConfig.defaultBaseUrl) {
    _initDio();
  }

  static String _sanitizeUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_sessionCookie == null || _sessionCookie!.isEmpty) {
            try {
              final stored = await StorageService.instance.getSessionCookie();
              if (stored != null && stored.isNotEmpty) {
                _sessionCookie = stored;
              }
            } catch (_) {}
          }
          if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
            options.headers['Cookie'] = 'session_id=$_sessionCookie';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final setCookies = response.headers['set-cookie'];
          if (setCookies != null) {
            for (final c in setCookies) {
              final match = RegExp(r'session_id=([^;]+)').firstMatch(c);
              if (match != null) {
                final extracted = match.group(1);
                if (extracted != null && extracted.isNotEmpty) {
                  _sessionCookie = extracted;
                  StorageService.instance.saveSessionCookie(extracted);
                }
              }
            }
          }
          return handler.next(response);
        },
      ),
    );
  }

  String get baseUrl => _baseUrl;
  String? get sessionCookie => _sessionCookie;
  int? get uid => _uid;
  int? get partnerId => _partnerId;
  String? get userName => _userName;

  void updateBaseUrl(String newUrl) {
    _baseUrl = _sanitizeUrl(newUrl);
    _dio.options.baseUrl = _baseUrl;
    RtcLogger.instance.log(
      'Updated Odoo API Base URL: $_baseUrl',
      tag: 'ODOO-API',
    );
  }

  Future<bool> authenticate({
    required String db,
    required String login,
    required String password,
    String? baseUrl,
  }) async {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      updateBaseUrl(baseUrl);
    }

    final url = '$_baseUrl/web/session/authenticate';
    final payload = {
      'jsonrpc': '2.0',
      'params': {'db': db, 'login': login, 'password': password},
    };

    RtcLogger.instance.log(
      'Authenticating $login against $url (db: $db)...',
      tag: 'ODOO-API',
    );

    try {
      final response = await _dio.post(url, data: payload);
      final data = response.data;

      if (data is Map && data['result'] != null) {
        final result = data['result'] as Map<String, dynamic>;
        _uid = result['uid'] as int?;
        _partnerId = result['partner_id'] as int?;
        _userName = result['name'] as String?;

        final sid = result['session_id'] as String?;
        if (sid != null && sid.isNotEmpty) {
          _sessionCookie = sid;
        }

        if (_sessionCookie == null || _sessionCookie!.isEmpty) {
          final cookies = response.headers['set-cookie'];
          if (cookies != null) {
            for (final c in cookies) {
              final match = RegExp(r'session_id=([^;]+)').firstMatch(c);
              if (match != null) {
                _sessionCookie = match.group(1);
                break;
              }
            }
          }
        }

        if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
          await StorageService.instance.saveSessionCookie(_sessionCookie!);
          await StorageService.instance.saveCredentials(
            login: login,
            password: password,
          );
          await StorageService.instance.saveUserData(
            userId: _uid ?? 1,
            userName: _userName ?? login,
            expiryTime: '',
            partnerId: _partnerId,
          );

          RtcLogger.instance.log(
            'Authentication SUCCESS: uid=$_uid partnerId=$_partnerId name=$_userName session_id=${_sessionCookie!.substring(0, _sessionCookie!.length > 10 ? 10 : _sessionCookie!.length)}...',
            tag: 'ODOO-API',
          );
          return true;
        }
      }

      final error = data is Map ? data['error'] : 'Unknown error';
      RtcLogger.instance.log('Authentication FAILED: $error', tag: 'ODOO-API');
      return false;
    } catch (e) {
      RtcLogger.instance.log('Authentication ERROR: $e', tag: 'ODOO-API');
      return false;
    }
  }

  Future<Map<String, dynamic>> joinCall({
    required int channelId,
    List<int>? checkRtcSessionIds,
  }) async {
    final url = '$_baseUrl/mail/rtc/channel/join_call';
    final payload = {
      'jsonrpc': '2.0',
      'params': {
        'channel_id': channelId,
        'check_rtc_session_ids': checkRtcSessionIds ?? [],
        'camera': false,
      },
    };

    RtcLogger.instance.log(
      'Joining RTC call on channel $channelId...',
      tag: 'ODOO-API',
    );

    try {
      final response = await _dio.post(url, data: payload);
      final data = response.data;

      if (data is Map && data['result'] != null) {
        final result = data['result'];
        RtcLogger.instance.log(
          'join_call response result received: $result',
          tag: 'ODOO-API',
        );

        int? sessionId;
        List<dynamic> iceServers = [];
        List<dynamic> rtcSessions = [];
        Map<String, dynamic>? serverInfo;

        if (result is Map) {
          // 1. Odoo 18 format: result['Rtc']['selfSession'] & result['Rtc']['iceServers']
          if (result['Rtc'] is Map) {
            final rtc = result['Rtc'] as Map;
            if (rtc['selfSession'] != null) {
              sessionId = rtc['selfSession'] as int?;
            }
            if (rtc['iceServers'] is List) {
              iceServers = rtc['iceServers'] as List;
            }
          }

          // 2. Standard Odoo 16/17 fallback formats
          sessionId ??=
              result['sessionId'] as int? ??
              result['rtcsession_id'] as int? ??
              result['rtc_session_id'] as int?;

          if (iceServers.isEmpty) {
            if (result['iceServers'] is List) {
              iceServers = result['iceServers'] as List;
            } else if (result['ice_servers'] is List) {
              iceServers = result['ice_servers'] as List;
            }
          }

          if (result['rtcSessions'] is List) {
            rtcSessions = result['rtcSessions'] as List;
          } else if (result['discuss.channel'] is List) {
            // Odoo 18 discuss.channel format
            for (final ch in result['discuss.channel']) {
              if (ch is Map && ch['id'] == channelId && ch['rtcSessions'] is List) {
                final ops = ch['rtcSessions'] as List;
                for (final op in ops) {
                  if (op is List && op.length == 2 && op[0] == 'ADD' && op[1] is List) {
                    for (final sId in op[1]) {
                      rtcSessions.add({'id': sId});
                    }
                  }
                }
              }
            }
          }

          if (result['serverInfo'] is Map) {
            serverInfo = (result['serverInfo'] as Map).cast<String, dynamic>();
          }

          // 3. Odoo 18 Store format fallback
          if (sessionId == null &&
              result.containsKey('discuss.channel.rtc.session')) {
            final sessions = result['discuss.channel.rtc.session'];
            if (sessions is List && sessions.isNotEmpty) {
              final lastSession = sessions.last;
              if (lastSession is Map && lastSession['id'] != null) {
                sessionId = lastSession['id'] as int;
              }
              if (rtcSessions.isEmpty) rtcSessions = sessions;
            }
          }
        }

        return {
          'sessionId': sessionId,
          'iceServers': iceServers,
          'rtcSessions': rtcSessions,
          'serverInfo': serverInfo,
          'raw': result,
        };
      }

      final error = data is Map ? data['error'] : 'Unknown response structure';
      RtcLogger.instance.log('join_call FAILED: $error', tag: 'ODOO-API');
      return {'error': error};
    } catch (e) {
      RtcLogger.instance.log('join_call EXCEPTION: $e', tag: 'ODOO-API');
      return {'error': e.toString()};
    }
  }

  /// Call /mail/rtc/channel/leave_call
  Future<bool> leaveCall({required int channelId}) async {
    final url = '$_baseUrl/mail/rtc/channel/leave_call';
    final payload = {
      'jsonrpc': '2.0',
      'params': {'channel_id': channelId},
    };

    RtcLogger.instance.log(
      'Leaving RTC call on channel $channelId...',
      tag: 'ODOO-API',
    );

    try {
      final response = await _dio.post(url, data: payload);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        RtcLogger.instance.log(
          'leave_call returned error: ${data['error']}',
          tag: 'ODOO-API',
        );
        return false;
      }
      RtcLogger.instance.log(
        'leave_call completed with HTTP status: ${response.statusCode}',
        tag: 'ODOO-API',
      );
      return response.statusCode == 200;
    } catch (e) {
      RtcLogger.instance.log('leave_call ERROR: $e', tag: 'ODOO-API');
      return false;
    }
  }

  /// Call /mail/rtc/session/notify_call_members
  ///
  /// :param peer_notifications: list of tuples:
  ///   [sender_session_id, [target_session_id1, ...], content_string]
  Future<int> notifyCallMembers({
    required List<List<dynamic>> peerNotifications,
  }) async {
    final url = '$_baseUrl/mail/rtc/session/notify_call_members';
    final payload = {
      'jsonrpc': '2.0',
      'params': {'peer_notifications': peerNotifications},
    };

    try {
      final response = await _dio.post(url, data: payload);
      final statusCode = response.statusCode ?? 200;
      return statusCode;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 500;
      RtcLogger.instance.log(
        'notify_call_members DioException: $e (status: $code)',
        tag: 'ODOO-API',
      );
      return code;
    } catch (e) {
      RtcLogger.instance.log(
        'notify_call_members unexpected exception: $e',
        tag: 'ODOO-API',
      );
      return 500;
    }
  }

  /// Call /mail/rtc/session/update_and_broadcast
  Future<bool> updateAndBroadcast({
    required int sessionId,
    required Map<String, dynamic> values,
  }) async {
    final url = '$_baseUrl/mail/rtc/session/update_and_broadcast';
    final payload = {
      'jsonrpc': '2.0',
      'params': {'session_id': sessionId, 'values': values},
    };

    try {
      final response = await _dio.post(url, data: payload);
      return response.statusCode == 200;
    } catch (e) {
      RtcLogger.instance.log('update_and_broadcast ERROR: $e', tag: 'ODOO-API');
      return false;
    }
  }

  /// Call /discuss/channel/ping (Odoo 18 call keep-alive every 30s)
  Future<bool> pingChannel({
    required int channelId,
    required int rtcSessionId,
    required List<int> checkRtcSessionIds,
  }) async {
    final url = '$_baseUrl/discuss/channel/ping';
    final payload = {
      'jsonrpc': '2.0',
      'params': {
        'channel_id': channelId,
        'rtc_session_id': rtcSessionId,
        'check_rtc_session_ids': checkRtcSessionIds,
      },
    };

    try {
      final response = await _dio.post(url, data: payload);
      return response.statusCode == 200;
    } catch (e) {
      RtcLogger.instance.log('pingChannel error: $e', tag: 'ODOO-API');
      return false;
    }
  }
}
