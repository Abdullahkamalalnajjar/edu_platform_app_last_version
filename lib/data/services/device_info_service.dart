import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service to get device information for session management
class DeviceInfoService {
  static const String _deviceIdKey = 'device_id';
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Generate a simple UUID-like string
  static String _generateUUID() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));

    // Set version 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Get or generate a unique device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a new UUID for this device
      deviceId = _generateUUID();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// Get a detailed, human-readable device name
  static Future<String> getDeviceName() async {
    try {
      if (kIsWeb) {
        // For web, get browser info
        final webInfo = await _deviceInfo.webBrowserInfo;
        final browserName = _getBrowserName(webInfo.browserName);
        final platform = webInfo.platform ?? 'الويب';
        return '$browserName على $platform';
      }

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        // Capitalize brand
        final brandCapitalized = brand.isNotEmpty
            ? brand[0].toUpperCase() + brand.substring(1)
            : 'Android';
        return '$brandCapitalized $model';
      }

      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final model = iosInfo.utsname.machine;
        final name = iosInfo.name;
        return '$name ($model)';
      }

      if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        final computerName = windowsInfo.computerName;
        return 'Windows - $computerName';
      }

      if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        final computerName = macInfo.computerName;
        return 'macOS - $computerName';
      }

      if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        final name = linuxInfo.prettyName;
        return 'Linux - $name';
      }
    } catch (e) {
      print('Error getting device name: $e');
    }

    return 'جهاز غير معروف';
  }

  /// Convert BrowserName enum to Arabic string
  static String _getBrowserName(BrowserName? browserName) {
    switch (browserName) {
      case BrowserName.chrome:
        return 'Chrome';
      case BrowserName.firefox:
        return 'Firefox';
      case BrowserName.safari:
        return 'Safari';
      case BrowserName.edge:
        return 'Edge';
      case BrowserName.opera:
        return 'Opera';
      case BrowserName.msie:
        return 'Internet Explorer';
      case BrowserName.samsungInternet:
        return 'Samsung Internet';
      default:
        return 'متصفح الويب';
    }
  }

  /// Get detailed device info for debugging
  static Future<Map<String, String>> getDetailedDeviceInfo() async {
    final info = <String, String>{};

    try {
      info['deviceId'] = await getDeviceId();
      info['deviceName'] = await getDeviceName();

      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        info['platform'] = webInfo.platform ?? 'Unknown';
        info['userAgent'] = webInfo.userAgent ?? 'Unknown';
        info['vendor'] = webInfo.vendor ?? 'Unknown';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info['brand'] = androidInfo.brand;
        info['model'] = androidInfo.model;
        info['androidVersion'] = androidInfo.version.release;
        info['sdkVersion'] = androidInfo.version.sdkInt.toString();
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info['name'] = iosInfo.name;
        info['systemVersion'] = iosInfo.systemVersion;
        info['model'] = iosInfo.model;
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        info['computerName'] = windowsInfo.computerName;
        info['productName'] = windowsInfo.productName;
      }
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }

  /// Clear the device ID (useful for testing or reset)
  static Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
  }

  /// Save the device ID for the current session
  static Future<void> saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, deviceId);
  }
}
