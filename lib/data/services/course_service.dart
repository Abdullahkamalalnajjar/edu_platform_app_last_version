import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/subscription_model.dart';
import '../models/course_models.dart';
import 'package:image_picker/image_picker.dart';
import 'token_service.dart';

class CourseService {
  final _tokenService = TokenService();

  Future<ApiResponse<List<CourseSubscription>>> getSubscriptionsByStatus(
    String status,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final studentId = await _tokenService.getUserId();

      if (studentId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User not authenticated',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url =
          '${ApiConstants.courseSubscriptions}/student/$studentId/status/$status';

      print('--- Get Subscriptions By Status ---');
      print('URL: $url');
      print('Status: $status');

      final response = await http.get(Uri.parse(url), headers: headers);
      final body = jsonDecode(response.body);

      print('Response from: $url');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (body['statusCode'] == 200) {
        final subscriptions = ApiResponse<List<CourseSubscription>>.fromJson(
          body,
          (data) => (data as List)
              .map((e) => CourseSubscription.fromJson(e))
              .toList(),
        );

        print('Parsed ${subscriptions.data?.length ?? 0} subscriptions');

        return subscriptions;
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch subscriptions',
        );
      }
    } catch (e) {
      print('Error in getSubscriptionsByStatus: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<int>> subscribeToCourse({required int courseId}) async {
    try {
      final token = await _tokenService.getToken();
      final studentId = await _tokenService.getUserId();

      print('--- Subscribe To Course Debug ---');
      print('StudentId from TokenService: $studentId');
      print('CourseId: $courseId');

      if (studentId == null) {
        print('Error: User ID is null. Cannot subscribe.');
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User not authenticated',
        );
      }

      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = {'studentId': studentId, 'courseId': courseId};
      print('Request Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConstants.courseSubscriptions),
        headers: headers,
        body: jsonEncode(body),
      );

      print(
        '--- Subscribe Response from ${ApiConstants.courseSubscriptions} ---',
      );
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('--------------------------');

      final responseBody = jsonDecode(response.body);

      if (responseBody['statusCode'] == 200) {
        return ApiResponse<int>.fromJson(responseBody, (data) => data as int);
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to subscribe',
        );
      }
    } catch (e) {
      print('Exception in subscribeToCourse: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getCoursesByTeacher(
    int teacherId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = '${ApiConstants.baseUrl}/api/v1/courses/teacher/$teacherId';
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل استرداد الدورات (رد فارغ)',
        );
      }
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
          message: body['message'] ?? 'Failed to fetch courses',
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

