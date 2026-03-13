import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student_model.dart';
import '../models/teacher_admin_model.dart';
import '../models/parent_admin_model.dart';
import '../models/admin_statistics_model.dart';
import '../../core/constants/api_constants.dart';
import './token_service.dart';

class AdminService {
  final _tokenService = TokenService();

  // Get admin statistics
  Future<AdminStatisticsModel> getStatistics() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('Fetching statistics from: ${ApiConstants.adminStatistics}');

      final response = await http.get(
        Uri.parse(ApiConstants.adminStatistics),
        headers: {'Accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );

      print('Statistics response status: ${response.statusCode}');
      print('Statistics response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Check if the response is successful
        final succeeded = jsonResponse['succeeded'] ?? false;
        if (!succeeded) {
          final message =
              jsonResponse['message'] ?? 'Failed to load statistics';
          throw Exception(message);
        }

        // Parse the data object
        final data = jsonResponse['data'];
        if (data == null) {
          throw Exception('No statistics data found');
        }

        return AdminStatisticsModel.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        print('Error response body: ${response.body}');
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getStatistics: $e');
      rethrow;
    }
  }

  // Get all students
  Future<List<StudentModel>> getAllStudents() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(ApiConstants.adminStudents),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Check if the response is successful
        final succeeded = jsonResponse['succeeded'] ?? false;
        if (!succeeded) {
          final message = jsonResponse['message'] ?? 'Failed to load students';
          throw Exception(message);
        }

        // Parse the data array
        final data = jsonResponse['data'] as List?;
        if (data == null) {
          return [];
        }

        return data
            .map((json) => StudentModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        throw Exception('Failed to load students: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAllStudents: $e');
      rethrow;
    }
  }

  // Get all teachers
  Future<List<TeacherAdminModel>> getAllTeachers() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(ApiConstants.adminTeachers),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('getAllTeachers response status: ${response.statusCode}');
      print('getAllTeachers response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Check if the response is successful
        final succeeded = jsonResponse['succeeded'] ?? false;
        if (!succeeded) {
          final message = jsonResponse['message'] ?? 'Failed to load teachers';
          throw Exception(message);
        }

        // Parse the data array
        final data = jsonResponse['data'] as List?;
        if (data == null) {
          return [];
        }

        return data
            .map(
              (json) =>
                  TeacherAdminModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        throw Exception('Failed to load teachers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAllTeachers: $e');
      rethrow;
    }
  }

  // Get all parents
  Future<List<ParentAdminModel>> getAllParents() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(ApiConstants.adminParents),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Check if the response is successful
        final succeeded = jsonResponse['succeeded'] ?? false;
        if (!succeeded) {
          final message = jsonResponse['message'] ?? 'Failed to load parents';
          throw Exception(message);
        }

        // Parse the data array
        final data = jsonResponse['data'] as List?;
        if (data == null) {
          return [];
        }

        return data
            .map(
              (json) => ParentAdminModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        throw Exception('Failed to load parents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAllParents: $e');
      rethrow;
    }
  }

  // Approve teacher
  Future<bool> approveTeacher(String teacherUserId) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(ApiConstants.approveTeacher),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'teacherUserId': teacherUserId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        throw Exception('Failed to approve teacher: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in approveTeacher: $e');
      rethrow;
    }
  }

  // Toggle Block User
  Future<bool> toggleBlockUser(String userId) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('Calling toggleBlockUser API...');
      print('URL: ${ApiConstants.toggleBlockUser}');
      print('UserId: $userId');

      final response = await http.post(
        Uri.parse(ApiConstants.toggleBlockUser),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'TeacherUserId': userId}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        throw Exception('Failed to toggle block user: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in toggleBlockUser: $e');
      rethrow;
    }
  }

  // Delete User
  Future<bool> deleteUser(String userId) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('Calling deleteUser API...');
      print('URL: ${ApiConstants.deleteUser(userId)}');
      print('UserId: $userId');

      final response = await http.delete(
        Uri.parse(ApiConstants.deleteUser(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('غير مصرح لك، يُرجى تسجيل الدخول');
      } else {
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in deleteUser: $e');
      rethrow;
    }
  }
}
