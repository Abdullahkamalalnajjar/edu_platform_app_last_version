import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches FCM notification data payloads locally so that
/// the in-app notification list can use them for navigation.
class NotificationCacheService {
  static const String _cacheKey = 'notification_data_cache';
  static const int _maxCacheSize = 200;

  /// Save an FCM notification data payload to cache.
  /// Key is generated from title + body to match with API notifications.
  static Future<void> cacheNotificationData(Map<String, dynamic> data,
      {String? title, String? body}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      final List<Map<String, dynamic>> cache = cacheJson != null
          ? List<Map<String, dynamic>>.from(jsonDecode(cacheJson))
          : [];

      final entry = {
        'title': title ?? data['title'] ?? '',
        'body': body ?? data['body'] ?? '',
        'data': Map<String, dynamic>.from(data),
        'cachedAt': DateTime.now().toIso8601String(),
      };

      // Add to beginning (newest first)
      cache.insert(0, entry);

      // Trim to max size
      if (cache.length > _maxCacheSize) {
        cache.removeRange(_maxCacheSize, cache.length);
      }

      await prefs.setString(_cacheKey, jsonEncode(cache));
      print('💾 Cached notification data: type=${data['type']}, title=$title');
    } catch (e) {
      print('❌ Error caching notification data: $e');
    }
  }

  /// Find cached data for a notification by matching title and body.
  static Future<Map<String, dynamic>?> findCachedData(
      String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson == null) return null;

      final List<dynamic> cache = jsonDecode(cacheJson);

      for (var entry in cache) {
        final cachedTitle = entry['title'] ?? '';
        final cachedBody = entry['body'] ?? '';

        // Match by title and body (exact or partial)
        if (_isMatch(cachedTitle, title) && _isMatch(cachedBody, body)) {
          return Map<String, dynamic>.from(entry['data']);
        }
      }

      // Fallback: match by title only
      for (var entry in cache) {
        final cachedTitle = entry['title'] ?? '';
        if (_isMatch(cachedTitle, title)) {
          return Map<String, dynamic>.from(entry['data']);
        }
      }

      return null;
    } catch (e) {
      print('❌ Error finding cached notification data: $e');
      return null;
    }
  }

  /// Check if two strings match (exact or one contains the other)
  static bool _isMatch(String cached, String apiValue) {
    if (cached.isEmpty || apiValue.isEmpty) return false;
    // Exact match
    if (cached == apiValue) return true;
    // Partial match (API title might be trimmed or different)
    if (cached.contains(apiValue) || apiValue.contains(cached)) return true;
    return false;
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
