import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assistant_models.dart';
import '../models/api_response.dart';
import 'token_service.dart';

class AssistantService {
  static const String baseUrl = 'https://bosla-education.com/api';
  final _tokenService = TokenService();

  Future<ApiResponse<void>> registerAssistant(
    RegisterAssistantRequest request,
  ) async {
    try {
      final token = await _tokenService.getToken();

      print('--- Register Assistant ---');
      print('Request: ${request.toJson()}');

      final response = await http.post(
        Uri.parse('$baseUrl/RegisterAssistant'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(request.toJson()),
      );

      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);

        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'تم تسجيل المساعد بنجاح',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'فشل تسجيل المساعد',
        );
      }
    } catch (e) {
      print('Error registering assistant: $e');
      return ApiResponse<void>(
        statusCode: 0,
        succeeded: false,
        message: 'خطأ: $e',
      );
    }
  }

  Future<ApiResponse<List<Assistant>>> getTeacherAssistants(
    int teacherId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/ByTeacher/$teacherId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Get Teacher Assistants ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['succeeded'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final assistants = data
              .map((item) => Assistant.fromJson(item))
              .toList();

          return ApiResponse<List<Assistant>>(
            statusCode: response.statusCode,
            succeeded: true,
            message: jsonResponse['message'] ?? 'Successfully',
            data: assistants,
          );
        }
      }

      final jsonResponse = json.decode(response.body);
      return ApiResponse<List<Assistant>>(
        statusCode: response.statusCode,
        succeeded: false,
        message: jsonResponse['message'] ?? 'فشل جلب المساعدين',
        data: [],
      );
    } catch (e) {
      print('Error fetching assistants: $e');
      return ApiResponse<List<Assistant>>(
        statusCode: 0,
        succeeded: false,
        message: 'خطأ: $e',
        data: [],
      );
    }
  }

  Future<ApiResponse<void>> deleteAssistant(String userId) async {
    try {
      final token = await _tokenService.getToken();
      // Correct endpoint: https://www.bosla-education.com/DeleteUser/{userId}
      final url = 'https://www.bosla-education.com/api/DeleteUser/$userId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'accept': '*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Delete Assistant ---');
      print('URL: $url');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      // Success cases (200, 204 No Content)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        String message = 'تم حذف المساعد بنجاح';

        // Try to parse message from response if body is not empty
        if (response.body.isNotEmpty) {
          try {
            final jsonResponse = json.decode(response.body);
            message = jsonResponse['message'] ?? message;
          } catch (_) {
            // If parsing fails, use default message
          }
        }

        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: true,
          message: message,
        );
      } else {
        // Error cases
        String message = 'فشل حذف المساعد';

        // Try to parse error message if body is not empty
        if (response.body.isNotEmpty) {
          try {
            final jsonResponse = json.decode(response.body);
            message = jsonResponse['message'] ?? message;
          } catch (_) {
            // If parsing fails, use default message
          }
        }

        // Provide more specific error messages based on status code
        if (response.statusCode == 404) {
          message = 'المساعد غير موجود';
        } else if (response.statusCode == 403) {
          message = 'ليس لديك صلاحية لحذف هذا المساعد';
        }

        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: false,
          message: message,
        );
      }
    } catch (e) {
      print('Error deleting assistant: $e');
      return ApiResponse<void>(
        statusCode: 0,
        succeeded: false,
        message: 'خطأ: $e',
      );
    }
  }

  Future<ApiResponse<Assistant>> getAssistantByUserId(String userId) async {
    try {
      final token = await _tokenService.getToken();
      final response = await http.get(
        // Assuming this endpoint exists based on standard REST patterns
        // If this fails, we might need to ask for the correct endpoint
        Uri.parse('$baseUrl/api/v1/assistants/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Get Assistant By UserId ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['succeeded'] == true) {
          return ApiResponse<Assistant>(
            statusCode: response.statusCode,
            succeeded: true,
            message: jsonResponse['message'] ?? 'Successfully',
            data: Assistant.fromJson(jsonResponse['data']),
          );
        }
      }

      return ApiResponse<Assistant>(
        statusCode: response.statusCode,
        succeeded: false,
        message: 'Failed to fetch assistant details',
      );
    } catch (e) {
      print('Error fetching assistant details: $e');
      return ApiResponse<Assistant>(
        statusCode: 0,
        succeeded: false,
        message: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<void>> changeAssistantPassword({
    required String assistantUserId,
    required String newPassword,
    required String confirmPassword,
    String? newEmail,
  }) async {
    try {
      final token = await _tokenService.getToken();

      print('--- Change Assistant Password/Email ---');
      print('AssistantUserId: $assistantUserId');
      print('Token present: ${token != null}');

      final Map<String, dynamic> body = {
        'assistantUserId': assistantUserId,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      };

      if (newEmail != null && newEmail.isNotEmpty) {
        body['newEmail'] = newEmail;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/auth/change-assistant-password'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'تم تغيير كلمة المرور بنجاح',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<void>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'فشل تغيير كلمة المرور',
        );
      }
    } catch (e) {
      print('Error changing password: $e');
      return ApiResponse<void>(
        statusCode: 0,
        succeeded: false,
        message: 'خطأ: $e',
      );
    }
  }
}
