import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/storage/storage_service.dart';
import '../../domain/models/login_response.dart';
import '../../domain/models/api_user_model.dart';

class AuthApiService {
  final DioClient _dioClient = DioClient.instance;
  final StorageService _storageService = StorageService.instance;

  // Login
  Future<ApiResponse<LoginResponse>> login({
    required String login,
    required String password,
    String? serverUrl,
    String? database,
  }) async {
    try {
      // 1. Update active config if server or database supplied
      if (serverUrl != null && serverUrl.trim().isNotEmpty) {
        ApiConstants.updateConfig(
          serverUrl: serverUrl,
          database: database,
        );
        await _storageService.saveServerConfig(
          serverUrl: ApiConstants.serverUrl,
          database: ApiConstants.database,
        );
      } else if (database != null && database.trim().isNotEmpty) {
        ApiConstants.updateConfig(database: database);
        await _storageService.saveServerConfig(
          serverUrl: ApiConstants.serverUrl,
          database: ApiConstants.database,
        );
      }

      final response = await _dioClient.post(
        ApiConstants.login,
        data: {'login': login, 'password': password},
      );

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(response.data);

        // Save token and user credentials/data securely
        await _storageService.saveToken(loginResponse.sessionToken);
        await _storageService.saveCredentials(login: login, password: password);
        await _storageService.saveUserData(
          userId: loginResponse.userId,
          userName: loginResponse.userName,
          expiryTime: loginResponse.expiryTime,
        );

        // Step 1: Call Odoo official session authentication to save session_id cookie
        await authenticateOdooSession(
          login: login,
          password: password,
          db: ApiConstants.database,
        );

        // Step 2: Sync FCM token with database
        final fcmToken = await _storageService.getFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          try {
            debugPrint('📤 [Auth] Syncing FCM token to /api/save_fcm_token after login...');
            final fcmResp = await _dioClient.post(
              ApiConstants.saveFcmToken,
              data: {'fcm_token': fcmToken},
            );
            debugPrint('📥 [Auth] FCM token sync response: ${fcmResp.data}');
          } catch (e) {
            debugPrint('⚠️ [Auth] Could not sync FCM token on login: $e');
          }
        }

        return ApiResponse.success(
          loginResponse,
          message: 'Login successful',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Login failed',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  // Logout
  Future<ApiResponse<void>> logout() async {
    try {
      final response = await _dioClient.post(ApiConstants.logout);

      await _storageService.clearAll();

      if (response.statusCode == 200) {
        return ApiResponse.success(
          null,
          message: 'Logout successful',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Logout failed',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      await _storageService.clearAll();
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      await _storageService.clearAll();
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Get Users (with automatic offline cache)
  Future<ApiResponse<UsersResponse>> getUsers() async {
    try {
      final response = await _dioClient.get(ApiConstants.users);

      if (response.statusCode == 200) {
        final usersResponse = UsersResponse.fromJson(response.data);

        // Cache users in local storage for offline use
        if (response.data is Map && response.data['users'] is List) {
          await _storageService.cacheContacts(response.data['users'] as List);
        }

        return ApiResponse.success(
          usersResponse,
          message: 'Users fetched successfully',
          statusCode: response.statusCode,
        );
      } else {
        return await _getCachedUsersFallback('Failed to fetch users');
      }
    } on DioException catch (e) {
      return await _getCachedUsersFallback(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return await _getCachedUsersFallback('An unexpected error occurred');
    }
  }

  Future<ApiResponse<UsersResponse>> _getCachedUsersFallback(
    String errorMsg, {
    int? statusCode,
  }) async {
    final cached = await _storageService.getCachedContacts();
    if (cached != null && cached.isNotEmpty) {
      final users = cached
          .map((u) => ApiUserModel.fromJson(u as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(
        UsersResponse(success: true, users: users),
        message: 'Loaded from offline cache',
      );
    }
    return ApiResponse.error(errorMsg, statusCode: statusCode);
  }

  /// Step 1: Authenticate with Odoo official session (/web/session/authenticate)
  /// and save session_id cookie for WebRTC (/mail/rtc/*) and WebSocket bus.
  Future<String?> authenticateOdooSession({
    required String login,
    required String password,
    String? db,
  }) async {
    try {
      final dbToUse = db ?? ApiConstants.database;
      final response = await _dioClient.post(
        ApiConstants.sessionAuthenticate,
        data: {
          'jsonrpc': '2.0',
          'params': {
            'db': dbToUse,
            'login': login,
            'password': password,
          },
        },
      );

      String? sessionId;

      // 1. Try extracting session_id from response body (Odoo json-rpc result)
      if (response.data is Map && response.data['result'] is Map) {
        final result = response.data['result'] as Map;
        sessionId = result['session_id'] as String?;
      }

      // 2. Try extracting from Set-Cookie header if not in body
      if (sessionId == null || sessionId.isEmpty) {
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          for (final c in cookies) {
            final match = RegExp(r'session_id=([^;]+)').firstMatch(c);
            if (match != null) {
              sessionId = match.group(1);
              break;
            }
          }
        }
      }

      if (sessionId != null && sessionId.isNotEmpty) {
        await _storageService.saveSessionCookie(sessionId);
        debugPrint('[AUTH] Odoo session_id cookie saved: $sessionId');
        return sessionId;
      } else {
        debugPrint(
          '[AUTH] Warning: session_id could not be extracted from authenticate response',
        );
      }
    } catch (e) {
      debugPrint('[AUTH] Error during Odoo session authentication: $e');
    }
    return null;
  }

  // Save FCM Token to backend database
  Future<ApiResponse<Map<String, dynamic>>> saveFcmToken(String fcmToken) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.saveFcmToken,
        data: {'fcm_token': fcmToken},
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(
          response.data as Map<String, dynamic>,
          message: response.data['message'] ?? 'FCM token updated successfully.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to update FCM token',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }
}
