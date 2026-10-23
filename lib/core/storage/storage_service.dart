import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _preferences;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // ── Secure Keys ──────────────────────────────────────────────────────────
  static const String _tokenKey = 'session_token';
  static const String _sessionCookieKey = 'session_cookie';
  static const String _serverUrlKey = 'odoo_server_url';
  static const String _databaseKey = 'odoo_database';
  static const String _passwordKey = 'saved_password';
  static const String _loginKey = 'saved_login';

  // ── Standard Prefs Keys ──────────────────────────────────────────────────
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _partnerIdKey = 'partner_id';
  static const String _userAvatarKey = 'user_avatar';
  static const String _expiryTimeKey = 'expiry_time';
  static const String _fcmTokenKey = 'fcm_device_token';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _cachedContactsKey = 'cached_contacts_json';
  static const String _cachedChannelsKey = 'cached_channels_json';
  static const String _cachedMessagesPrefix = 'cached_msgs_channel_';

  // ── Server & Database Settings ───────────────────────────────────────────
  Future<void> saveServerConfig({
    required String serverUrl,
    required String database,
  }) async {
    await _secureStorage.write(key: _serverUrlKey, value: serverUrl.trim());
    await _secureStorage.write(key: _databaseKey, value: database.trim());
  }

  Future<String?> getServerUrl() async {
    return await _secureStorage.read(key: _serverUrlKey);
  }

  Future<String?> getDatabase() async {
    return await _secureStorage.read(key: _databaseKey);
  }

  // ── Secure Credentials & Tokens ──────────────────────────────────────────
  Future<void> saveCredentials({
    required String login,
    required String password,
  }) async {
    await _secureStorage.write(key: _loginKey, value: login);
    await _secureStorage.write(key: _passwordKey, value: password);
  }

  Future<String?> getSavedLogin() async {
    return await _secureStorage.read(key: _loginKey);
  }

  Future<String?> getSavedPassword() async {
    return await _secureStorage.read(key: _passwordKey);
  }

  Future<bool> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      await _preferences?.setString(_tokenKey, token);
      return true;
    } catch (_) {
      return await _preferences?.setString(_tokenKey, token) ?? false;
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return _preferences?.getString(_tokenKey);
  }

  Future<bool> saveSessionCookie(String cookie) async {
    try {
      await _secureStorage.write(key: _sessionCookieKey, value: cookie);
      await _preferences?.setString(_sessionCookieKey, cookie);
      return true;
    } catch (_) {
      return await _preferences?.setString(_sessionCookieKey, cookie) ?? false;
    }
  }

  Future<String?> getSessionCookie() async {
    try {
      final cookie = await _secureStorage.read(key: _sessionCookieKey);
      if (cookie != null && cookie.isNotEmpty) return cookie;
    } catch (_) {}
    return _preferences?.getString(_sessionCookieKey);
  }

  // ── FCM Token ────────────────────────────────────────────────────────────
  Future<bool> saveFcmToken(String token) async {
    return await _preferences?.setString(_fcmTokenKey, token) ?? false;
  }

  Future<String?> getFcmToken() async {
    return _preferences?.getString(_fcmTokenKey);
  }

  // ── User Data ────────────────────────────────────────────────────────────
  Future<bool> saveUserData({
    required int userId,
    required String userName,
    required String expiryTime,
    int? partnerId,
    String? email,
    String? avatar,
  }) async {
    final results = await Future.wait([
      _preferences?.setInt(_userIdKey, userId) ?? Future.value(false),
      _preferences?.setString(_userNameKey, userName) ?? Future.value(false),
      _preferences?.setString(_expiryTimeKey, expiryTime) ?? Future.value(false),
      if (partnerId != null)
        _preferences?.setInt(_partnerIdKey, partnerId) ?? Future.value(false),
      if (email != null)
        _preferences?.setString(_userEmailKey, email) ?? Future.value(false),
      if (avatar != null)
        _preferences?.setString(_userAvatarKey, avatar) ?? Future.value(false),
    ]);
    return results.every((result) => result);
  }

  Future<int?> getUserId() async => _preferences?.getInt(_userIdKey);
  Future<String?> getUserName() async => _preferences?.getString(_userNameKey);
  Future<String?> getUserEmail() async => _preferences?.getString(_userEmailKey);
  Future<int?> getPartnerId() async => _preferences?.getInt(_partnerIdKey);
  Future<String?> getUserAvatar() async => _preferences?.getString(_userAvatarKey);
  Future<String?> getExpiryTime() async => _preferences?.getString(_expiryTimeKey);

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
      'partner_id': await getPartnerId(),
      'email': await getUserEmail(),
      'avatar': await getUserAvatar(),
    };
  }

  // ── Onboarding & Theme Preferences ───────────────────────────────────────
  Future<bool> isOnboardingComplete() async {
    return _preferences?.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await _preferences?.setBool(_onboardingCompleteKey, complete);
  }

  Future<bool> isDarkMode() async {
    return _preferences?.getBool(_isDarkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _preferences?.setBool(_isDarkModeKey, isDark);
  }

  // ── Offline Caching for Contacts, Channels, Messages ─────────────────────
  Future<void> cacheContacts(List<dynamic> contactsJson) async {
    await _preferences?.setString(_cachedContactsKey, jsonEncode(contactsJson));
  }

  Future<List<dynamic>?> getCachedContacts() async {
    final raw = _preferences?.getString(_cachedContactsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheChannels(List<dynamic> channelsJson) async {
    await _preferences?.setString(_cachedChannelsKey, jsonEncode(channelsJson));
  }

  Future<List<dynamic>?> getCachedChannels() async {
    final raw = _preferences?.getString(_cachedChannelsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheMessages(int channelId, List<dynamic> messagesJson) async {
    await _preferences?.setString(
      '$_cachedMessagesPrefix$channelId',
      jsonEncode(messagesJson),
    );
  }

  Future<List<dynamic>?> getCachedMessages(int channelId) async {
    final raw = _preferences?.getString('$_cachedMessagesPrefix$channelId');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Call History Caching ──────────────────────────────────────────────────
  static const String _cachedCallsKey = 'cached_calls_history_json';

  Future<void> saveCallRecord(Map<String, dynamic> callJson) async {
    try {
      final existing = await getCallHistory();
      existing.insert(0, callJson);
      if (existing.length > 50) {
        existing.removeRange(50, existing.length);
      }
      await _preferences?.setString(_cachedCallsKey, jsonEncode(existing));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCallHistory() async {
    final raw = _preferences?.getString(_cachedCallsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Clear & Logout ───────────────────────────────────────────────────────
  Future<bool> clearAll() async {
    await _secureStorage.deleteAll();
    final onboardingDone = await isOnboardingComplete();
    final isDark = await isDarkMode();
    final success = await _preferences?.clear() ?? false;
    // Retain non-auth device preferences
    await setOnboardingComplete(onboardingDone);
    await setDarkMode(isDark);
    return success;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    final expiryTime = await getExpiryTime();
    if (expiryTime != null) {
      try {
        final expiry = DateTime.parse(expiryTime);
        if (DateTime.now().isAfter(expiry)) {
          await clearAll();
          return false;
        }
      } catch (_) {
        return true;
      }
    }
    return true;
  }
}
