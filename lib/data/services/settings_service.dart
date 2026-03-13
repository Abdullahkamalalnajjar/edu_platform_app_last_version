import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import 'token_service.dart';

class SettingsService {
  final _tokenService = TokenService();

  Future<ApiResponse<String>> getAboutUs() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User not authenticated',
        );
      }

      final response = await http.get(
        Uri.parse(ApiConstants.aboutUs),
        headers: {...ApiConstants.headers, 'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final aboutUsText = jsonResponse['data']['aboutUs'] as String?;
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: aboutUsText ?? 'من نحن',
        );
      } else {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch about us',
        );
      }
    } catch (e) {
      print('Error fetching about us: $e');
      return ApiResponse<String>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<String>> updateAppInfo({
    required String aboutUs,
    required String supportPhoneNumber,
    String? applicationUrl,
    String? version,
    bool? googleIconEnabled,
    bool? deleteAccountEnabled,
    bool? iconPriceEnabled,
    dynamic
    explanationVideoFile, // Accept File type depending on platform (io.File or bytes) if needed, but assuming io.File for now or handle appropriately
  }) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User not authenticated',
        );
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConstants.updateAppInfo),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'text/plain',
      });

      request.fields['AboutUs'] = aboutUs;
      request.fields['SupportPhoneNumber'] = supportPhoneNumber;
      if (applicationUrl != null && applicationUrl.isNotEmpty) {
        request.fields['ApplicationUrl'] = applicationUrl;
      }
      if (version != null && version.isNotEmpty) {
        request.fields['Version'] = version;
      }
      if (googleIconEnabled != null) {
        request.fields['GoogleIconEnabled'] = googleIconEnabled.toString();
      }
      if (deleteAccountEnabled != null) {
        request.fields['BtnDeleteAccountEnabled'] = deleteAccountEnabled
            .toString();
      }
      if (iconPriceEnabled != null) {
        request.fields['IconPriceEnabled'] = iconPriceEnabled.toString();
      }

      if (explanationVideoFile != null) {
        // Assuming implementation uses dart:io File for mobile/desktop
        // Add import 'dart:io'; at the top if not present, or use dynamic checking
        var file = explanationVideoFile;
        // Check if it's a file path or File object (simplified for now assuming File)
        var multipartFile = await http.MultipartFile.fromPath(
          'ExplanationVideoFile',
          file.path,
          // contentType: MediaType('video', 'mp4'), // Optional: Add mime type if needed
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: true,
          message:
              jsonResponse['message'] ??
              'Application info has been updated successfully',
          data: jsonResponse['data']
              ?.toString(), // The response data is a string message
        );
      } else {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to update app info',
        );
      }
    } catch (e) {
      print('Error updating app info: $e');
      return ApiResponse<String>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<String>> getExplanationVideoUrl() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.explanationVideo),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final url = jsonResponse['data']['explanationVideoUrl'] as String?;
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: url,
        );
      } else {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch video URL',
        );
      }
    } catch (e) {
      print('Error fetching video URL: $e');
      return ApiResponse<String>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<String>> getSupportPhoneNumber() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.supportPhone),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final phone = jsonResponse['data']['supportPhoneNumber'] as String?;
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: phone,
        );
      } else {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch phone number',
        );
      }
    } catch (e) {
      print('Error fetching phone number: $e');
      return ApiResponse<String>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<String>> getVersion() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.version),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final version = jsonResponse['data']['version'] as String?;
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: version ?? '1.0.0',
        );
      } else {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch version',
          data: '1.0.0',
        );
      }
    } catch (e) {
      print('Error fetching version: $e');
      return ApiResponse<String>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
        data: '1.0.0',
      );
    }
  }

  Future<ApiResponse<String>> getApplicationUrl() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.applicationUrl),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final url = jsonResponse['data'] as String?;
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: url,
        );
      } else {
        return ApiResponse<String>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch application URL',
        );
      }
    } catch (e) {
      print('Error fetching application URL: $e');
      return ApiResponse<String>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> getGoogleLoginEnabled() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.googleLoginEnabled),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final isEnabled = jsonResponse['data'] as bool? ?? false;
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: isEnabled,
        );
      } else {
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: false,
          message:
              jsonResponse['message'] ?? 'Failed to fetch Google login status',
          data: false, // Default to false if failed
        );
      }
    } catch (e) {
      print('Error fetching Google login status: $e');
      return ApiResponse<bool>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
        data: false, // Default to false on error
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAppInfo() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        return ApiResponse(
          statusCode: 401,
          succeeded: false,
          message: 'User not authenticated',
        );
      }

      final response = await http.get(
        Uri.parse(ApiConstants.updateAppInfo),
        headers: {...ApiConstants.headers, 'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final data = jsonResponse['data'] as Map<String, dynamic>?;
        return ApiResponse<Map<String, dynamic>>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: data ?? {},
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          statusCode: response.statusCode,
          succeeded: false,
          message: jsonResponse['message'] ?? 'Failed to fetch app info',
        );
      }
    } catch (e) {
      print('Error fetching app info: $e');
      return ApiResponse<Map<String, dynamic>>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
      );
    }
  }

  Future<ApiResponse<bool>> getDeleteAccountEnabled() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.deleteAccountEnabled),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final isEnabled = jsonResponse['data'] as bool? ?? false;
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: isEnabled,
        );
      } else {
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: false,
          message:
              jsonResponse['message'] ??
              'Failed to fetch delete account status',
          data: false,
        );
      }
    } catch (e) {
      print('Error fetching delete account status: $e');
      return ApiResponse<bool>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
        data: false,
      );
    }
  }

  Future<ApiResponse<bool>> getIconPricerEnabled() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.iconPricerEnabled),
        headers: ApiConstants.headers,
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      // Log the response for debugging as requested
      print('=== getIconPricerEnabled Response ===');
      print(jsonResponse);

      if (response.statusCode == 200 && jsonResponse['succeeded'] == true) {
        final isEnabled = jsonResponse['data'] as bool? ?? false;
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: true,
          message: jsonResponse['message'] ?? 'Successfully',
          data: isEnabled,
        );
      } else {
        return ApiResponse<bool>(
          statusCode: response.statusCode,
          succeeded: false,
          message:
              jsonResponse['message'] ?? 'Failed to fetch icon pricer status',
          data: false,
        );
      }
    } catch (e) {
      print('Error fetching icon pricer status: $e');
      return ApiResponse<bool>(
        statusCode: 500,
        succeeded: false,
        message: 'An error occurred: $e',
        data: false,
      );
    }
  }
}
