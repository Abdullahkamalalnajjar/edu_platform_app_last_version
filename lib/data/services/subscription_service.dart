import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_models.dart';
import '../models/api_response.dart';
import 'token_service.dart';

import '../../core/constants/api_constants.dart';

class SubscriptionService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api/v1';
  final _tokenService = TokenService();

  Future<ApiResponse<List<CourseSubscription>>> getTeacherSubscriptions(
    int teacherId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/course-subscriptions/teacher/$teacherId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Get Teacher Subscriptions ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final List<dynamic> data = jsonResponse['data'] ?? [];

        // Debug: Print each item to see the structure
        for (var item in data) {
          print('Subscription item: $item');
        }

        final subscriptions = data
            .map((item) => CourseSubscription.fromJson(item))
            .toList();

        return ApiResponse<List<CourseSubscription>>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: subscriptions,
        );
      } else {
        return ApiResponse<List<CourseSubscription>>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch subscriptions',
        );
      }
    } catch (e) {
      print('Error fetching teacher subscriptions: $e');
      return ApiResponse<List<CourseSubscription>>(
        statusCode: 0,
        succeeded: false,
        message: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<List<CourseSubscription>>> getStudentSubscriptions(
    int studentId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/course-subscriptions/student/$studentId/status/Approved',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Get Student Subscriptions ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final List<dynamic> data = jsonResponse['data'] ?? [];

        final subscriptions = data
            .map((item) => CourseSubscription.fromJson(item))
            .toList();

        return ApiResponse<List<CourseSubscription>>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: subscriptions,
        );
      } else {
        return ApiResponse<List<CourseSubscription>>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch subscriptions',
          data: [], // Return empty list instead of null
        );
      }
    } catch (e) {
      print('Error fetching student subscriptions: $e');
      return ApiResponse<List<CourseSubscription>>(
        statusCode: 0,
        succeeded: false,
        message: 'Error: $e',
        data: [], // Return empty list instead of null
      );
    }
  }

  Future<ApiResponse<List<CourseSubscription>>> getStudentPendingSubscriptions(
    int studentId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/course-subscriptions/student/$studentId/status/Pending',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Get Student Pending Subscriptions ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final List<dynamic> data = jsonResponse['data'] ?? [];

        final subscriptions = data
            .map((item) => CourseSubscription.fromJson(item))
            .toList();

        return ApiResponse<List<CourseSubscription>>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: subscriptions,
        );
      } else {
        return ApiResponse<List<CourseSubscription>>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch pending subscriptions',
          data: [],
        );
      }
    } catch (e) {
      print('Error fetching student pending subscriptions: $e');
      return ApiResponse<List<CourseSubscription>>(
        statusCode: 0,
        succeeded: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }

  Future<ApiResponse<void>> updateSubscriptionStatus({
    required int subscriptionId,
    required String status, // "Approved" or "Rejected"
  }) async {
    try {
      final token = await _tokenService.getToken();
      final request = UpdateSubscriptionStatusRequest(
        id: subscriptionId,
        status: status,
      );

      final response = await http.put(
        Uri.parse('$baseUrl/course-subscriptions/status'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(request.toJson()),
      );

      print('--- Update Subscription Status ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Status updated successfully',
        );
      } else {
        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to update status',
        );
      }
    } catch (e) {
      print('Error updating subscription status: $e');
      return ApiResponse<void>(
        statusCode: 0,
        succeeded: false,
        message: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<bool>> checkStudentSubscriptionStatus({
    required int studentId,
    required int courseId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/course-subscriptions/student/$studentId/status/Approved',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Check Student Subscription ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final List<dynamic> data = jsonResponse['data'] ?? [];

        // Check if student has approved subscription for this course
        final hasApprovedSubscription = data.any(
          (item) =>
              item['courseId'] == courseId && item['status'] == 'Approved',
        );

        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: hasApprovedSubscription,
        );
      } else {
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to check subscription',
          data: false,
        );
      }
    } catch (e) {
      print('Error checking subscription status: $e');
      return ApiResponse<bool>(
        statusCode: 0,
        succeeded: false,
        message: 'Error: $e',
        data: false,
      );
    }
  }
}
