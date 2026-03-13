import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TokenService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _userGuidKey = 'user_guid'; // ApplicationUser Id (String)
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _photoUrlKey = 'photo_url';
  static const String _phoneNumberKey = 'phone_number';
  static const String _facebookUrlKey = 'facebook_url';
  static const String _telegramUrlKey = 'telegram_url';
  static const String _whatsAppNumberKey = 'whatsapp_number';
  static const String _youTubeChannelUrlKey = 'youtube_channel_url';
  static const String _teacherIdKey = 'teacher_id';

  Future<void> saveExtendedUserInfo({
    String? photoUrl,
    String? phoneNumber,
    String? facebookUrl,
    String? telegramUrl,
    String? whatsAppNumber,
    String? youTubeChannelUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (photoUrl != null) await prefs.setString(_photoUrlKey, photoUrl);
    if (phoneNumber != null)
      await prefs.setString(_phoneNumberKey, phoneNumber);
    if (facebookUrl != null)
      await prefs.setString(_facebookUrlKey, facebookUrl);
    if (telegramUrl != null)
      await prefs.setString(_telegramUrlKey, telegramUrl);
    if (whatsAppNumber != null)
      await prefs.setString(_whatsAppNumberKey, whatsAppNumber);
    if (youTubeChannelUrl != null)
      await prefs.setString(_youTubeChannelUrlKey, youTubeChannelUrl);
  }

  Future<void> saveTeacherId(int teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_teacherIdKey, teacherId);
  }

  Future<int?> getTeacherId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_teacherIdKey);
  }

  Future<void> saveUserInfo({
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  Future<String?> getPhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_photoUrlKey);
  }

  Future<String?> getPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneNumberKey);
  }

  Future<String?> getFacebookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_facebookUrlKey);
  }

  Future<String?> getTelegramUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_telegramUrlKey);
  }

  Future<String?> getWhatsAppNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_whatsAppNumberKey);
  }

  Future<String?> getYouTubeChannelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_youTubeChannelUrlKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  Future<void> saveUserGuid(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userGuidKey, id);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt(_userIdKey);

    if (userId == null) {
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        try {
          print('Token found in getUserId fallback. Decoding...');
          final payload = _decodeToken(token);
          print('Token Payload Keys: ${payload.keys.toList()}');

          final val =
              payload['userId'] ??
              payload['UserId'] ??
              payload['studentId'] ??
              payload['StudentId'] ??
              payload['id'] ??
              payload['Id'];

          if (val is int) {
            userId = val;
            print('Found userId as int: $val');
          } else if (val is String) {
            userId = int.tryParse(val);
            print('Found userId as String: $val, parsed: $userId');
          } else {
            print(
              'Could not find compatible userId in payload. Value found: $val',
            );
          }

          if (userId != null) {
            await saveUserId(userId);
            print('Recovered userId from token: $userId');
          }
        } catch (e) {
          print('Error recovering userId from token: $e');
        }
      } else {
        print('Token is NULL in getUserId fallback.');
      }
    }
    return userId;
  }

  Future<String?> getUserGuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? guid = prefs.getString(_userGuidKey);

    // If GUID is missing OR looks like an integer (incorrectly saved ID), try to recover from token
    bool isSuspicious = false;
    if (guid != null) {
      // Check if it looks like a plain integer
      isSuspicious = int.tryParse(guid) != null;
    }

    if (guid == null || isSuspicious) {
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        try {
          final payload = _decodeToken(token);
          // Try common claim names for ID - Prioritize GUID claims over Integer ID claims
          guid =
              payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
              payload['sub'] ??
              payload['uid'] ??
              payload['sid'] ??
              payload['userGuid'] ??
              payload['id'] ??
              payload['Id'] ??
              payload['userId'] ??
              payload['UserId'];

          print('Debug GUID from Token: $guid'); // Debug print check

          if (guid != null) {
            await saveUserGuid(guid);
          }
        } catch (e) {
          print('Error decoding token for GUID: $e');
        }
      }
    }
    return guid;
  }

  Map<String, dynamic> _decodeToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }

    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('Invalid payload');
    }

    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        // Continue anyway, base64 decode might handle or throw
        break;
    }
    return utf8.decode(base64.decode(output));
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_photoUrlKey);
    await prefs.remove(_phoneNumberKey);
    await prefs.remove(_facebookUrlKey);
    await prefs.remove(_telegramUrlKey);
    await prefs.remove(_whatsAppNumberKey);
    await prefs.remove(_youTubeChannelUrlKey);
    await prefs.remove(_teacherIdKey);
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> deleteRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }

  Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  Future<void> deleteRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userRoleKey);
  }

  Future<void> deleteUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userGuidKey);
  }

  static const String _profileCompletedKeyPrefix = 'profile_completed_';

  Future<bool> hasProfileCompleted(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_profileCompletedKeyPrefix}$userId') ?? false;
  }

  Future<void> setProfileCompleted(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_profileCompletedKeyPrefix}$userId', true);
  }
}
