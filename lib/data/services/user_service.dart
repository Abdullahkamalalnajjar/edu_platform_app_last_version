import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import 'token_service.dart';

class UserService {
  final TokenService _tokenService = TokenService();

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
        'accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Ensure URL encoding for safety though GUIDs usually safe
      final encodedGuid = Uri.encodeComponent(userGuid);
      final url = '${ApiConstants.baseUrl}/api/v1/users/profile/$encodedGuid';

      print('Fetching User Profile: $url');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('Get User Profile Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // If string body is empty
        if (response.body.isEmpty) {
          return ApiResponse(
            statusCode: response.statusCode,
            succeeded: false,
            message: 'Empty response',
          );
        }

        final jsonResponse = jsonDecode(response.body);

        // Standard API Response structure
        if (jsonResponse is Map<String, dynamic>) {
          if (jsonResponse.containsKey('succeeded') &&
              jsonResponse['succeeded'] == false) {
            return ApiResponse(
              statusCode: response.statusCode,
              succeeded: false,
              message: jsonResponse['message'] ?? 'Failed to get profile',
            );
          }

          // If direct object or data wrapper
          if (jsonResponse.containsKey('data')) {
            return ApiResponse(
              statusCode: 200,
              succeeded: true,
              message: 'Profile retrieved',
              data: jsonResponse['data'],
            );
          } else {
            // Maybe the response itself is the profile data?
            // But usually your API wraps in { data: ... }
            // Let's assume it might return the profile object directly if not wrapped.
            return ApiResponse(
              statusCode: 200,
              succeeded: true,
              message: 'Profile retrieved',
              data: jsonResponse,
            );
          }
        }

        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Invalid response format',
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: 'Failed to load profile used status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error getting user profile: $e');
      return ApiResponse(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }
}
