import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../l10n/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ids.dart';
import '../models/oauth_config.dart';

class AuthSession {
  const AuthSession({
    required this.email,
    required this.client,
    this.fromGoogleSignIn = false,
  });

  final String? email;
  final http.Client client;
  final bool fromGoogleSignIn;
}

/// Android는 google_sign_in, 데스크톱은 루프백 OAuth(googleapis_auth).
class AuthService {
  AuthService({required this.config, this._prefs});

  final OauthConfig config;
  SharedPreferences? _prefs;

  static const _credKey = 'drive_oauth_credentials';
  static const _emailKey = 'drive_oauth_email';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', DriveConstants.driveScope],
    serverClientId: _nonEmpty(config.serverClientId),
  );

  AuthSession? _session;

  AuthSession? get session => _session;

  bool get isSignedIn => _session != null;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  bool get canSignIn {
    if (isAndroid) return true;
    return config.hasDesktop;
  }

  Future<void> restore() async {
    if (isAndroid) {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return;
      _session = AuthSession(
        email: account.email,
        client: _HeaderClient(await account.authHeaders),
        fromGoogleSignIn: true,
      );
      return;
    }
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_credKey);
    if (raw == null || !config.hasDesktop) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final creds = _credentialsFromJson(map);
      final id = ClientId(config.desktopClientId!, config.desktopClientSecret);
      final client = autoRefreshingClient(id, creds, http.Client());
      _session = AuthSession(
        email: _prefs!.getString(_emailKey),
        client: client,
      );
    } catch (_) {
      await _prefs!.remove(_credKey);
    }
  }

  Future<AuthSession> signIn() async {
    if (isAndroid) {
      try {
        final account = await _googleSignIn.signIn();
        if (account == null) {
          throw AuthCancelled();
        }
        _session = AuthSession(
          email: account.email,
          client: _HeaderClient(await account.authHeaders),
          fromGoogleSignIn: true,
        );
        return _session!;
      } on PlatformException catch (e) {
        if (isGoogleSignInDeveloperError(e)) {
          throw AuthDeveloperError();
        }
        rethrow;
      }
    }

    if (!config.hasDesktop) {
      throw AuthConfigMissing();
    }

    final id = ClientId(config.desktopClientId!, config.desktopClientSecret);
    final client = http.Client();
    try {
      final credentials = await obtainAccessCredentialsViaUserConsent(
        id,
        const [DriveConstants.driveScope, 'email'],
        client,
        (url) async {
          final uri = Uri.parse(url);
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok) {
            throw AuthException('브라우저를 열 수 없습니다: $url');
          }
        },
      );
      final refreshing = autoRefreshingClient(id, credentials, http.Client());
      String? email;
      try {
        final res = await refreshing.get(
          Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        );
        if (res.statusCode == 200) {
          email = (jsonDecode(res.body) as Map<String, dynamic>)['email']
              as String?;
        }
      } catch (_) {}

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_credKey, jsonEncode(_credentialsToJson(credentials)));
      if (email != null) await _prefs!.setString(_emailKey, email);

      _session = AuthSession(email: email, client: refreshing);
      return _session!;
    } finally {
      client.close();
    }
  }

  Future<void> signOut() async {
    if (isAndroid) {
      await _googleSignIn.signOut();
    }
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_credKey);
    await _prefs!.remove(_emailKey);
    _session?.client.close();
    _session = null;
  }

  Map<String, dynamic> _credentialsToJson(AccessCredentials c) {
    return {
      'accessToken': c.accessToken.data,
      'tokenType': c.accessToken.type,
      'expiry': c.accessToken.expiry.toUtc().toIso8601String(),
      'refreshToken': c.refreshToken,
      'scopes': c.scopes,
      'idToken': c.idToken,
    };
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }

  AccessCredentials _credentialsFromJson(Map<String, dynamic> json) {
    return AccessCredentials(
      AccessToken(
        json['tokenType'] as String? ?? 'Bearer',
        json['accessToken'] as String,
        DateTime.parse(json['expiry'] as String).toUtc(),
      ),
      json['refreshToken'] as String?,
      (json['scopes'] as List<dynamic>? ?? [DriveConstants.driveScope])
          .map((e) => '$e')
          .toList(),
      idToken: json['idToken'] as String?,
    );
  }
}

class _HeaderClient extends http.BaseClient {
  _HeaderClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class AuthCancelled implements Exception {}

class AuthConfigMissing implements Exception {}

class AuthDeveloperError implements Exception {
  @override
  String toString() => S.signInDeveloperError;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `PlatformException(sign_in_failed, … 10 …)` — Google Sign-In DEVELOPER_ERROR.
bool isGoogleSignInDeveloperError(PlatformException e) {
  final blob = '${e.code} ${e.message} ${e.details}'.toLowerCase();
  if (blob.contains('developer_error')) return true;
  if (e.code == '10') return true;
  if (e.code == 'sign_in_failed' &&
      RegExp(r'(^|[^0-9])10([^0-9]|$)').hasMatch(blob)) {
    return true;
  }
  return false;
}
