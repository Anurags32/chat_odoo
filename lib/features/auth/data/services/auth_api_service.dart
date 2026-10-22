import 'package:dio/dio.dart';
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
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.login,
        data: {'login': login, 'password': password},
      );

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(response.data);

        // Save token and user data
        await _storageService.saveToken(loginResponse.sessionToken);
        await _storageService.saveUserData(
          userId: loginResponse.userId,
          userName: loginResponse.userName,
          expiryTime: loginResponse.expiryTime,
        );

        // Step 1: Call Odoo official session authentication to save session_id cookie
        await authenticateOdooSession(
          login: login,
          password: password,
        );

        // Step 2: Sync FCM token with database
        final fcmToken = await _storageService.getFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          try {
            print('\x1B[32m📤 [Auth] Syncing FCM token to /api/save_fcm_token after login...\x1B[0m');
            final fcmResp = await _dioClient.post(
              ApiConstants.saveFcmToken,
              data: {'fcm_token': fcmToken},
            );
            print('\x1B[32m📥 [Auth] FCM token sync response: ${fcmResp.data}\x1B[0m');
          } catch (e) {
            print('\x1B[33m⚠️ [Auth] Could not sync FCM token on login: $e\x1B[0m');
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
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Logout
  Future<ApiResponse<void>> logout() async {
    try {
      final response = await _dioClient.post(ApiConstants.logout);

      if (response.statusCode == 200) {
        // Clear local storage
        await _storageService.clearAll();

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
      // Clear local storage even if API fails
      await _storageService.clearAll();

      return ApiResponse.error(
        e.response?.data['message'] ?? 'Network error occurred',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      // Clear local storage even if error occurs
      await _storageService.clearAll();

      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Get Users
  Future<ApiResponse<UsersResponse>> getUsers() async {
    try {
      final response = await _dioClient.get(ApiConstants.users);

      if (response.statusCode == 200) {
        final usersResponse = UsersResponse.fromJson(response.data);

        return ApiResponse.success(
          usersResponse,
          message: 'Users fetched successfully',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch users',
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

  /// Step 1: Authenticate with Odoo official session (/web/session/authenticate)
  /// and save session_id cookie for WebRTC (/mail/rtc/*) and WebSocket bus.
  Future<String?> authenticateOdooSession({
    required String login,
    required String password,
    String db = ApiConstants.database,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.sessionAuthenticate,
        data: {
          'jsonrpc': '2.0',
          'params': {
            'db': db,
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
        print('\x1B[32m[AUTH] Odoo session_id cookie saved: $sessionId\x1B[0m');
        return sessionId;
      } else {
        print(
          '\x1B[33m[AUTH] Warning: session_id could not be extracted from authenticate response\x1B[0m',
        );
      }
    } catch (e) {
      print('\x1B[31m[AUTH] Error during Odoo session authentication: $e\x1B[0m');
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
