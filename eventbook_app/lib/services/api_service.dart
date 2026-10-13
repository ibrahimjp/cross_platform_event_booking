import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The session is no longer valid (expired token, suspended account, ...).
  bool get isAuthError => statusCode == 401 || statusCode == 403 && message.toLowerCase().contains('suspend');

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static const _prefsKey = 'apiBaseUrl';
  static const _prefsDefaultKey = 'apiBaseUrlDefault';
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');

  /// BACKEND_URI from eventbook_app/.env, then --dart-define=API_BASE_URL, then a local server.
  static String get defaultBaseUrl {
    final fromEnv = (dotenv.isInitialized ? dotenv.env['BACKEND_URI'] : null)?.trim() ?? '';
    if (fromEnv.isNotEmpty) return _normalize(fromEnv);
    final configured = _configuredUrl.trim();
    if (configured.isNotEmpty) return _normalize(configured);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static String _baseUrl = defaultBaseUrl;
  static String get baseUrl => _baseUrl;

  static String _normalize(String url) {
    var value = url.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!value.startsWith('http://') && !value.startsWith('https://')) value = 'http://$value';
    return value;
  }

  static Future<void> loadSavedBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_prefsKey);
    // A manual override only applies while .env still points at the backend it was made against.
    if (preferences.getString(_prefsDefaultKey) != defaultBaseUrl) return;
    if (saved != null && saved.trim().isNotEmpty) _baseUrl = _normalize(saved);
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().isEmpty ? defaultBaseUrl : _normalize(url);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_prefsKey, _baseUrl);
    await preferences.setString(_prefsDefaultKey, defaultBaseUrl);
  }

  /// Returns null when the server is reachable, otherwise an error message.
  static Future<String?> testConnection(String url) async {
    try {
      final response = await http.get(Uri.parse('${_normalize(url)}/health')).timeout(const Duration(seconds: 6));
      return response.statusCode == 200 ? null : 'Server answered with status ${response.statusCode}.';
    } catch (_) {
      return 'Could not reach ${_normalize(url)}. Check the address and that the phone is on the same Wi-Fi.';
    }
  }

  static final _client = http.Client();
  static const _timeout = Duration(seconds: 25);

  static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  static Map<String, String> _headers(String? token, {bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    late http.Response response;
    try {
      response = await call().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('The server took too long to respond. Please try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        'Could not reach the EventBook server at $_baseUrl. Make sure the backend is running and this device is on the same network.',
      );
    }
    if (response.statusCode == 204) return {};
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException('The server returned an invalid response (${response.statusCode}).', statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic> ? decoded['error'] as String? : null;
      throw ApiException(message ?? 'The request failed (${response.statusCode}).', statusCode: response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) throw const ApiException('The server returned an unexpected response.');
    return decoded;
  }

  static Future<Map<String, dynamic>> _request(String method, String path, {String? token, Object? body}) {
    final headers = _headers(token);
    final encoded = body == null ? null : jsonEncode(body);
    return _send(() {
      switch (method) {
        case 'GET':
          return _client.get(_uri(path), headers: headers);
        case 'POST':
          return _client.post(_uri(path), headers: headers, body: encoded ?? '{}');
        case 'PATCH':
          return _client.patch(_uri(path), headers: headers, body: encoded ?? '{}');
        case 'DELETE':
          return _client.delete(_uri(path), headers: headers);
      }
      throw StateError('Unsupported HTTP method: $method');
    });
  }

  static MediaType _mediaType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      'heic' || 'heif' => MediaType('image', 'heic'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  static Future<Map<String, dynamic>> _multipart(
    String method,
    String path, {
    required String token,
    Map<String, String> fields = const {},
    String fileField = 'image',
    ImageUpload? file,
  }) {
    return _send(() async {
      final request = http.MultipartRequest(method, _uri(path))
        ..headers.addAll(_headers(token, json: false))
        ..fields.addAll(fields);
      if (file != null) {
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          file.bytes,
          filename: file.filename,
          contentType: _mediaType(file.filename),
        ));
      }
      return http.Response.fromStream(await _client.send(request));
    });
  }

  // ---- Auth & profile ----

  static Future<Map<String, dynamic>> login(String email, String password) =>
      _request('POST', '/api/auth/login', body: {'email': email, 'password': password});

  static Future<Map<String, dynamic>> register(String name, String email, String password) =>
      _request('POST', '/api/auth/register', body: {'name': name, 'email': email, 'password': password});

  static Future<AppUser> me(String token) async =>
      AppUser.fromJson((await _request('GET', '/api/auth/me', token: token))['user'] as Map<String, dynamic>);

  static Future<AppUser> updateProfile(String token, Map<String, Object> fields) async => AppUser.fromJson(
      (await _request('PATCH', '/api/auth/profile', token: token, body: fields))['user'] as Map<String, dynamic>);

  static Future<void> changePassword(String token, String currentPassword, String newPassword) =>
      _request('POST', '/api/auth/password', token: token, body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  static Future<AppUser> uploadAvatar(String token, ImageUpload image) async => AppUser.fromJson(
      (await _multipart('POST', '/api/auth/avatar', token: token, fileField: 'avatar', file: image))['user']
          as Map<String, dynamic>);

  static Future<AppUser> removeAvatar(String token) async =>
      AppUser.fromJson((await _request('DELETE', '/api/auth/avatar', token: token))['user'] as Map<String, dynamic>);

  static Future<AppUser> toggleWishlist(String token, String eventId) async => AppUser.fromJson(
      (await _request('POST', '/api/auth/wishlist/${Uri.encodeComponent(eventId)}', token: token))['user']
          as Map<String, dynamic>);

  // ---- Events ----

  static Future<List<Event>> getEvents() async {
    final response = await _request('GET', '/api/events');
    return (response['events'] as List<dynamic>).map((event) => Event.fromJson(event as Map<String, dynamic>)).toList();
  }

  static Future<Event> getEvent(String id) async =>
      Event.fromJson((await _request('GET', '/api/events/${Uri.encodeComponent(id)}'))['event'] as Map<String, dynamic>);

  static Future<Event> createEvent(String token, EventDraft draft, ImageUpload? image) async {
    final response = await _multipart('POST', '/api/events',
        token: token, fields: {'data': jsonEncode(draft.toJson())}, file: image);
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  static Future<Event> updateEvent(String token, String id, EventDraft draft, ImageUpload? image) async {
    final response = await _multipart('PATCH', '/api/events/${Uri.encodeComponent(id)}',
        token: token, fields: {'data': jsonEncode(draft.toJson())}, file: image);
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  static Future<void> deleteEvent(String token, String id) =>
      _request('DELETE', '/api/events/${Uri.encodeComponent(id)}', token: token);

  static Future<List<Event>> getHostedEvents(String token) async {
    final response = await _request('GET', '/api/host/events', token: token);
    return (response['events'] as List<dynamic>).map((event) => Event.fromJson(event as Map<String, dynamic>)).toList();
  }

  static Future<List<Attendee>> getAttendees(String token, String eventId) async {
    final response = await _request('GET', '/api/host/events/${Uri.encodeComponent(eventId)}/bookings', token: token);
    return (response['bookings'] as List<dynamic>)
        .map((booking) => Attendee.fromJson(booking as Map<String, dynamic>))
        .toList();
  }

  // ---- Checkout & bookings ----

  static Future<Map<String, dynamic>> quote(String token,
          {required String eventId, required Map<String, int> quantities, required String promoCode}) =>
      _request('POST', '/api/payments/quote',
          token: token, body: {'eventId': eventId, 'quantities': quantities, 'promoCode': promoCode});

  static Future<CheckoutStart> startCheckout(String token,
      {required String eventId, required Map<String, int> quantities, required String promoCode}) async {
    final response = await _request('POST', '/api/payments/checkout',
        token: token, body: {'eventId': eventId, 'quantities': quantities, 'promoCode': promoCode});
    if (response['requiresPayment'] == false) {
      return CheckoutStart(booking: Booking.fromJson(response['booking'] as Map<String, dynamic>));
    }
    return CheckoutStart(sessionId: response['sessionId'] as String, url: response['url'] as String);
  }

  static Future<bool> testPaymentsEnabled() async =>
      (await _request('GET', '/api/payments/config'))['testPaymentsEnabled'] == true;

  /// Demo checkout: books the tickets without charging a card (server must allow test payments).
  static Future<Booking> testCheckout(String token,
      {required String eventId, required Map<String, int> quantities, required String promoCode}) async {
    final response = await _request('POST', '/api/payments/test-checkout',
        token: token, body: {'eventId': eventId, 'quantities': quantities, 'promoCode': promoCode});
    return Booking.fromJson(response['booking'] as Map<String, dynamic>);
  }

  static Future<CheckoutStatus> checkoutStatus(String token, String sessionId) async {
    final response = await _request('GET', '/api/payments/checkout/${Uri.encodeComponent(sessionId)}', token: token);
    final booking = response['booking'];
    return CheckoutStatus(
      status: response['status'] as String? ?? 'pending',
      message: response['message'] as String?,
      booking: booking is Map<String, dynamic> && booking['eventId'] is Map ? Booking.fromJson(booking) : null,
    );
  }

  static Future<List<Booking>> getBookings(String token) async {
    final response = await _request('GET', '/api/bookings', token: token);
    return (response['bookings'] as List<dynamic>)
        .where((booking) => (booking as Map<String, dynamic>)['eventId'] is Map)
        .map((booking) => Booking.fromJson(booking as Map<String, dynamic>))
        .toList();
  }

  static Future<Booking> cancelBooking(String token, String bookingId) async {
    final response = await _request('POST', '/api/bookings/${Uri.encodeComponent(bookingId)}/cancel', token: token);
    return Booking.fromJson(response['booking'] as Map<String, dynamic>);
  }

  // ---- Saved cards ----

  static Future<String> createCardSetupUrl(String token) async =>
      (await _request('POST', '/api/payments/setup', token: token))['url'] as String;

  static Future<List<SavedCard>> getPaymentMethods(String token) async {
    final response = await _request('GET', '/api/payments/methods', token: token);
    return (response['methods'] as List<dynamic>).map((m) => SavedCard.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<void> removePaymentMethod(String token, String id) =>
      _request('DELETE', '/api/payments/methods/${Uri.encodeComponent(id)}', token: token);
}
