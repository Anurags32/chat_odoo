import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/storage_service.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get token and session cookie from storage
    final token = await StorageService.instance.getToken();
    final sessionCookie = await StorageService.instance.getSessionCookie();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      options.headers['Cookie'] = 'session_id=$sessionCookie';
    }

    debugPrint(
      '\x1B[32m🚀 REQUEST[${options.method}] => PATH: ${options.path}\x1B[0m',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '\x1B[32m✅ RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}\x1B[0m',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '\x1B[31m❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}\x1B[0m',
    );
    super.onError(err, handler);
  }
}
