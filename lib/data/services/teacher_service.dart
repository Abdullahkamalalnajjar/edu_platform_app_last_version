import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/course_models.dart';
import '../models/teacher_revenue_model.dart';
import 'token_service.dart';

class TeacherService {
  final _tokenService = TokenService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenService.getToken();
    return {...ApiConstants.headers, 'Authorization': 'Bearer $token'};
  }

  Future<ApiResponse<Map<String, dynamic>>> getProfileByGuid(
    String guid,
  ) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/v1/teachers/profile/$guid',
      );

      print('--- Get Teacher Profile By GUID ---');
      print('URL: $uri');

      final response = await http.get(uri, headers: headers);

      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          body,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse(
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch profile',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('Error getting profile by GUID: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<bool>> createProfile({
    required String userId,
    required String phoneNumber,
    required String governorate,
    required String city,
    required int subjectId,
    String? facebookUrl,
    String? telegramUrl,
    String? whatsAppNumber,
    String? youTubeChannelUrl,
    List<int>? educationStageIds,
    String? photoPath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.createTeacherProfile);
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      });
      request.headers.remove('Content-Type');

      // Add fields
      request.fields['UserId'] = userId;
      request.fields['PhoneNumber'] = phoneNumber;
      request.fields['Governorate'] = governorate;
      request.fields['City'] = city;
      request.fields['SubjectId'] = subjectId.toString();

      if (facebookUrl != null && facebookUrl.isNotEmpty) {
        request.fields['FacebookUrl'] = facebookUrl;
      }
      if (telegramUrl != null && telegramUrl.isNotEmpty) {
        request.fields['TelegramUrl'] = telegramUrl;
      }
      if (whatsAppNumber != null && whatsAppNumber.isNotEmpty) {
        request.fields['WhatsAppNumber'] = whatsAppNumber;
      }
      if (youTubeChannelUrl != null && youTubeChannelUrl.isNotEmpty) {
        request.fields['YouTubeChannelUrl'] = youTubeChannelUrl;
      }

      if (educationStageIds != null && educationStageIds.isNotEmpty) {
        for (var id in educationStageIds) {
          request.files.add(
            http.MultipartFile.fromString('EducationStageIds', id.toString()),
          );
        }
      } else {
        // Send a 0 or empty list if needed?
        request.files.add(
          http.MultipartFile.fromString('EducationStageIds', '0'),
        );
      }

      if (photoPath != null && photoPath.isNotEmpty) {
        final fileName = photoPath.split('/').last;
        final mimeType = _getMimeType(fileName);
        request.files.add(
          await http.MultipartFile.fromPath(
            'PhotoFile',
            photoPath,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print('--- Create Teacher Profile Request ---');
      print('URL: $uri');
      print('Fields: ${request.fields}');
      if (photoPath != null) print('Photo: $photoPath');
      print('------------------------------------');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Create Teacher Profile Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'تم إنشاء الملف الشخصي بنجاح',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      print('Error creating teacher profile: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  Future<ApiResponse<bool>> updateProfile({
    required int teacherId,
    required String phoneNumber,
    required String governorate,
    required String city,
    required int subjectId,
    String? firstName,
    String? lastName,
    String? facebookUrl,
    String? telegramUrl,
    String? whatsAppNumber,
    String? youTubeChannelUrl,
    List<int>? educationStageIds,
    String? photoPath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.updateTeacherProfile);
      final request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({
        ...ApiConstants.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      });
      // Remove Content-Type to let MultipartRequest set it with boundary
      request.headers.remove('Content-Type');

      // Add fields
      request.fields['TeacherId'] = teacherId.toString();
      request.fields['SubjectId'] = subjectId.toString();
      request.fields['PhoneNumber'] = phoneNumber;
      request.fields['Governorate'] = governorate;
      request.fields['City'] = city;

      if (firstName != null && firstName.isNotEmpty) {
        request.fields['FirstName'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        request.fields['LastName'] = lastName;
      }

      if (facebookUrl != null && facebookUrl.isNotEmpty) {
        request.fields['FacebookUrl'] = facebookUrl;
      }
      if (telegramUrl != null && telegramUrl.isNotEmpty) {
        request.fields['TelegramUrl'] = telegramUrl;
      }
      if (whatsAppNumber != null && whatsAppNumber.isNotEmpty) {
        request.fields['WhatsAppNumber'] = whatsAppNumber;
      }
      if (youTubeChannelUrl != null && youTubeChannelUrl.isNotEmpty) {
        request.fields['YouTubeChannelUrl'] = youTubeChannelUrl;
      }

      // Add EducationStageIds
      if (educationStageIds != null && educationStageIds.isNotEmpty) {
        for (var id in educationStageIds) {
          // Binding often requires repeating the key for lists in specific multipart handlers,
          // checking backend style from screenshot where it says "EducationStageIds array".
          // Standard http client for list often is same key multiple times.
          request.files.add(
            http.MultipartFile.fromString('EducationStageIds', id.toString()),
          );
        }
      }

      // Add Photo
      if (photoPath != null && photoPath.isNotEmpty) {
        final fileName = photoPath.split('/').last;
        final mimeType = _getMimeType(fileName);
        request.files.add(
          await http.MultipartFile.fromPath(
            'PhotoFile',
            photoPath,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print('--- Update Teacher Profile Request ---');
      print('URL: $uri');
      print('Fields: ${request.fields}');
      if (photoPath != null) print('Photo: $photoPath');
      print('------------------------------------');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Update Teacher Profile Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'تم تحديث الملف الشخصي بنجاح',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      print('Error updating teacher profile: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  Future<ApiResponse<int>> createCourse(CourseRequest request) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.courses);

      final multipartRequest = http.MultipartRequest('POST', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      // Add fields
      multipartRequest.fields.addAll(request.toFields());

      print('--- Create Course Request ---');
      print('URL: ${ApiConstants.courses}');
      print('Fields: ${request.toFields()}');
      print('Image: ${request.imagePath}');
      print('-----------------------------');

      // Add image if present
      if (request.imagePath != null) {
        final fileName = request.imagePath!.split('\\').last.split('/').last;
        final mimeType = _getMimeType(fileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'CourseImageUrl', // Matches Swagger parameter name
            request.imagePath!,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Create Course Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<int>> createLecture(
    LectureRequest request, {
    String? coverImagePath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.lectures);
      final multipartRequest = http.MultipartRequest('POST', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      multipartRequest.fields['title'] = request.title;
      multipartRequest.fields['courseId'] = request.courseId.toString();

      if (coverImagePath != null) {
        final coverFileName =
            coverImagePath.split('\\').last.split('/').last;
        final mimeType = _getMimeType(coverFileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'coverImage',
            coverImagePath,
            filename: coverFileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print('Creating lecture with fields: ${multipartRequest.fields}');
      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);
      print('Create Lecture Response: ${response.statusCode} ${response.body}');

      final body = jsonDecode(response.body);
      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<List<Course>>> getTeacherCourses(int teacherId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.courses}/teacher/$teacherId';
      print('═══════════════════════════════════════════');
      print('📡 GET TEACHER COURSES REQUEST');
      print('URL: $url');
      print('═══════════════════════════════════════════');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('📥 GET TEACHER COURSES RESPONSE');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('═══════════════════════════════════════════');

      final body = jsonDecode(response.body);
      return ApiResponse<List<Course>>.fromJson(
        body,
        (data) => (data as List).map((e) => Course.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Add material to a lecture (Video with URL only)
  Future<ApiResponse<int>> createMaterial(MaterialRequest request,
      {String? coverImagePath}) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.materials);

      final multipartRequest = http.MultipartRequest('POST', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      multipartRequest.fields['type'] = request.type;
      multipartRequest.fields['lectureId'] = request.lectureId.toString();
      multipartRequest.fields['isFree'] = request.isFree.toString();
      if (request.title != null) {
        multipartRequest.fields['title'] = request.title!;
      }
      if (request.videoUrl != null) {
        multipartRequest.fields['videoUrl'] = request.videoUrl!;
      }
      // Optional cover image
      if (coverImagePath != null) {
        final coverFileName = coverImagePath.split('\\').last.split('/').last;
        final mimeType = _getMimeType(coverFileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'coverImage',
            coverImagePath,
            filename: coverFileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print(
        'Creating material (multipart) with fields: ${multipartRequest.fields}',
      );

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Create Material Response Status: ${response.statusCode}');
      print('Create Material Response Body: ${response.body}');

      final body = jsonDecode(response.body);
      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      print('Create Material Error: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Add material with file upload (PDF, Image, Homework)
  Future<ApiResponse<int>> createMaterialWithFile({
    required String type,
    required int lectureId,
    required String filePath,
    required String fileName,
    required bool isFree,
    String? title,
    String? coverImagePath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.materials);

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['type'] = type;
      request.fields['lectureId'] = lectureId.toString();
      request.fields['isFree'] = isFree.toString();
      if (title != null) {
        request.fields['title'] = title;
      }

      print(
        'Uploading file material: Type=$type, LectureID=$lectureId, File=$fileName',
      );

      // Add main file
      final mimeType = _getMimeType(fileName);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Optional cover image
      if (coverImagePath != null) {
        final coverFileName = coverImagePath.split('\\').last.split('/').last;
        final coverMimeType = _getMimeType(coverFileName);
        request.files.add(
          await http.MultipartFile.fromPath(
            'coverImage',
            coverImagePath,
            filename: coverFileName,
            contentType: MediaType.parse(coverMimeType),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Upload Material Response Status: ${response.statusCode}');
      print('Upload Material Response Body: ${response.body}');

      final body = jsonDecode(response.body);

      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      print('Upload Material Error: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> deleteCourse(int courseId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.courses}/$courseId'),
        headers: headers,
      );

      if (response.body.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            succeeded: true,
            message: 'Deleted successfully',
            data: true,
            statusCode: response.statusCode,
          );
        }
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> updateCourse(
    CourseRequest request,
    int courseId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse('${ApiConstants.courses}/Edit');

      final multipartRequest = http.MultipartRequest('PUT', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      // Add fields
      final fields = request.toFields();
      fields['Id'] = courseId.toString(); // Add ID for update
      multipartRequest.fields.addAll(fields);

      print('--- Update Course Request ---');
      print('URL: $uri');
      print('Fields: $fields');
      print('Image: ${request.imagePath}');
      print('-----------------------------');

      // Add image if present
      if (request.imagePath != null) {
        final fileName = request.imagePath!.split('\\').last.split('/').last;
        final mimeType = _getMimeType(fileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'CourseImageUrl',
            request.imagePath!,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Update Course Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Updated successfully',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> reorderCourses(
      int teacherId, List<int> orderedCourseIds) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'teacherId': teacherId,
        'orderedCourseIds': orderedCourseIds,
      };

      print('--- Reorder Courses Request ---');
      print('URL: ${ApiConstants.courses}/reorder');
      print('Payload: $body');
      print('---------------------------------');

      final response = await http.post(
        Uri.parse('${ApiConstants.courses}/reorder'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('--- Reorder Courses Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResponse(
            succeeded: true,
            data: true,
            statusCode: response.statusCode,
            message: 'تم إعادة الترتيب بنجاح',
          );
        }
        final bodyData = jsonDecode(response.body);
        return ApiResponse<bool>.fromJson(bodyData, (data) => true);
      } else {
        final bodyData =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        if (response.statusCode == 401) {
          return ApiResponse(
            succeeded: false,
            statusCode: response.statusCode,
            message: bodyData['message'] ??
                'أنتهت صلاحية الجلسة يرجي تسجيل الخروج وتسجيل الدخول مرة أخرة',
          );
        }
        return ApiResponse(
          succeeded: false,
          statusCode: response.statusCode,
          message: bodyData['message'] ?? 'Failed to reorder courses',
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

  Future<ApiResponse<bool>> deleteLecture(int lectureId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.lectures}/$lectureId'),
        headers: headers,
      );

      if (response.body.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            succeeded: true,
            message: 'Deleted successfully',
            data: true,
            statusCode: response.statusCode,
          );
        }
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> updateLecture(
    LectureRequest request,
    int lectureId, {
    String? coverImagePath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse('${ApiConstants.lectures}/Edit');
      final multipartRequest = http.MultipartRequest('PUT', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      multipartRequest.fields['id'] = lectureId.toString();
      multipartRequest.fields['title'] = request.title;
      multipartRequest.fields['courseId'] = request.courseId.toString();

      if (coverImagePath != null) {
        final coverFileName =
            coverImagePath.split('\\').last.split('/').last;
        final mimeType = _getMimeType(coverFileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'coverImage',
            coverImagePath,
            filename: coverFileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print('Updating lecture $lectureId fields: ${multipartRequest.fields}');
      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);
      print('Update Lecture Response: ${response.statusCode} ${response.body}');

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> reorderLectures(
      int courseId, List<int> orderedLectureIds) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'courseId': courseId,
        'orderedLectureIds': orderedLectureIds,
      };

      print('--- Reorder Lectures Request ---');
      print('URL: ${ApiConstants.lectures}/reorder');
      print('Payload: $body');
      print('---------------------------------');

      final response = await http.post(
        Uri.parse('${ApiConstants.lectures}/reorder'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('--- Reorder Lectures Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResponse(
            succeeded: true,
            data: true,
            statusCode: response.statusCode,
            message: 'تم إعادة الترتيب بنجاح',
          );
        }
        final bodyData = jsonDecode(response.body);
        return ApiResponse<bool>.fromJson(bodyData, (data) => true);
      } else {
        final bodyData =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        // Specific error handling for 401
        if (response.statusCode == 401) {
          return ApiResponse(
            succeeded: false,
            statusCode: response.statusCode,
            message: bodyData['message'] ??
                'أنتهت صلاحية الجلسة يرجي تسجيل الخروج وتسجيل الدخول مرة أخرة',
          );
        }
        return ApiResponse(
          succeeded: false,
          statusCode: response.statusCode,
          message: bodyData['message'] ?? 'Failed to reorder lectures',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ أثناء الترتيب: $e',
      );
    }
  }

  Future<ApiResponse<bool>> reorderMaterials(
      int lectureId, List<int> orderedMaterialIds) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'lectureId': lectureId,
        'orderedMaterialIds': orderedMaterialIds,
      };

      print('--- Reorder Materials Request ---');
      print('URL: ${ApiConstants.lectures}/materials/reorder');
      print('Payload: $body');
      print('---------------------------------');

      final response = await http.post(
        Uri.parse('${ApiConstants.lectures}/materials/reorder'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('--- Reorder Materials Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResponse(
            succeeded: true,
            data: true,
            statusCode: response.statusCode,
            message: 'تم إعادة الترتيب بنجاح',
          );
        }
        final bodyData = jsonDecode(response.body);
        return ApiResponse<bool>.fromJson(bodyData, (data) => true);
      } else {
        final bodyData =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        if (response.statusCode == 401) {
          return ApiResponse(
            succeeded: false,
            statusCode: response.statusCode,
            message: bodyData['message'] ??
                'أنتهت صلاحية الجلسة يرجي تسجيل الخروج وتسجيل الدخول مرة أخرة',
          );
        }
        return ApiResponse(
          succeeded: false,
          statusCode: response.statusCode,
          message: bodyData['message'] ?? 'Failed to reorder materials',
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ أثناء الترتيب: $e',
      );
    }
  }

  Future<ApiResponse<bool>> deleteMaterial(int materialId) async {
    try {
      final headers = await _getHeaders();
      // User request: http://edu-platform.runasp.net/api/v1/lectures/{id}/materials
      // NOTE: This typically implies {id} is the lecture ID, but since we are deleting a specific material,
      // and checking the user prompt "api/v1/lectures/99/materials for delete",
      // it suggests the backend might be using this path to delete material #99?
      // OR it is actually /lectures/{lectureId}/materials/{materialId}?
      // Since I only have materialId here, and user passed "99" (likely material ID) in example,
      // I will construct exactly what was asked: .../lectures/99/materials

      final response = await http.delete(
        Uri.parse('${ApiConstants.lectures}/$materialId/materials'),
        headers: headers,
      );

      if (response.body.isEmpty) {
        // Handle empty response (likely success 204)
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            succeeded: true,
            message: 'Deleted successfully',
            data: true,
            statusCode: response.statusCode,
          );
        }
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<int>> createExam(ExamRequest request) async {
    try {
      final headers = await _getHeaders();
      final payload = jsonEncode(request.toJson());

      print('--- Create Exam Request ---');
      print('URL: ${ApiConstants.exams}');
      print('Headers: $headers');
      print('FIXED_PAYLOAD: $payload'); // Added prefix for visibility
      print('--------------------------');

      final response = await http.post(
        Uri.parse(ApiConstants.exams),
        headers: headers,
        body: payload,
      );

      final body = jsonDecode(response.body);
      print('--- Create Exam Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------');
      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<int>> createQuestion(QuestionRequest request) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(ApiConstants.examQuestions);

      final multipartRequest = http.MultipartRequest('POST', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      multipartRequest.fields.addAll(request.toFields());

      print('--- Create Question Request ---');
      print('URL: ${ApiConstants.examQuestions}');
      print('Fields: ${request.toFields()}');
      if (request.filePath != null) {
        print('File: ${request.filePath}');
      }
      if (request.correctAnswerFilePath != null) {
        print('CorrectAnswerFile: ${request.correctAnswerFilePath}');
      }
      print('-----------------------------');

      if (request.fileBytes != null && request.fileName != null) {
        final mimeType = _getMimeType(request.fileName!);
        multipartRequest.files.add(
          http.MultipartFile.fromBytes(
            'File',
            request.fileBytes!,
            filename: request.fileName!,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else if (request.filePath != null) {
        final fileName = request.filePath!.split('\\').last.split('/').last;
        final mimeType = _getMimeType(fileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'File',
            request.filePath!,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      // Handle CorrectAnswerFile
      if (request.correctAnswerFileBytes != null &&
          request.correctAnswerFileName != null) {
        final mimeType = _getMimeType(request.correctAnswerFileName!);
        multipartRequest.files.add(
          http.MultipartFile.fromBytes(
            'CorrectAnswerFile',
            request.correctAnswerFileBytes!,
            filename: request.correctAnswerFileName!,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else if (request.correctAnswerFilePath != null) {
        final fileName =
            request.correctAnswerFilePath!.split('\\').last.split('/').last;
        final mimeType = _getMimeType(fileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'CorrectAnswerFile',
            request.correctAnswerFilePath!,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      final body = jsonDecode(response.body);
      print('--- Create Question Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');
      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<int>> createQuestionOption(
    QuestionOptionRequest request,
  ) async {
    try {
      final headers = await _getHeaders();
      final payload = jsonEncode(request.toJson());

      print('--- Create Question Option Request ---');
      print('URL: ${ApiConstants.questionOptions}');
      print('Headers: $headers');
      print('Payload: $payload');
      print('------------------------------------');

      final response = await http.post(
        Uri.parse(ApiConstants.questionOptions),
        headers: headers,
        body: payload,
      );

      final body = jsonDecode(response.body);
      print('--- Create Question Option Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');
      return ApiResponse<int>.fromJson(body, (data) => data as int);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> approveStudentSubscription({
    required int teacherId,
    required int courseId,
    required int studentId,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/v1/course-subscriptions/teacher/$teacherId/course/$courseId/students/$studentId/approve',
      );

      print('--- Approve Student Subscription Request ---');
      print('URL: $uri');
      print('Headers: $headers');
      print('------------------------------------------');

      final response = await http.post(uri, headers: headers);

      print('--- Approve Student Subscription Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Student approved successfully',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => false);
    } catch (e) {
      print('Error approving subscription: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> approveStudentSubscriptionByEmail({
    required int teacherId,
    required int courseId,
    required String studentEmail,
  }) async {
    try {
      final headers = await _getHeaders();
      // Email must be encoded to be safe in the URL path
      final encodedEmail = Uri.encodeComponent(studentEmail);

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/v1/course-subscriptions/teacher/$teacherId/course/$courseId/students/$encodedEmail/approve',
      );

      print('--- Approve Student Subscription By Email Request ---');
      print('URL: $uri');
      print('Headers: $headers');
      print('--------------------------------------------------');

      final response = await http.post(uri, headers: headers);

      print('--- Approve Student Subscription Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Student approved successfully',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => false);
    } catch (e) {
      print('Error approving subscription: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteQuestionOption(int optionId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.questionOptions}/$optionId';

      print('--- Delete Question Option Request ---');
      print('URL: $url');
      print('Headers: $headers');
      print('------------------------------------');

      final response = await http.delete(Uri.parse(url), headers: headers);

      print('--- Delete Question Option Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: true,
          message: 'Option deleted successfully',
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to delete option',
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

  Future<ApiResponse<void>> updateQuestionOption(
    QuestionOptionRequest request,
  ) async {
    try {
      final headers = await _getHeaders();
      // API uses PUT /api/v1/question-options (ID is in the request body)
      final url = ApiConstants.questionOptions;
      final payload = jsonEncode(request.toJson());

      print('--- Update Question Option Request ---');
      print('URL: $url');
      print('Headers: $headers');
      print('Payload: $payload');
      print('------------------------------------');

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: payload,
      );

      print('--- Update Question Option Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: true,
          message: 'Option updated successfully',
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to update option',
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

  Future<ApiResponse<bool>> updateQuestion(
    QuestionRequest request,
    int questionId,
  ) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse('${ApiConstants.exams}/Edit/questions');

      final multipartRequest = http.MultipartRequest('PUT', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      final fields = request.toFields();
      fields['Id'] = questionId.toString();
      multipartRequest.fields.addAll(fields);

      print('--- Update Question Request ---');
      print('URL: $uri');
      print('Fields:Fields: $fields');
      if (request.filePath != null) {
        print('File: ${request.filePath}');
      }
      if (request.correctAnswerFilePath != null) {
        print('CorrectAnswerFile: ${request.correctAnswerFilePath}');
      }
      print('-----------------------------');

      if (request.fileBytes != null && request.fileName != null) {
        final mimeType = _getMimeType(request.fileName!);
        multipartRequest.files.add(
          http.MultipartFile.fromBytes(
            'File',
            request.fileBytes!,
            filename: request.fileName!,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else if (request.filePath != null) {
        final fileName = request.filePath!.split('\\').last.split('/').last;
        final mimeType = _getMimeType(fileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'File',
            request.filePath!,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      // Handle CorrectAnswerFile
      if (request.correctAnswerFileBytes != null &&
          request.correctAnswerFileName != null) {
        final mimeType = _getMimeType(request.correctAnswerFileName!);
        multipartRequest.files.add(
          http.MultipartFile.fromBytes(
            'CorrectAnswerFile',
            request.correctAnswerFileBytes!,
            filename: request.correctAnswerFileName!,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else if (request.correctAnswerFilePath != null) {
        final fileName =
            request.correctAnswerFilePath!.split('\\').last.split('/').last;
        final mimeType = _getMimeType(fileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'CorrectAnswerFile',
            request.correctAnswerFilePath!,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Update Question Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Updated successfully',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Update student answer image (for teacher editing during grading)
  /// PUT /api/v1/student-answers/{id}/image
  Future<ApiResponse<String>> updateStudentAnswerImage({
    required int studentAnswerId,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final uri = Uri.parse(
        ApiConstants.updateStudentAnswerImage(studentAnswerId),
      );

      final multipartRequest = http.MultipartRequest('PUT', uri);
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      // Add StudentAnswerId as field
      multipartRequest.fields['StudentAnswerId'] = studentAnswerId.toString();

      // Add image file
      final mimeType = _getMimeType(fileName);
      multipartRequest.files.add(
        http.MultipartFile.fromBytes(
          'ImageFile',
          imageBytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      print('--- Update Student Answer Image Request ---');
      print('URL: $uri');
      print('StudentAnswerId: $studentAnswerId');
      print('FileName: $fileName');
      print('------------------------------------------');

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Update Student Answer Image Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Try to extract the new image URL from response
        String? newImageUrl;
        if (response.body.isNotEmpty) {
          try {
            final body = jsonDecode(response.body);
            newImageUrl = body['data']?['imageUrl'] ?? body['imageUrl'];
          } catch (_) {
            // If parsing fails, return empty string
          }
        }
        return ApiResponse(
          succeeded: true,
          message: 'تم تحديث صورة الإجابة بنجاح',
          data: newImageUrl ?? '',
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<String>.fromJson(body, (data) => data.toString());
    } catch (e) {
      print('ERROR in updateStudentAnswerImage: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  Future<ApiResponse<bool>> deleteQuestion(int questionId) async {
    try {
      final headers = await _getHeaders();
      // User requested path: .../api/v1/exams/{id}/questions
      // Assuming {id} is the questionId based on previous patterns (like deleteMaterial)
      final uri = Uri.parse('${ApiConstants.exams}/$questionId/questions');

      print('--- Delete Question Request ---');
      print('URL: $uri');
      print('-----------------------------');

      final response = await http.delete(uri, headers: headers);

      print('--- Delete Question Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'تم حذف السؤال بنجاح',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  Future<ApiResponse<bool>> deleteExam(int examId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.exams}/$examId'),
        headers: headers,
      );

      if (response.body.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(
            succeeded: true,
            message: 'Deleted successfully',
            data: true,
            statusCode: response.statusCode,
          );
        }
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> updateExam(ExamRequest request, int examId) async {
    try {
      final headers = await _getHeaders();
      final bodyData = request.toJson();
      bodyData['id'] = examId;

      print('--- Update Exam Request ---');
      print('URL: ${ApiConstants.exams}/Edit');
      print('Headers: $headers');
      print('Payload: $bodyData');
      print('---------------------------');

      final response = await http.put(
        Uri.parse('${ApiConstants.exams}/Edit'),
        headers: headers,
        body: jsonEncode(bodyData),
      );

      print('--- Update Exam Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('----------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<List<Exam>>> getExamByLecture(int lectureId) async {
    try {
      final headers = await _getHeaders();
      final url = ApiConstants.getLectureExam(lectureId);

      print('--- Get Exam by Lecture Request ---');
      print('Lecture ID: $lectureId');
      print('URL: $url');
      print('Headers: $headers');
      print('------------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Get Exam by Lecture Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<List<Exam>>.fromJson(
        body,
        (data) => (data as List).map((e) => Exam.fromJson(e)).toList(),
      );
    } catch (e) {
      print('ERROR in getExamByLecture: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<Exam>> getExamById(int examId) async {
    try {
      final headers = await _getHeaders();
      final url = ApiConstants.getExamById(examId);

      print('--- Get Exam By Id Request ---');
      print('Exam ID: $examId');
      print('URL: $url');
      print('------------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Get Exam By Id Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<Exam>.fromJson(body, (data) => Exam.fromJson(data));
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Get teacher revenue statistics
  Future<ApiResponse<TeacherRevenueResponse>> getTeacherRevenue(
    int teacherId,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.baseUrl}/api/v1/teachers/revenue/$teacherId';

      print('--- Get Teacher Revenue Request ---');
      print('Teacher ID: $teacherId');
      print('URL: $url');
      print('-----------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Get Teacher Revenue Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<TeacherRevenueResponse>.fromJson(
        body,
        (data) => TeacherRevenueResponse.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      print('ERROR in getTeacherRevenue: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> autoSubmitExam(int examId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.exams}/$examId/auto-submit';

      final response = await http.post(Uri.parse(url), headers: headers);

      print('--- Auto Submit Exam Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------------');

      final body = jsonDecode(response.body);
      // The endpoint returns data object directly in result
      return ApiResponse<Map<String, dynamic>>.fromJson(
        body,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<int>> correctAllExams(int examId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.exams}/$examId/correct-all';

      final response = await http.post(Uri.parse(url), headers: headers);

      print('--- Correct All Exams Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('----------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<int>.fromJson(
        body,
        (data) => data as int,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> correctExamForStudent(
    int examId,
    int studentId,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.exams}/$examId/students/$studentId/correct';

      final response = await http.post(Uri.parse(url), headers: headers);

      print('--- Correct Student Exam Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-----------------------------------');

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Corrected successfully',
          data: true,
          statusCode: response.statusCode,
        );
      }
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
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
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<ApiResponse<List<EnrolledStudent>>> getEnrolledStudents(
    int courseId, {
    int? teacherId,
  }) async {
    try {
      final headers = await _getHeaders();
      final effectiveTeacherId =
          teacherId ?? await _tokenService.getTeacherId();

      if (effectiveTeacherId == null) {
        print('--- Get Enrolled Students Error ---');
        print(
          'Error: Teacher ID is null in SharedPreferences and not provided',
        );
        print('-----------------------------------');
        return ApiResponse(
          statusCode: 400,
          succeeded: false,
          message: 'Teacher ID not found',
        );
      }

      final url =
          '${ApiConstants.courseSubscriptions}/teacher/$effectiveTeacherId/course/$courseId/students';

      print('--- Get Enrolled Students Request ---');
      print('URL: $url');
      print('-----------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Get Enrolled Students Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------------');
      print('------------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<List<EnrolledStudent>>.fromJson(
        body,
        (data) =>
            (data as List).map((e) => EnrolledStudent.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> createDeadlineException(
    DeadlineExceptionRequest request,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.exams}/deadline-exception';
      final payload = jsonEncode(request.toJson());

      print('--- Create Deadline Exception Request ---');
      print('URL: $url');
      print('Payload: $payload');
      print('---------------------------------------');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: payload,
      );

      print('--- Create Deadline Exception Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('----------------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => true);
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Send exam notifications to students
  /// POST /api/v1/exams/send-notifications
  Future<ApiResponse<bool>> sendExamNotifications({
    required int examId,
    required int lectureId,
    required String examTitle,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.exams}/send-notifications';
      final payload = jsonEncode({
        'examId': examId,
        'lectureId': lectureId,
        'examTitle': examTitle,
      });

      print('--- Send Exam Notifications Request ---');
      print('URL: $url');
      print('Payload: $payload');
      print('---------------------------------------');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: payload,
      );

      print('--- Send Exam Notifications Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('----------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'تم إرسال الإشعارات بنجاح',
          data: true,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<bool>.fromJson(body, (data) => false);
    } catch (e) {
      print('ERROR in sendExamNotifications: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Get all students scores in a course
  /// GET /api/v1/courses/{courseId}/students/{teacherId}/scores
  /// Note: The API uses teacherId in the path to verify permissions
  Future<ApiResponse<List<Map<String, dynamic>>>> getCourseStudentsScores(
    int courseId,
  ) async {
    try {
      final headers = await _getHeaders();

      // Get teacherId from token
      final teacherId = await _tokenService.getTeacherId();
      if (teacherId == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'Teacher ID not found. Please login again.',
        );
      }

      final url =
          '${ApiConstants.baseUrl}/api/v1/courses/$courseId/students/$teacherId/scores';

      print('--- Get Course Students Scores Request ---');
      print('Course ID: $courseId');
      print('Teacher ID: $teacherId');
      print('URL: $url');
      print('------------------------------------------');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('--- Get Course Students Scores Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------------');

      final body = jsonDecode(response.body);
      return ApiResponse<List<Map<String, dynamic>>>.fromJson(
        body,
        (data) => (data as List).map((e) => e as Map<String, dynamic>).toList(),
      );
    } catch (e) {
      print('ERROR in getCourseStudentsScores: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Change exam visibility
  /// PUT /api/v1/exams/change-visiblity?examId={examId}&isVasbilty={isVisible}
  Future<ApiResponse<bool>> changeExamVisibility({
    required int examId,
    required bool isVisible,
  }) async {
    try {
      final headers = await _getHeaders();
      // NOTE: Query param 'isVasbilty' has a typo in the API as per user instruction
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/v1/exams/change-visiblity?examId=$examId&isVasbilty=$isVisible',
      );

      print('--- Change Exam Visibility Request ---');
      print('URL: $uri');
      print('------------------------------------');

      final response = await http.put(uri, headers: headers);

      print('--- Change Exam Visibility Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          final body = jsonDecode(response.body);
          // If response body structure is standard (statusCode, succeeded, message, data)
          if (body is Map<String, dynamic>) {
            return ApiResponse<bool>.fromJson(body, (data) => true);
          }
        }
        // Fallback for empty body or non-standard success
        return ApiResponse(
          succeeded: true,
          message: 'Visibility changed successfully',
          data: true,
          statusCode: response.statusCode,
        );
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to change visibility',
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

  /// Change lecture visibility
  /// PUT /api/v1/lectures/visibility
  Future<ApiResponse<bool>> changeLectureVisibility({
    required int lectureId,
    required bool isVisible,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConstants.baseUrl}/api/v1/lectures/visibility';

      final body = jsonEncode({'lectureId': lectureId, 'isVisible': isVisible});

      print('--- Change Lecture Visibility Request ---');
      print('URL: $url');
      print('Body: $body');
      print('---------------------------------------');

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('--- Change Lecture Visibility Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('----------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          final responseBody = jsonDecode(response.body);
          if (responseBody is Map<String, dynamic>) {
            return ApiResponse<bool>.fromJson(responseBody, (data) => true);
          }
        }
        return ApiResponse(
          succeeded: true,
          message: 'Visibility changed successfully',
          data: true,
          statusCode: response.statusCode,
        );
      } else {
        final responseBody =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to change visibility',
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

  /// Edit lecture material
  /// PUT /api/v1/lectures/Edit/materials  (multipart to support coverImage)
  Future<ApiResponse<bool>> editLectureMaterial({
    required int id,
    required String title,
    required String type,
    required String fileUrl,
    required int lectureId,
    required bool isFree,
    String? coverImagePath,
  }) async {
    try {
      final token = await _tokenService.getToken();
      final url = '${ApiConstants.baseUrl}/api/v1/lectures/Edit/materials';

      final multipartRequest = http.MultipartRequest('PUT', Uri.parse(url));
      multipartRequest.headers['Authorization'] = 'Bearer $token';

      multipartRequest.fields['id'] = id.toString();
      multipartRequest.fields['title'] = title;
      multipartRequest.fields['type'] = type;
      multipartRequest.fields['fileUrl'] = fileUrl;
      multipartRequest.fields['lectureId'] = lectureId.toString();
      multipartRequest.fields['isFree'] = isFree.toString();

      // Optional cover image
      if (coverImagePath != null) {
        final coverFileName = coverImagePath.split('\\').last.split('/').last;
        final mimeType = _getMimeType(coverFileName);
        multipartRequest.files.add(
          await http.MultipartFile.fromPath(
            'coverImage',
            coverImagePath,
            filename: coverFileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print('--- Edit Lecture Material Request ---');
      print('URL: $url');
      print('Fields: ${multipartRequest.fields}');
      print('CoverImage: $coverImagePath');
      print('------------------------------------');

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Edit Lecture Material Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          final responseBody = jsonDecode(response.body);
          if (responseBody is Map<String, dynamic>) {
            return ApiResponse<bool>.fromJson(responseBody, (data) => true);
          }
        }
        return ApiResponse(
          succeeded: true,
          message: 'Material updated successfully',
          data: true,
          statusCode: response.statusCode,
        );
      } else {
        final responseBody =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: responseBody['message'] ?? 'Failed to update material',
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
