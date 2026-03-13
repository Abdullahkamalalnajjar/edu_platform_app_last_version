import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import 'token_service.dart';

class StudentService {
  final TokenService _tokenService = TokenService();

  Future<ApiResponse<bool>> createProfile({
    required int
    studentId, // Keeping standard fields but checking payload from user logs
    required int gradeYear,
    required String studentPhoneNumber,
    required String parentPhoneNumber,
    required String governorate,
    required String city,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Based on user log: "{userId: string, gradeYear: 0, studentPhoneNumber...}"
      // It seems to expect "userId" string (GUID?) or maybe the int StudentId?
      // But the path is /students/create-profile.
      // Let's assume the payload matches updateProfile but points to create-profile.

      final body = {
        'userId':
            (await _tokenService.getUserGuid()) ??
            '', // Assuming it needs GUID based on "userId: string" in log
        'gradeYear': gradeYear,
        'studentPhoneNumber': studentPhoneNumber,
        'parentPhoneNumber': parentPhoneNumber,
        'governorate': governorate,
        'city': city,
      };

      print('Creating Student Profile: $body');

      final response = await http.post(
        Uri.parse(ApiConstants.createStudentProfile),
        headers: headers,
        body: jsonEncode(body),
      );

      print('Create Profile Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: true,
          message: 'Profile created successfully',
          data: true,
        );
      } else {
        dynamic responseBody;
        try {
          responseBody = jsonDecode(response.body);
        } catch (_) {
          responseBody = {'message': response.body};
        }
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to create profile',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> updateProfile({
    required String studentId,
    required int gradeYear,
    required String studentPhoneNumber,
    required String parentPhoneNumber,
    required String governorate,
    required String city,
    String? profileImagePath, // Optional image path
  }) async {
    try {
      final token = await _tokenService.getToken();

      // Create multipart request
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConstants.updateStudentProfile),
      );

      // Add headers
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add form fields
      request.fields['StudentId'] = studentId;
      final userGuid = await _tokenService.getUserGuid();
      if (userGuid != null) {
        request.fields['UserId'] = userGuid;
      }
      request.fields['StudentPhoneNumber'] = studentPhoneNumber;
      request.fields['ParentPhoneNumber'] = parentPhoneNumber;
      request.fields['Governorate'] = governorate;
      request.fields['City'] = city;

      // Add image file if provided
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        var imageFile = await http.MultipartFile.fromPath(
          'StudentProfileImageFile',
          profileImagePath,
        );
        request.files.add(imageFile);
      }

      print('Updating Profile with fields: ${request.fields}');
      if (profileImagePath != null) {
        print('Including profile image: $profileImagePath');
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Update Profile Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: true,
          message: 'Profile updated successfully',
          data: true,
        );
      } else {
        dynamic responseBody;
        try {
          responseBody = jsonDecode(response.body);
        } catch (_) {
          responseBody = {'message': response.body};
        }

        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to update profile',
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getProfile() async {
    try {
      final token = await _tokenService.getToken();
      final userGuid = await _tokenService.getUserGuid();

      if (userGuid == null || userGuid.isEmpty) {
        return ApiResponse(
          statusCode: 400,
          succeeded: false,
          message: 'User GUID not found',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(ApiConstants.getStudentProfile(userGuid));

      print('Fetching Student Profile: $uri');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      print('Get Profile Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // The API returns: { statusCode, succeeded, message, data: {...} }
        if (jsonResponse['succeeded'] == true && jsonResponse['data'] != null) {
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message:
                jsonResponse['message'] ?? 'Profile retrieved successfully',
            data: jsonResponse['data'] as Map<String, dynamic>,
          );
        } else {
          return ApiResponse(
            statusCode: response.statusCode,
            succeeded: false,
            message: jsonResponse['message'] ?? 'Failed to get profile',
          );
        }
      } else {
        dynamic responseBody;
        try {
          responseBody = jsonDecode(response.body);
        } catch (_) {
          responseBody = {'message': response.body};
        }

        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to get profile',
        );
      }
    } catch (e) {
      print('Error getting profile: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }
}
