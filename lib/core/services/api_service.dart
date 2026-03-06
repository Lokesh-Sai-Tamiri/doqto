/// ============================================================================
/// API SERVICE - HTTP Client for HymnChat API Backend
/// ============================================================================
///
/// Handles all REST API communication with the FastAPI backend.
/// Automatically injects Supabase JWT tokens for authentication.
/// ============================================================================
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'supabase_service.dart';

/// HTTP methods enum
enum HttpMethod { get, post, put, patch, delete }

/// API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
  });

  factory ApiResponse.success(T data, int statusCode) {
    return ApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.failure(String error, int statusCode) {
    return ApiResponse(
      success: false,
      error: error,
      statusCode: statusCode,
    );
  }
}

/// API Service for communicating with the HymnChat backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  /// Base URL for API requests
  String get baseUrl => AppConfig.apiBaseUrl + AppConfig.apiVersion;

  /// Get authorization header with current JWT token
  Future<Map<String, String>> _getHeaders({
    bool requireAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = SupabaseService.currentSession?.accessToken;
      if (token == null) {
        throw ApiException('Not authenticated', 401);
      }

      // Check if session is valid, refresh if needed
      if (!SupabaseService.isSessionValid()) {
        final refreshed = await SupabaseService.refreshSession();
        if (!refreshed) {
          throw ApiException('Session expired', 401);
        }
      }

      final freshToken = SupabaseService.currentSession?.accessToken;
      if (freshToken != null) {
        headers['Authorization'] = 'Bearer $freshToken';
      }
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Make an API request
  Future<ApiResponse<T>> request<T>({
    required String path,
    required HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final headers = await _getHeaders(requireAuth: requireAuth);

      if (AppConfig.apiDebugMode) {
        print('📤 ${method.name.toUpperCase()} $uri');
        if (body != null) {
          print('   Body: ${jsonEncode(body)}');
        }
      }

      http.Response response;
      final timeout = Duration(seconds: AppConfig.apiRequestTimeoutSeconds);

      switch (method) {
        case HttpMethod.get:
          response = await _client.get(uri, headers: headers).timeout(timeout);
          break;
        case HttpMethod.post:
          response = await _client
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(timeout);
          break;
        case HttpMethod.put:
          response = await _client
              .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(timeout);
          break;
        case HttpMethod.patch:
          response = await _client
              .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(timeout);
          break;
        case HttpMethod.delete:
          response = await _client.delete(uri, headers: headers).timeout(timeout);
          break;
      }

      if (AppConfig.apiDebugMode) {
        print('📥 ${response.statusCode}: ${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}');
      }

      return _handleResponse<T>(response, fromJson);
    } on SocketException catch (e) {
      if (AppConfig.apiDebugMode) {
        print('❌ Network error: $e');
      }
      return ApiResponse.failure('Network error. Please check your connection.', 0);
    } on http.ClientException catch (e) {
      if (AppConfig.apiDebugMode) {
        print('❌ Client error: $e');
      }
      return ApiResponse.failure('Connection error. Please try again.', 0);
    } on ApiException catch (e) {
      if (AppConfig.apiDebugMode) {
        print('❌ API error: ${e.message}');
      }
      return ApiResponse.failure(e.message, e.statusCode);
    } catch (e) {
      if (AppConfig.apiDebugMode) {
        print('❌ Unexpected error: $e');
      }
      return ApiResponse.failure('Something went wrong. Please try again.', 0);
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final url = '$baseUrl$path';
    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: queryParams);
    }
    return Uri.parse(url);
  }

  /// Handle API response
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJson,
  ) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return ApiResponse.success(null as T, statusCode);
      }

      final json = jsonDecode(response.body);

      if (fromJson != null) {
        return ApiResponse.success(fromJson(json), statusCode);
      }

      return ApiResponse.success(json as T, statusCode);
    }

    // Handle error responses
    String errorMessage = 'Request failed';

    try {
      final errorJson = jsonDecode(response.body);
      errorMessage = errorJson['detail'] ?? errorJson['message'] ?? errorMessage;
    } catch (_) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }

    return ApiResponse.failure(errorMessage, statusCode);
  }

  // ============================================================================
  // Convenience methods
  // ============================================================================

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) {
    return request<T>(
      path: path,
      method: HttpMethod.get,
      queryParams: queryParams,
      requireAuth: requireAuth,
      fromJson: fromJson,
    );
  }

  /// POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) {
    return request<T>(
      path: path,
      method: HttpMethod.post,
      body: body,
      queryParams: queryParams,
      requireAuth: requireAuth,
      fromJson: fromJson,
    );
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) {
    return request<T>(
      path: path,
      method: HttpMethod.put,
      body: body,
      requireAuth: requireAuth,
      fromJson: fromJson,
    );
  }

  /// PATCH request
  Future<ApiResponse<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) {
    return request<T>(
      path: path,
      method: HttpMethod.patch,
      body: body,
      requireAuth: requireAuth,
      fromJson: fromJson,
    );
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    bool requireAuth = true,
    T Function(dynamic json)? fromJson,
  }) {
    return request<T>(
      path: path,
      method: HttpMethod.delete,
      requireAuth: requireAuth,
      fromJson: fromJson,
    );
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

/// API Exception
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
