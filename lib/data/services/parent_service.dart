import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/parent_models.dart';
import '../models/course_models.dart';
import 'token_service.dart';

class ParentService {
  final _tokenService = TokenService();

  Future<ApiResponse<List<ParentStudent>>> getMyStudents() async {
    try {
      final token = await _tokenService.getToken();
      final userId = await _tokenService.getUserId();

      if (userId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User ID not found',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getMyStudents(userId);
      print('Fetching MyStudents from: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('MyStudents Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Empty response',
        );
      }

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<List<ParentStudent>>.fromJson(
          body,
          (data) =>
              (data as List).map((e) => ParentStudent.fromJson(e)).toList(),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch students',
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

  /// Get exam scores for a specific student and course
  Future<ApiResponse<List<StudentExamScore>>> getStudentCourseExams(
    int studentId,
    int courseId,
  ) async {
    try {
      final token = await _tokenService.getToken();

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url =
          '${ApiConstants.baseUrl}/Student/$studentId/Course/$courseId/ExamScores';
      print('Fetching student course exams from: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Student Course Exams Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Empty response',
        );
      }

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<List<StudentExamScore>>.fromJson(
          body,
          (data) =>
              (data as List).map((e) => StudentExamScore.fromJson(e)).toList(),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch exam scores',
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

  /// Get detailed exam result for a specific student and exam
  Future<ApiResponse<StudentExamResult>> getStudentExamResult(
    int examId,
    int studentId,
  ) async {
    try {
      final token = await _tokenService.getToken();

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url =
          '${ApiConstants.baseUrl}/api/v1/exams/$examId/students/$studentId/score';
      print('Fetching student exam result from: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Student Exam Result Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Empty response',
        );
      }

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<StudentExamResult>.fromJson(
          body,
          (data) => StudentExamResult.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch exam details',
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
}
