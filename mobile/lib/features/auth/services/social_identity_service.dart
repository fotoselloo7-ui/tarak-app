import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class SocialIdentityCredential {
  final String provider;
  final String idToken;
  final String nonce;
  final String? authorizationCode;
  final String? firstName;
  final String? lastName;

  const SocialIdentityCredential({
    required this.provider,
    required this.idToken,
    required this.nonce,
    this.authorizationCode,
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toJson() => {
    'id_token': idToken,
    'nonce': nonce,
    if (authorizationCode != null) 'authorization_code': authorizationCode,
  };
}

/// Obtains a provider credential without creating a Tarak account or session.
class SocialIdentityService {
  static Future<void>? _googleInitialization;
  static bool _acquiring = false;
  final ApiClient api;
  SocialIdentityService(this.api);

  Future<String> _nonce() async {
    final response = await api.get('/auth/social/nonce');
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final nonce = data is Map ? data['nonce']?.toString() : null;
    if (nonce == null || nonce.isEmpty) {
      throw const AppException(
        message: 'Güvenli giriş başlatılamadı. Lütfen tekrar deneyin.',
      );
    }
    return nonce;
  }

  Future<SocialIdentityCredential> acquire(String provider) async {
    if (_acquiring) {
      throw const AppException(
        message: 'Giriş işlemi devam ediyor. Lütfen bekleyin.',
      );
    }
    _acquiring = true;
    try {
      return await _acquire(provider);
    } finally {
      _acquiring = false;
    }
  }

  Future<SocialIdentityCredential> _acquire(String provider) async {
    final nonce = await _nonce();
    if (provider == 'google') {
      const configuredClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
      const configuredServerClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
      );
      String? clientId = configuredClientId.isEmpty ? null : configuredClientId;
      String? serverClientId = configuredServerClientId.isEmpty
          ? null
          : configuredServerClientId;
      if (_googleInitialization == null &&
          (serverClientId == null ||
              (defaultTargetPlatform == TargetPlatform.iOS &&
                  clientId == null))) {
        final response = await api.get('/auth/social/config');
        final data = response.data is Map ? response.data['data'] : null;
        if (data is Map) {
          serverClientId ??= data['google_client_id']?.toString();
          clientId ??= data['google_ios_client_id']?.toString();
        }
      }
      if (_googleInitialization == null &&
          (serverClientId == null || serverClientId.isEmpty)) {
        throw const AppException(
          message: 'Google web istemci kimliği yapılandırılmadı.',
        );
      }
      final signIn = GoogleSignIn.instance;
      // The Google SDK must be initialized exactly once. Native clients use
      // the verified ID token plus the backend's one-use request nonce; a
      // per-request SDK nonce cannot be changed after initialization.
      try {
        await (_googleInitialization ??= signIn.initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? clientId
              : null,
          serverClientId: serverClientId,
        ));
      } catch (_) {
        _googleInitialization = null;
        rethrow;
      }
      if (!signIn.supportsAuthenticate()) {
        throw const AppException(
          message: 'Google girişi bu cihazda kullanılamıyor.',
        );
      }
      await signIn.signOut();
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AppException(
          message: 'Google kimlik doğrulama belirteci alınamadı.',
        );
      }
      return SocialIdentityCredential(
        provider: provider,
        idToken: token,
        nonce: nonce,
      );
    }

    if (provider == 'apple') {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        throw const AppException(
          message: 'Apple ile giriş bu cihaz için henüz yapılandırılmadı.',
        );
      }
      if (!await SignInWithApple.isAvailable()) {
        throw const AppException(
          message: 'Apple ile giriş bu cihazda kullanılamıyor.',
        );
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.fullName,
          AppleIDAuthorizationScopes.email,
        ],
        nonce: nonce,
      );
      final token = credential.identityToken;
      if (token == null ||
          token.isEmpty ||
          credential.authorizationCode.isEmpty) {
        throw const AppException(message: 'Apple kimlik bilgisi alınamadı.');
      }
      return SocialIdentityCredential(
        provider: provider,
        idToken: token,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
    }
    throw const AppException(message: 'Bilinmeyen giriş sağlayıcısı.');
  }
}
