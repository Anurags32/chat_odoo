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
}
