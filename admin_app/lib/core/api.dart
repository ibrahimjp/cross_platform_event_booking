import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// A file picked for upload (event images).
class UploadFile {
  UploadFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Thin HTTP client for the EventBook admin API (`/api/admin/*`).
class AdminApi {
  AdminApi._();

  static final AdminApi instance = AdminApi._();

  static const _urlKey = 'admin_api_url';
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');

  final http.Client _client = http.Client();
  String? _token;
  String _baseUrl = defaultBaseUrl;

  /// Called when the server rejects the admin session (expired, demoted, suspended).
  VoidCallback? onUnauthorized;

  static String get defaultBaseUrl {
    if (_configuredUrl.trim().isNotEmpty) return _trim(_configuredUrl);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://127.0.0.1:3000';
  }

  static String _trim(String url) => url.trim().replaceFirst(RegExp(r'/+$'), '');

  String get baseUrl => _baseUrl;

  set token(String? value) => _token = value;

  Future<void> loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_urlKey);
      if (saved != null && saved.trim().isNotEmpty) _baseUrl = _trim(saved);
    } catch (_) {
      // Preferences are optional; fall back to the default URL.
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().isEmpty ? defaultBaseUrl : _trim(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey, _baseUrl);
    } catch (_) {}
  }

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isNotEmpty) params[key] = text;
    });
    final uri = Uri.parse('$_baseUrl$path');
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> get(String path, [Map<String, Object?>? query]) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send(
    () => _client.post(
      _uri(path),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Map<String, dynamic>> patch(String path, Object body) => _send(
    () => _client.patch(_uri(path), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(body)),
  );

  Future<Map<String, dynamic>> delete(String path, [Map<String, Object?>? query]) =>
      _send(() => _client.delete(_uri(path, query), headers: _headers));

  /// Sends event data as multipart (JSON in `data`, optional `image` file), matching the
  /// server's event endpoints.
  Future<Map<String, dynamic>> multipart(String method, String path, Map<String, dynamic> data, {UploadFile? image}) {
    return _send(() async {
      final request = http.MultipartRequest(method, _uri(path))
        ..headers.addAll(_headers)
        ..fields['data'] = jsonEncode(data);
      if (image != null) {
        request.files.add(http.MultipartFile.fromBytes('image', image.bytes, filename: image.name));
      }
      return http.Response.fromStream(await _client.send(request));
    }, timeout: const Duration(seconds: 60));
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } catch (_) {
      throw ApiException('Cannot reach the EventBook server at $_baseUrl. Is the backend running?');
    }
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Non-JSON error pages fall through to the status-code message.
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final error = ApiException(
      body['error']?.toString() ?? 'Request failed (${response.statusCode}).',
      statusCode: response.statusCode,
    );
    // Admin routes only answer 401/403 when the session itself is no longer valid.
    if (error.isAuthError && _token != null) onUnauthorized?.call();
    throw error;
  }
}
