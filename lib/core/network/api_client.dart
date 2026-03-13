import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../data/services/token_service.dart';
import '../constants/api_constants.dart';

/// A global key to access navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// HTTP Client wrapper with automatic token handling and 401 interception
class ApiClient {
  final TokenService _tokenService = TokenService();

  /// Make GET request with automatic token injection
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final requestHeaders = await _buildHeaders(headers, requiresAuth);
    final response = await http.get(Uri.parse(url), headers: requestHeaders);
    return _handleResponse(response);
  }

  /// Make POST request with automatic token injection
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final requestHeaders = await _buildHeaders(headers, requiresAuth);
    final encodedBody = body is String ? body : jsonEncode(body);
    final response = await http.post(
      Uri.parse(url),
      headers: requestHeaders,
      body: encodedBody,
    );
    return _handleResponse(response);
  }

  /// Make PUT request with automatic token injection
  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final requestHeaders = await _buildHeaders(headers, requiresAuth);
    final encodedBody = body is String ? body : jsonEncode(body);
    final response = await http.put(
      Uri.parse(url),
      headers: requestHeaders,
      body: encodedBody,
    );
    return _handleResponse(response);
  }

  /// Make DELETE request with automatic token injection
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final requestHeaders = await _buildHeaders(headers, requiresAuth);
    final response = await http.delete(Uri.parse(url), headers: requestHeaders);
    return _handleResponse(response);
  }

  /// Build headers with token if required
  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders,
    bool requiresAuth,
  ) async {
    final headers = Map<String, String>.from(ApiConstants.headers);

    if (requiresAuth) {
      final token = await _tokenService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Handle response and check for 401
  http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      // Token is expired or invalid - handle unauthorized
      _handleUnauthorized();
    }
    return response;
  }

  /// Handle 401 Unauthorized - clear tokens and redirect to login
  void _handleUnauthorized() async {
    print('🔒 401 Unauthorized - Session expired or invalid');

    // Clear all tokens
    await _tokenService.clearTokens();

    // Navigate to login screen if navigator is available
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _tokenService.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current auth token
  Future<String?> getAuthToken() async {
    return await _tokenService.getToken();
  }
}

/// Singleton instance of ApiClient
final apiClient = ApiClient();
