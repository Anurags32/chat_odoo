import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _preferences;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // Keys
  static const String _tokenKey = 'session_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _expiryTimeKey = 'expiry_time';

  // Save token
  Future<bool> saveToken(String token) async {
    return await _preferences?.setString(_tokenKey, token) ?? false;
  }

  // Get token
  Future<String?> getToken() async {
    return _preferences?.getString(_tokenKey);
  }

  // Save user data
  Future<bool> saveUserData({
    required int userId,
    required String userName,
    required String expiryTime,
  }) async {
    final results = await Future.wait([
      _preferences?.setInt(_userIdKey, userId) ?? Future.value(false),
      _preferences?.setString(_userNameKey, userName) ?? Future.value(false),
      _preferences?.setString(_expiryTimeKey, expiryTime) ??
          Future.value(false),
    ]);
    return results.every((result) => result);
  }

  // Get user ID
  Future<int?> getUserId() async {
    return _preferences?.getInt(_userIdKey);
  }

  // Get user name
  Future<String?> getUserName() async {
    return _preferences?.getString(_userNameKey);
  }

  // Get all user data
  Future<Map<String, dynamic>?> getUserData() async {
    final userId = await getUserId();
    final userName = await getUserName();
    final token = await getToken();
    final expiryTime = await getExpiryTime();

    if (userId == null || userName == null || token == null) {
      return null;
    }

    return {
      'user_id': userId,
      'user_name': userName,
      'session_token': token,
      'expiry_time': expiryTime,
    };
  }

  // Get expiry time
  Future<String?> getExpiryTime() async {
    return _preferences?.getString(_expiryTimeKey);
  }

  // Clear all data
  Future<bool> clearAll() async {
    return await _preferences?.clear() ?? false;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    // Check if session is expired
    final expiryTime = await getExpiryTime();
    if (expiryTime != null) {
      try {
        final expiry = DateTime.parse(expiryTime);
        final now = DateTime.now();
        
        // If session expired, clear all data
        if (now.isAfter(expiry)) {
          await clearAll();
          return false;
        }
      } catch (e) {
        // If parsing fails, assume not expired
        return true;
      }
    }

    return true;
  }
}