  Future<ApiResponse<List<Exam>>> getExamByLectureId(int lectureId) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getLectureExam(lectureId);
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل استرداد الامتحانات (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<List<Exam>>.fromJson(
          body,
          (data) => (data as List).map((e) => Exam.fromJson(e)).toList(),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch exams',
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

  /// Get exam by exam ID (for notification navigation)
  Future<ApiResponse<Exam>> getExamById(int examId) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getExamById(examId);
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل استرداد الامتحان (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<Exam>.fromJson(body, (data) => Exam.fromJson(data));
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch exam',
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

  /// Get lecture by ID
  Future<ApiResponse<Lecture>> getLectureById(int lectureId) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = '${ApiConstants.lectures}/$lectureId';
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل استرداد المحاضرة (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        // The API returns simple object: { id, title, courseId, ... }
        // Our Lecture model expects 'materials' list usually, but let's see.
        // If materials are missing, it defaults to empty list.
        return ApiResponse<Lecture>.fromJson(
          body,
          (data) => Lecture.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch lecture',
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

  /// Get course by ID
  Future<ApiResponse<Course>> getCourseById(int courseId) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getCourseById(courseId);
      print('═══════════════════════════════════════════');
      print('📡 GET COURSE BY ID REQUEST');
      print('URL: $url');
      print('═══════════════════════════════════════════');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('📥 GET COURSE RESPONSE');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('═══════════════════════════════════════════');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل استرداد الكورس (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<Course>.fromJson(
          body,
          (data) => Course.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch course',
        );
      }
    } catch (e) {
      print('Error fetching course: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Check if student can access exam (checks for deadline exceptions)
  Future<ApiResponse<ExamAccessResponse>> checkExamAccess({
    required int examId,
    int? studentId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final effectiveStudentId = studentId ?? await _tokenService.getUserId();

      if (effectiveStudentId == null) {
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

      final url = ApiConstants.checkExamAccess(examId, effectiveStudentId);

      print('--- Check Exam Access Request ---');
      print('URL: $url');
      print('----------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Check Exam Access Response from $url ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-----------------------------------');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل التحقق من الوصول (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<ExamAccessResponse>.fromJson(
          body,
          (data) => ExamAccessResponse.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to check exam access',
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

  Future<ApiResponse<double>> submitExam(ExamSubmissionRequest request) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      print('--- Submit Exam Request ---');
      print('URL: ${ApiConstants.baseUrl}/api/v1/exams/submit');
      print('Payload: ${jsonEncode(request.toJson())}');
      print('---------------------------');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/exams/submit'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل تسليم الامتحان (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);
      print(
        '--- Submit Exam Response from ${ApiConstants.baseUrl}/api/v1/exams/submit ---',
      );
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('----------------------------');

      if (body['succeeded'] == true) {
        return ApiResponse<double>.fromJson(
          body,
          (data) => (data != null) ? (data as num).toDouble() : 0.0,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to submit exam',
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

  Future<ApiResponse<StudentExamResult>> getStudentExamResult(
    int examId, {
    int? studentId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final effectiveStudentId = studentId ?? await _tokenService.getUserId();

      if (effectiveStudentId == null) {
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

      final url =
          '${ApiConstants.baseUrl}/api/v1/exams/$examId/students/$effectiveStudentId/score';
      print('--- Get Student Result Request ---');
      print('URL: $url');
      print('----------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Get Student Result Response from $url ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-----------------------------------');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل استرداد النتيجة من الخادم (رد فارغ)',
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
          message: body['message'] ?? 'Failed to fetch exam result',
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

  Future<ApiResponse<List<ExamSubmission>>> getExamSubmissions(
    int lectureId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getExamSubmissions(lectureId);
      final response = await http.get(Uri.parse(url), headers: headers);
      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse<List<ExamSubmission>>.fromJson(
          body,
          (data) =>
              (data as List).map((e) => ExamSubmission.fromJson(e)).toList(),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch exam submissions',
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

  Future<ApiResponse<List<ExamSubmission>>> getExamSubmissionsByExamId(
    int examId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getSubmissionsByExamId(examId);
      final response = await http.get(Uri.parse(url), headers: headers);
      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        final dataList = body['data'] as List;
        for (var item in dataList) {
          print('📋 Raw submission: gradedByName=${item['gradedByName']}, studentName=${item['studentName']}');
        }
        return ApiResponse<List<ExamSubmission>>.fromJson(
          body,
          (data) =>
              (data as List).map((e) => ExamSubmission.fromJson(e)).toList(),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch exam submissions',
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

  Future<ApiResponse<NonSubmittedStudentsResponse>> getNonSubmittedStudents({
    required int examId,
    required int courseId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = ApiConstants.getNonSubmittedStudents(examId, courseId);
      final response = await http.get(Uri.parse(url), headers: headers);
      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse<NonSubmittedStudentsResponse>.fromJson(
          body,
          (data) => NonSubmittedStudentsResponse.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch non-submitted students',
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

  Future<ApiResponse<GradeExamResponse>> gradeExam(
    GradeExamRequest request,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      print('--- Grade Exam Request ---');
      print('URL: ${ApiConstants.gradeExam}');
      print('Payload: ${jsonEncode(request.toJson())}');
      print('--------------------------');

      final response = await http.post(
        Uri.parse(ApiConstants.gradeExam),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      print('--- Grade Exam Response from ${ApiConstants.gradeExam} ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل تصحيح الامتحان (رد فارغ)',
        );
      }
      final body = jsonDecode(response.body);

      if (body['succeeded'] == true) {
        return ApiResponse<GradeExamResponse>.fromJson(
          body,
          (data) => GradeExamResponse.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to grade exam',
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

  Future<ApiResponse<int>> startExam({
    required int examId,
    required int studentId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = {'examId': examId, 'studentId': studentId};
      final url = ApiConstants.startExamUrl(examId);

      print('--- Start Exam Request ---');
      print('URL: $url');
      print('Payload: ${jsonEncode(body)}');
      print('--------------------------');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      print('--- Start Exam Response from $url ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------');

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'فشل بدء الامتحان (رد فارغ) - رمز: ${response.statusCode}',
        );
      }
      final responseBody = jsonDecode(response.body);

      if (responseBody['statusCode'] == 200 ||
          responseBody['statusCode'] == 201) {
        return ApiResponse<int>.fromJson(
          responseBody,
          (data) => (data is int) ? data : (data as Map)['id'],
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to start exam',
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

  Future<ApiResponse<String>> uploadStudentImageAnswer({
    required int examId,
    required int studentId,
    required int questionId,
    required XFile image,
    int? studentExamResultId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.studentAnswersImage);

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['ExamId'] = examId.toString();
      request.fields['StudentId'] = studentId.toString();
      request.fields['QuestionId'] = questionId.toString();
      request.fields['StudentExamResultId'] = (studentExamResultId ?? 0)
          .toString();

      final bytes = await image.readAsBytes();
      String mimeType = image.mimeType ?? _getMimeType(image.name);
      if (mimeType == 'application/octet-stream') {
        mimeType = 'image/jpeg';
      }

      String fileName = image.name;
      if (!fileName.contains('.')) {
        fileName += '.jpg';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'ImageFile',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      print(
        'Uploading Answer Image: ${image.name} to ${ApiConstants.studentAnswersImage}',
      );
      print('Payload: ${request.fields}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
        'Upload Answer Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // The data field usually contains the ID or URL.
        return ApiResponse<String>.fromJson(body, (data) => data.toString());
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to upload image',
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<StudentCourseScore>> getStudentCourseScore({
    required int courseId,
    required int studentId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final headers = {
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url =
          '${ApiConstants.baseUrl}/api/v1/exams/courses/$courseId/students/$studentId/total-score';

      print('--- Get Student Course Score Request ---');
      print('URL: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 404) {
        return ApiResponse(
          statusCode: 404,
          succeeded: false,
          message: 'No exams found for this course',
        );
      }

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Empty response',
        );
      }

      final body = jsonDecode(response.body);

      if (body['statusCode'] == 200) {
        return ApiResponse<StudentCourseScore>.fromJson(
          body,
          (data) => StudentCourseScore.fromJson(data),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch course score',
        );
      }
    } catch (e) {
      print('Error fetching student course score: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}
