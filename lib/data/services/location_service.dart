import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';

class LocationService {
  /// Fetch list of governorates
  Future<ApiResponse<List<String>>> getGovernorates() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.governorates),
        headers: ApiConstants.headers,
      );

      final body = jsonDecode(response.body);

      if (body['succeeded'] == true && body['data'] != null) {
        return ApiResponse<List<String>>(
          statusCode: 200,
          succeeded: true,
          message: body['message'] ?? 'Success',
          data: List<String>.from(body['data']),
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          succeeded: false,
          message: body['message'] ?? 'Failed to fetch governorates',
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
