import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/subject_model.dart';
import 'token_service.dart';

class SubjectService {
  final _tokenService = TokenService();

  Future<ApiResponse<List<Subject>>> getSubjects() async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse(ApiConstants.subjects),
        headers: headers,
      );

      final body = jsonDecode(response.body);

      // Check if the response matches ApiResponse structure
      if (body['statusCode'] != null) {
        return ApiResponse<List<Subject>>.fromJson(
          body,
          (data) => (data as List).map((e) => Subject.fromJson(e)).toList(),
        );
      } else {
        // Fallback if needed or explicit error handling
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Unexpected response format',
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

  Future<ApiResponse<List<Map<String, dynamic>>>> getTeachersByEducationStage(
    int educationStageId,
    int subjectId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url =
          '${ApiConstants.baseUrl}/api/v1/teachers/by-education-stage/$educationStageId/$subjectId';
      final response = await http.get(Uri.parse(url), headers: headers);

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<List<Map<String, dynamic>>>.fromJson(
          body,
          (data) => List<Map<String, dynamic>>.from(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Unknown error',
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

  /// Fetches teachers for a specific subject
  /// API: GET /api/v1/subjects/{subjectId}/teachers
  /// Response data is an array: [{ id, name, subjectImageUrl, teachers: [...] }]
  Future<ApiResponse<List<Map<String, dynamic>>>> getTeachersBySubject(
    int subjectId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = '${ApiConstants.baseUrl}/api/v1/subjects/$subjectId/teachers';
      final response = await http.get(Uri.parse(url), headers: headers);

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        // data is an array containing subject info with teachers
        final dataList = body['data'] as List? ?? [];

        // Extract teachers from all subjects in the response
        List<Map<String, dynamic>> allTeachers = [];
        for (var subjectData in dataList) {
          final teachers = subjectData['teachers'] as List? ?? [];
          for (var teacher in teachers) {
            allTeachers.add(Map<String, dynamic>.from(teacher));
          }
        }

        return ApiResponse<List<Map<String, dynamic>>>(
          statusCode: 200,
          succeeded: true,
          message: body['message'] ?? 'Success',
          data: allTeachers,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Unknown error',
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

  Future<ApiResponse<List<Map<String, dynamic>>>> getEducationStages() async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = '${ApiConstants.baseUrl}/api/v1/education-stages';
      final response = await http.get(Uri.parse(url), headers: headers);

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<List<Map<String, dynamic>>>.fromJson(
          body,
          (data) => List<Map<String, dynamic>>.from(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Unknown error',
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

  /// Create a new subject
  /// API: POST /api/v1/subjects (multipart/form-data)
  Future<ApiResponse<Subject>> createSubject({
    required String name,
    String? imagePath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'غير مصرح لك، يُرجى تسجيل الدخول',
        );
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.subjects),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['Name'] = name;

      if (imagePath != null && imagePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('SubjectImageFile', imagePath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Create subject response: ${response.statusCode}');
      print('Create subject body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['succeeded'] == true) {
          // Check if data is a Map (full object) or just an ID
          if (body['data'] != null && body['data'] is Map<String, dynamic>) {
            return ApiResponse<Subject>(
              statusCode: 200,
              succeeded: true,
              message: body['message'] ?? 'تم إنشاء المادة بنجاح',
              data: Subject.fromJson(body['data']),
            );
          }
          // If data is just an ID, return success without data
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message: body['message'] ?? 'تم إنشاء المادة بنجاح',
          );
        }
        return ApiResponse(
          statusCode: 200,
          succeeded: false,
          message: body['message'] ?? 'فشل في إنشاء المادة',
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في إنشاء المادة',
        );
      }
    } catch (e) {
      print('Error in createSubject: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Update an existing subject
  /// API: PUT /api/v1/subjects/Edit (multipart/form-data)
  Future<ApiResponse<Subject>> updateSubject({
    required int id,
    required String name,
    String? imagePath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'غير مصرح لك، يُرجى تسجيل الدخول',
        );
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConstants.editSubject),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['Id'] = id.toString();
      request.fields['Name'] = name;

      if (imagePath != null && imagePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('SubjectImageFile', imagePath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Update subject response: ${response.statusCode}');
      print('Update subject body: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['succeeded'] == true) {
          // Check if data is a Map (full object) or just an ID
          if (body['data'] != null && body['data'] is Map<String, dynamic>) {
            return ApiResponse<Subject>(
              statusCode: 200,
              succeeded: true,
              message: body['message'] ?? 'تم تحديث المادة بنجاح',
              data: Subject.fromJson(body['data']),
            );
          }
          // If data is just an ID, return success without data
          return ApiResponse(
            statusCode: 200,
            succeeded: true,
            message: body['message'] ?? 'تم تحديث المادة بنجاح',
          );
        }
        return ApiResponse(
          statusCode: 200,
          succeeded: false,
          message: body['message'] ?? 'فشل في تحديث المادة',
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في تحديث المادة',
        );
      }
    } catch (e) {
      print('Error in updateSubject: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Delete a subject
  /// API: DELETE /api/v1/subjects/{id}
  Future<ApiResponse<void>> deleteSubject(int id) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'غير مصرح لك، يُرجى تسجيل الدخول',
        );
      }

      final response = await http.delete(
        Uri.parse(ApiConstants.deleteSubject(id)),
        headers: {...ApiConstants.headers, 'Authorization': 'Bearer $token'},
      );

      print('Delete subject response: ${response.statusCode}');
      print('Delete subject body: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(
          statusCode: 200,
          succeeded: true,
          message: body['message'] ?? 'تم حذف المادة بنجاح',
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في حذف المادة',
        );
      }
    } catch (e) {
      print('Error in deleteSubject: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Get a subject by ID
  /// API: GET /api/v1/subjects/{id}
  Future<ApiResponse<Subject>> getSubjectById(int id) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse(ApiConstants.getSubjectById(id)),
        headers: headers,
      );

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200 && body['data'] != null) {
        return ApiResponse<Subject>(
          statusCode: 200,
          succeeded: true,
          message: body['message'] ?? 'Success',
          data: Subject.fromJson(body['data']),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'فشل في تحميل المادة',
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
