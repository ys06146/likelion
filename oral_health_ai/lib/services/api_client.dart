import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiClient {
  static const requestTimeout = Duration(seconds: 25);
  static const uploadTimeout = Duration(seconds: 90);
  static const maxImageBytes = 10 * 1024 * 1024;
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      // One origin for the container deployment; local Flutter uses a separate port.
      final local =
          Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';
      if (local && Uri.base.port != 8000) return 'http://127.0.0.1:8000';
      return Uri.base.origin;
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  static Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return send(request, token: token);
  }

  static Future<Map<String, dynamic>> send(
    http.BaseRequest request, {
    String? token,
    Duration timeout = requestTimeout,
  }) async {
    final client = http.Client();
    request.headers['accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw ApiException(
          'The server returned an unexpected response. Please try again.',
          response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          throw const ApiException(
            'Your session has expired. Please sign in again.',
            401,
          );
        }
        final detail = decoded is Map ? decoded['detail'] : null;
        String message = 'Request failed. Please try again.';
        if (detail is String) {
          message = detail;
        } else if (detail is List) {
          message = detail.map((e) => e is Map ? e['msg'] : e).join('\n');
        }
        throw ApiException(message, response.statusCode);
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The server returned an unexpected response.');
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    } finally {
      client.close();
    }
  }
}
