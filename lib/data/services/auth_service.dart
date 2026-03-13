import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';
import '../models/auth_response_model.dart';
import '../models/role_model.dart';
import '../models/lookup_models.dart';
import '../models/session_models.dart';
import 'token_service.dart';
import 'device_info_service.dart';
import 'fcm_service.dart';

class AuthService {
  /// Login with email and password
  /// Set [forceLogin] to true to force logout from other devices
  Future<ApiResponse<AuthResponse>> login(
    String email,
    String password, {
    bool forceLogin = false,
  }) async {
    try {
      // Get device info for session management
      final deviceId = await DeviceInfoService.getDeviceId();
      final deviceName = await DeviceInfoService.getDeviceName();

      // Get FCM token for push notifications
      String? fcmToken;
      try {
        fcmToken = await FcmService.getFcmToken();
      } catch (e) {
        print('Warning: Could not get FCM token: $e');
      }

      final response = await http.post(
        Uri.parse(ApiConstants.signin),
        headers: ApiConstants.headers,
        body: jsonEncode(
          LoginRequest(
            email: email,
            password: password,
            deviceId: deviceId,
            deviceName: deviceName,
            fcmToken: fcmToken,
            forceLogin: forceLogin,
          ).toJson(),
        ),
      );

      print('--- Login Response Body ---');
      print('Status Code: ${response.statusCode}');
      print(response.body);
      print('---------------------------');

      if (response.statusCode != 200 &&
          response.headers['content-type']?.contains('text/html') == true) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message:
              'Received HTML error page instead of JSON. Check API endpoint.',
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<AuthResponse>.fromJson(
        body,
        (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Sign in with Google
  Future<ApiResponse<AuthResponse>> signInWithGoogle(String idToken) async {
    try {
      // Get FCM token for push notifications
      String? fcmToken;
      try {
        fcmToken = await FcmService.getFcmToken();
      } catch (e) {
        print('Warning: Could not get FCM token: $e');
      }

      final response = await http.get(
        Uri.parse(ApiConstants.googleSignin).replace(
          queryParameters: {
            'idToken': idToken,
            if (fcmToken != null) 'FCMtoken': fcmToken,
          },
        ),
        headers: ApiConstants.headers,
      );

      final body = jsonDecode(response.body);
      print('--- Google Sign-In Response Body ---');
      print(jsonEncode(body));
      print('------------------------------------');

      return ApiResponse<AuthResponse>.fromJson(
        body,
        (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<AuthResponse>> signup(SignupRequest request) async {
    try {
      var uri = Uri.parse(ApiConstants.signup);
      var multipartRequest = http.MultipartRequest('POST', uri);

      // Add headers (excluding content-type as multipart sets it)
      ApiConstants.headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          multipartRequest.headers[key] = value;
        }
      });

      // Add Fields
      final fields = request.toFields();
      fields.forEach((key, value) {
        multipartRequest.fields[key] = value;
      });

      // Add EducationStageIds (List<int>)
      if (request.educationStageIds != null) {
        for (var id in request.educationStageIds!) {
          // ASP.NET Core often binds lists from repeated keys
          multipartRequest.files.add(
            http.MultipartFile.fromString('EducationStageIds', id.toString()),
          );
        }
      }

      // Add Photo
      if (request.photoPath != null && request.photoPath!.isNotEmpty) {
        final file = await http.MultipartFile.fromPath(
          'PhotoFile',
          request.photoPath!,
        );
        multipartRequest.files.add(file);
      }

      // Send
      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Signup Response Body ---');
      print('Status Code: ${response.statusCode}');
      print(response.body);
      print('----------------------------');

      if (response.statusCode != 200 &&
          response.headers['content-type']?.contains('text/html') == true) {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message:
              'Received HTML error page instead of JSON. Check API endpoint.',
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<AuthResponse>.fromJson(
        body,
        (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<List<Role>>> getRoles() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.getRoles),
        headers: ApiConstants.headers,
      );

      print('--- Get Roles Response ---');
      print('Status Code: ${response.statusCode}');
      print(response.body);
      print('--------------------------');

      if (response.headers['content-type']?.contains('text/html') == true) {
        print('CRITICAL ERROR: Received HTML from ${ApiConstants.getRoles}');
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message:
              'Server returned HTML instead of JSON. Endpoint might be wrong: ${ApiConstants.getRoles}',
        );
      }

      final body = jsonDecode(response.body);
      return ApiResponse<List<Role>>.fromJson(
        body,
        (data) => (data as List).map((e) => Role.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<List<EducationStage>>> getEducationStages() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.educationStages),
        headers: ApiConstants.headers,
      );

      final body = jsonDecode(response.body);
      return ApiResponse<List<EducationStage>>.fromJson(
        body,
        (data) =>
            (data as List).map((e) => EducationStage.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<List<Subject>>> getSubjects() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.subjects),
        headers: ApiConstants.headers,
      );

      final body = jsonDecode(response.body);
      return ApiResponse<List<Subject>>.fromJson(
        body,
        (data) => (data as List).map((e) => Subject.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> updateProfile(
    EditUserProfileRequest request,
  ) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/EditUserProfile');
      final multipartRequest = http.MultipartRequest('PUT', uri);

      ApiConstants.headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          multipartRequest.headers[key] = value;
        }
      });

      final tokenService = TokenService();
      final token = await tokenService.getToken();
      if (token != null) {
        multipartRequest.headers['Authorization'] = 'Bearer $token';
      }

      final fields = request.toFields();
      fields.forEach((key, value) {
        multipartRequest.fields[key] = value;
      });

      if (request.photoPath != null && request.photoPath!.isNotEmpty) {
        final file = await http.MultipartFile.fromPath(
          'PhotoFile',
          request.photoPath!,
        );
        multipartRequest.files.add(file);
      }

      print('--- Update Profile Request ---');
      print('URL: $uri');
      print('Fields: ${multipartRequest.fields}');
      if (request.photoPath != null) print('Photo: ${request.photoPath}');
      print('------------------------------');

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('--- Update Profile Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Profile updated successfully',
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

  /// Update user role
  Future<ApiResponse<bool>> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getToken();

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/users/role'),
        headers: {
          ...ApiConstants.headers,
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId, 'newRole': newRole}),
      );

      print('--- Update User Role Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------------');

      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          succeeded: true,
          message: 'Role updated successfully',
          data: true,
          statusCode: response.statusCode,
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        succeeded: false,
        message: body['message'] ?? 'Failed to update user role',
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  // ============ Session Management ============

  /// Get active sessions for a user
  Future<ApiResponse<ActiveSessionsResponse>> getActiveSessions(
    String userId,
  ) async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getToken();
      final currentDeviceId = await DeviceInfoService.getDeviceId();

      final response = await http.get(
        Uri.parse(
          ApiConstants.getActiveSessions(
            userId,
            currentDeviceId: currentDeviceId,
          ),
        ),
        headers: {
          ...ApiConstants.headers,
          'Accept': '*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('--- Get Active Sessions Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------------');

      final body = jsonDecode(response.body);

      // API returns: {statusCode, succeeded, message, data: {...}}
      if (response.statusCode == 200 && body['succeeded'] == true) {
        return ApiResponse<ActiveSessionsResponse>(
          statusCode: body['statusCode'] ?? 200,
          succeeded: true,
          message: body['message'] ?? 'Success',
          data: ActiveSessionsResponse.fromJson(
            body['data'] as Map<String, dynamic>,
          ),
        );
      }

      // Handle error response
      return ApiResponse<ActiveSessionsResponse>(
        statusCode: body['statusCode'] ?? response.statusCode,
        succeeded: false,
        message: body['message'] ?? 'Failed to load sessions',
      );
    } catch (e) {
      print('Error in getActiveSessions: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Logout from a specific device/session
  Future<ApiResponse<bool>> logoutDevice(String userId, int sessionId) async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getToken();

      final response = await http.post(
        Uri.parse(ApiConstants.logoutDevice),
        headers: {
          ...ApiConstants.headers,
          'Accept': '*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(
          LogoutDeviceRequest(userId: userId, sessionId: sessionId).toJson(),
        ),
      );

      print('--- Logout Device Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');

      // Parse the response
      if (response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        // data field contains: "Logged out from device: Realme RMX2001"
        String message = body['message'] ?? 'تم تسجيل الخروج بنجاح';
        if (body['data'] != null && body['data'] is String) {
          message =
              body['data']; // Use more descriptive message with device name
        }
        return ApiResponse<bool>(
          statusCode: body['statusCode'] ?? response.statusCode,
          succeeded: body['succeeded'] ?? (response.statusCode == 200),
          message: message,
          data: true,
        );
      }

      // Handle empty response
      return ApiResponse<bool>(
        statusCode: response.statusCode,
        succeeded: response.statusCode == 200,
        message: response.statusCode == 200
            ? 'تم تسجيل الخروج بنجاح'
            : 'فشل في تسجيل الخروج',
        data: response.statusCode == 200,
      );
    } catch (e) {
      print('Error in logoutDevice: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Logout from all devices
  Future<ApiResponse<bool>> logoutAllDevices(String userId) async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getToken();

      final response = await http.post(
        Uri.parse(ApiConstants.logoutAllDevices),
        headers: {
          ...ApiConstants.headers,
          'Accept': '*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(LogoutAllDevicesRequest(userId: userId).toJson()),
      );

      print('--- Logout All Devices Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-----------------------------------');

      // Parse the response
      if (response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        String message = body['message'] ?? 'تم تسجيل الخروج من جميع الأجهزة';
        if (body['data'] != null && body['data'] is String) {
          message = body['data']; // Use more descriptive message
        }
        return ApiResponse<bool>(
          statusCode: body['statusCode'] ?? response.statusCode,
          succeeded: body['succeeded'] ?? (response.statusCode == 200),
          message: message,
          data: true,
        );
      }

      // Handle empty response
      return ApiResponse<bool>(
        statusCode: response.statusCode,
        succeeded: response.statusCode == 200,
        message: response.statusCode == 200
            ? 'تم تسجيل الخروج من جميع الأجهزة'
            : 'فشل في تسجيل الخروج',
        data: response.statusCode == 200,
      );
    } catch (e) {
      print('Error in logoutAllDevices: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Change user password
  Future<ApiResponse<bool>> changePassword(
    ChangePasswordRequest request,
  ) async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getToken();

      final response = await http.put(
        Uri.parse(ApiConstants.changePassword),
        headers: {
          ...ApiConstants.headers,
          'Accept': '*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      print('--- Change Password Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('--------------------------------');

      if (response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        return ApiResponse<bool>(
          statusCode: body['statusCode'] ?? response.statusCode,
          succeeded: body['succeeded'] ?? (response.statusCode == 200),
          message:
              body['message'] ??
              (response.statusCode == 200
                  ? 'تم تغيير كلمة المرور بنجاح'
                  : 'فشل في تغيير كلمة المرور'),
          data: body['succeeded'] ?? (response.statusCode == 200),
        );
      }

      return ApiResponse<bool>(
        statusCode: response.statusCode,
        succeeded: response.statusCode == 200,
        message: response.statusCode == 200
            ? 'تم تغيير كلمة المرور بنجاح'
            : 'فشل في تغيير كلمة المرور',
        data: response.statusCode == 200,
      );
    } catch (e) {
      print('Error in changePassword: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  // ============ Forgot Password Flow ============

  /// Send OTP to email for password reset
  Future<ApiResponse<bool>> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.sendOtp(email)),
        headers: {...ApiConstants.headers, 'Accept': '*/*'},
      );

      print('--- Send OTP Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------');

      if (response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        return ApiResponse<bool>(
          statusCode: body['statusCode'] ?? response.statusCode,
          succeeded: body['succeeded'] ?? (response.statusCode == 200),
          message:
              body['message'] ??
              (response.statusCode == 200
                  ? 'تم إرسال رمز التحقق إلى بريدك الإلكتروني'
                  : 'فشل في إرسال رمز التحقق'),
          data: body['succeeded'] ?? (response.statusCode == 200),
        );
      }

      return ApiResponse<bool>(
        statusCode: response.statusCode,
        succeeded: response.statusCode == 200,
        message: response.statusCode == 200
            ? 'تم إرسال رمز التحقق إلى بريدك الإلكتروني'
            : 'فشل في إرسال رمز التحقق',
        data: response.statusCode == 200,
      );
    } catch (e) {
      print('Error in sendOtp: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Verify OTP code
  Future<ApiResponse<bool>> verifyOtp(VerifyOtpRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.verifyOtp),
        headers: {...ApiConstants.headers, 'Accept': '*/*'},
        body: jsonEncode(request.toJson()),
      );

      print('--- Verify OTP Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------');

      if (response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        return ApiResponse<bool>(
          statusCode: body['statusCode'] ?? response.statusCode,
          succeeded: body['succeeded'] ?? (response.statusCode == 200),
          message:
              body['message'] ??
              (response.statusCode == 200
                  ? 'تم التحقق من الرمز بنجاح'
                  : 'رمز التحقق غير صحيح'),
          data: body['succeeded'] ?? (response.statusCode == 200),
        );
      }

      return ApiResponse<bool>(
        statusCode: response.statusCode,
        succeeded: response.statusCode == 200,
        message: response.statusCode == 200
            ? 'تم التحقق من الرمز بنجاح'
            : 'رمز التحقق غير صحيح',
        data: response.statusCode == 200,
      );
    } catch (e) {
      print('Error in verifyOtp: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Reset password with new password
  Future<ApiResponse<bool>> resetPassword(ResetPasswordRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.resetPassword),
        headers: {...ApiConstants.headers, 'Accept': '*/*'},
        body: jsonEncode(request.toJson()),
      );

      print('--- Reset Password Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-------------------------------');

      if (response.body.isNotEmpty) {
        final body = jsonDecode(response.body);
        return ApiResponse<bool>(
          statusCode: body['statusCode'] ?? response.statusCode,
          succeeded: body['succeeded'] ?? (response.statusCode == 200),
          message:
              body['message'] ??
              (response.statusCode == 200
                  ? 'تم تغيير كلمة المرور بنجاح'
                  : 'فشل في تغيير كلمة المرور'),
          data: body['succeeded'] ?? (response.statusCode == 200),
        );
      }

      return ApiResponse<bool>(
        statusCode: response.statusCode,
        succeeded: response.statusCode == 200,
        message: response.statusCode == 200
            ? 'تم تغيير كلمة المرور بنجاح'
            : 'فشل في تغيير كلمة المرور',
        data: response.statusCode == 200,
      );
    } catch (e) {
      print('Error in resetPassword: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'حدث خطأ: $e',
      );
    }
  }

  /// Update FCM token on the backend (for token refresh)
  Future<ApiResponse<bool>> updateFcmToken(String fcmToken) async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getToken();
      final deviceId = await DeviceInfoService.getDeviceId();

      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User not authenticated',
        );
      }

      final response = await http.post(
        Uri.parse(ApiConstants.updateFcmToken),
        headers: {...ApiConstants.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode({'fcmToken': fcmToken, 'deviceId': deviceId}),
      );

      print('--- Update FCM Token Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('---------------------------------');

      if (response.statusCode == 200) {
        return ApiResponse(
          statusCode: 200,
          succeeded: true,
          message: 'FCM token updated successfully',
          data: true,
        );
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to update FCM token',
        );
      }
    } catch (e) {
      print('Error updating FCM token: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  /// Refresh Access Token
  Future<ApiResponse<AuthResponse>> refreshToken() async {
    try {
      final tokenService = TokenService();
      final refreshToken = await tokenService.getRefreshToken();
      final accessToken = await tokenService.getToken();

      if (refreshToken == null || accessToken == null) {
        return ApiResponse(
          statusCode: 400,
          succeeded: false,
          message: 'No tokens available for refresh',
        );
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/auth/refresh-token'),
        headers: ApiConstants.headers,
        body: jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        }),
      );

      print('--- Refresh Token Response ---');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('------------------------------');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'] != null
            ? AuthResponse.fromJson(body['data'])
            : AuthResponse.fromJson(body);

        await tokenService.saveToken(data.token);
        await tokenService.saveRefreshToken(data.refreshToken);

        if (data.userId != null) {
          await tokenService.saveUserId(data.userId!);
        }
        if (data.teacherId != null) {
          await tokenService.saveTeacherId(data.teacherId!);
        }

        if (data.roles.isNotEmpty) {
          String? roleToSave;
          if (data.roles.contains('Admin')) {
            roleToSave = 'Admin';
          } else if (data.roles.contains('Teacher')) {
            roleToSave = 'Teacher';
          } else if (data.roles.contains('Assistant')) {
            roleToSave = 'Assistant';
          } else if (data.roles.contains('Student')) {
            roleToSave = 'Student';
          } else if (data.roles.contains('Parent')) {
            roleToSave = 'Parent';
          }
          if (roleToSave != null) {
            await tokenService.saveRole(roleToSave);
          }
        }

        // Save extended info if available
        await tokenService.saveExtendedUserInfo(
          photoUrl: data.photoUrl,
          phoneNumber: data.phoneNumber,
          facebookUrl: data.facebookUrl,
          telegramUrl: data.telegramUrl,
          whatsAppNumber: data.whatsAppNumber,
          youTubeChannelUrl: data.youTubeChannelUrl,
        );

        await tokenService.saveUserInfo(
          name: '${data.firstName} ${data.lastName}',
          email: data.email,
        );

        return ApiResponse(
          succeeded: true,
          data: data,
          statusCode: 200,
          message: 'Token refreshed successfully',
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        succeeded: false,
        message: body['message'] ?? 'Failed to refresh token',
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'Error refreshing token: $e',
      );
    }
  }
}
