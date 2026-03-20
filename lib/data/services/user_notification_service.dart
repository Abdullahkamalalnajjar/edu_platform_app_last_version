import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/notification_models.dart';
import 'token_service.dart';

class UserNotificationService {
  final _tokenService = TokenService();

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final token = await _tokenService.getToken();
      final userId = await _tokenService.getUserGuid();

      if (userId == null) return 0;

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getUnreadNotifications(userId);
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        if (body['succeeded'] == true && body['data'] != null) {
          return (body['data'] as List).length;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Get user notifications
  Future<ApiResponse<List<NotificationItem>>> getUserNotifications({
    bool? isRead,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final userId = await _tokenService.getUserGuid();

      if (userId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'المستخدم غير مسجل الدخول',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Always use the base endpoint. If isRead is provided, add it as query param.
      // If isRead is null, it should fetch all (depending on API default behavior)
      final url = ApiConstants.getUserNotifications(userId, isRead: isRead);

      print('fetching notifications from: $url');
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 401) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'جلسة العمل انتهت، يرجى تسجيل الدخول مرة أخرى',
        );
      }

      print('Notification Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'لا توجد بيانات (رد فارغ من الخادم)',
        );
      }

      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse<List<NotificationItem>>.fromJson(
          body,
          (data) {
                final list = data as List;
                for (var e in list) {
                  print('📋 Notification raw keys: ${(e as Map).keys.toList()}');
                  print('📋 Notification raw data: $e');
                }
                return list.map((e) => NotificationItem.fromJson(e)).toList();
              },
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في جلب الإشعارات',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Mark single notification as read
  Future<ApiResponse<bool>> markAsRead(int notificationId) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.markNotificationAsRead(notificationId);
      final response = await http.put(Uri.parse(url), headers: headers);

      print('MarkAsRead Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        // If success status code but empty body, assume success
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message: 'تم تحديد الإشعار كمقروء',
            data: true,
          );
        }
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل في تحديث حالة الإشعار (رد فارغ)',
        );
      }

      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse(
          statusCode: 200,
          succeeded: true,
          message: 'تم تحديد الإشعار كمقروء',
          data: true,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في تحديث حالة الإشعار',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Mark all notifications as read
  Future<ApiResponse<bool>> markAllAsRead() async {
    try {
      final token = await _tokenService.getToken();
      final userId = await _tokenService.getUserGuid();

      if (userId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'المستخدم غير مسجل الدخول',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.markAllNotificationsAsRead(userId);
      final response = await http.put(Uri.parse(url), headers: headers);

      print('MarkAllAsRead Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        // If success status code but empty body, assume success
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message: 'تم تحديد جميع الإشعارات كمقروءة',
            data: true,
          );
        }
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل في تحديث حالة الإشعارات (رد فارغ)',
        );
      }

      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse(
          statusCode: 200,
          succeeded: true,
          message: 'تم تحديد جميع الإشعارات كمقروءة',
          data: true,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في تحديث حالة الإشعارات',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Delete all notifications
  Future<ApiResponse<bool>> deleteAll() async {
    try {
      final token = await _tokenService.getToken();
      final userId = await _tokenService.getUserGuid();

      if (userId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'المستخدم غير مسجل الدخول',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.deleteAllNotifications(userId);
      print('Deleting all notifications: $url');
      final response = await http.delete(Uri.parse(url), headers: headers);

      print('DeleteAll Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message: 'تم حذف جميع الإشعارات',
            data: true,
          );
        }
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل في حذف الإشعارات (رد فارغ)',
        );
      }

      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse(
          statusCode: 200,
          succeeded: true,
          message: 'تم حذف جميع الإشعارات',
          data: true,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في حذف الإشعارات',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Delete single notification
  Future<ApiResponse<bool>> deleteNotification(int id) async {
    try {
      final token = await _tokenService.getToken();
      final userId = await _tokenService.getUserGuid();

      if (userId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'المستخدم غير مسجل الدخول',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.deleteNotification(id, userId);
      final response = await http.delete(Uri.parse(url), headers: headers);

      print('Delete Notification ($id) Response: ${response.statusCode}');

      if (response.body.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message: 'تم حذف الإشعار',
            data: true,
          );
        }
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل في حذف الإشعار',
        );
      }

      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse(
          statusCode: 200,
          succeeded: true,
          message: 'تم حذف الإشعار',
          data: true,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في حذف الإشعار',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }
}
