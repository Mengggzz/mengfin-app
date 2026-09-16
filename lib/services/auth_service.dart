import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/config.dart';
import '../utils/web_auth_stub.dart'
    if (dart.library.html) '../utils/web_auth_web.dart' as webAuth;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userKey  = 'auth_user';

  final _googleSignIn = GoogleSignIn(
    // Web: pakai clientId untuk OAuth popup/redirect
    clientId: kIsWeb ? kGoogleClientId : null,
    // Android: serverClientId diperlukan agar idToken tersedia
    serverClientId: kIsWeb ? null : kGoogleClientId,
    scopes: ['email', 'profile'],
  );

  String? _token;
  Map<String, dynamic>? _user;

  final _loginResult = StreamController<bool>.broadcast();
  Stream<bool> get onLoginResult => _loginResult.stream;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null;

  /// Init: load JWT dari storage + proses callback OAuth (jika ada)
  Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try { _user = jsonDecode(userStr); } catch (_) {}
    }

    if (kIsWeb && _token == null) {
      // Cek apakah ada access token dari Google redirect callback
      final accessToken = webAuth.checkPendingToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        webAuth.clearPendingToken();
        await _processWebAccessToken(accessToken);
      }
    }

    return _token != null;
  }

  /// Proses access token yang didapat dari Google redirect
  Future<void> _processWebAccessToken(String accessToken) async {
    try {
      // Ambil info user dari Google UserInfo API
      final userInfoRes = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (userInfoRes.statusCode != 200) {
        print('UserInfo error: ${userInfoRes.body}');
        return;
      }
      final userInfo = jsonDecode(userInfoRes.body) as Map<String, dynamic>;

      // Kirim ke backend → dapat JWT
      await _postToAuth({
        'accessToken': accessToken,
        'googleId':    userInfo['sub']     ?? '',
        'email':       userInfo['email']   ?? '',
        'nama':        userInfo['name']    ?? '',
        'foto':        userInfo['picture'] ?? '',
      });
    } catch (e) {
      print('Process web token error: $e');
    }
  }

  /// Trigger sign-in:
  /// - Web: redirect ke Google (tidak ada popup, tidak bisa diblock)
  /// - Mobile: pakai google_sign_in package
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) {
      // Redirect ke Google OAuth → tidak ada return value langsung
      // Setelah login, page reload → init() akan proses tokennya
      webAuth.triggerGoogleSignIn();
      return false;
    } else {
      try {
        final account = await _googleSignIn.signIn();
        if (account == null) return false;
        final auth = await account.authentication;
        if (auth.idToken == null) throw Exception('No ID token');
        return await _postToAuth({'idToken': auth.idToken!});
      } catch (e) {
        print('Mobile sign-in error: $e');
        rethrow;
      }
    }
  }

  Future<bool> _postToAuth(Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) {
        print('Backend error ${res.statusCode}: ${res.body}');
        return false;
      }
      final data = jsonDecode(res.body);
      _token = data['token'] as String;
      _user  = data['user']  as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userKey,  jsonEncode(_user));
      return true;
    } catch (e) {
      print('Auth post error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    _token = null;
    _user  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  void dispose() => _loginResult.close();
}
