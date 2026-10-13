import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Holds the signed-in admin and their token, persisted across launches.
class Session extends ChangeNotifier {
  Session() {
    AdminApi.instance.onUnauthorized = () => signOut(message: 'Your admin session ended. Sign in again.');
  }

  static const _tokenKey = 'admin_token';

  SessionStatus status = SessionStatus.loading;
  AdminUser? admin;
  String? notice;

  Future<void> restore() async {
    await AdminApi.instance.loadBaseUrl();
    String? token;
    try {
      token = (await SharedPreferences.getInstance()).getString(_tokenKey);
    } catch (_) {}
    if (token == null) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    AdminApi.instance.token = token;
    try {
      final data = await AdminApi.instance.get('/api/admin/auth/me');
      admin = AdminUser.fromJson(data['admin']);
      status = SessionStatus.signedIn;
    } on ApiException catch (error) {
      if (error.isAuthError) await _clearToken();
      AdminApi.instance.token = error.isAuthError ? null : token;
      // Keep a still-valid token when the server is just unreachable; the login screen
      // explains the problem and signing in again replaces it.
      status = SessionStatus.signedOut;
      notice = error.isAuthError ? null : error.message;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final data = await AdminApi.instance.post('/api/admin/auth/login', {'email': email.trim(), 'password': password});
    await _storeToken(data['token'] as String);
    admin = AdminUser.fromJson(data['admin']);
    notice = null;
    status = SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) async {
    final data = await AdminApi.instance.post('/api/admin/auth/password', {
      'currentPassword': current,
      'newPassword': next,
    });
    await _storeToken(data['token'] as String);
  }

  Future<void> signOut({String? message}) async {
    if (status == SessionStatus.signedOut) return;
    await _clearToken();
    admin = null;
    notice = message;
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> _storeToken(String token) async {
    AdminApi.instance.token = token;
    try {
      await (await SharedPreferences.getInstance()).setString(_tokenKey, token);
    } catch (_) {}
  }

  Future<void> _clearToken() async {
    AdminApi.instance.token = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_tokenKey);
    } catch (_) {}
  }
}
