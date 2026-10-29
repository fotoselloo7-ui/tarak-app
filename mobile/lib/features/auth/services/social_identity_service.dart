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

  const SocialIdentityCredential({
    required this.provider,
    required this.idToken,
    required this.nonce,
    this.authorizationCode,
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
  final ApiClient api;
  SocialIdentityService(this.api);

  Future<String> _nonce() async {
    final response = await api.get('/auth/social/nonce');
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final nonce = data is Map ? data['nonce']?.toString() : null;
    if (nonce == null || nonce.isEmpty) {
      throw const AppException(message: 'Güvenli giriş başlatılamadı. Lütfen tekrar deneyin.');
    }
    return nonce;
  }

  Future<SocialIdentityCredential> acquire(String provider) async {
    final nonce = await _nonce();
    if (provider == 'google') {
      const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
      const serverClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '977885914941-lts9n172clgr8p6glbi3gv1k2qn2fkvn.apps.googleusercontent.com',
      );
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          clientId.isEmpty) {
        throw const AppException(
          message: 'Google girişi iOS için henüz yapılandırılmadı.',
        );
      }
      final signIn = GoogleSignIn.instance;
      // The Google SDK must be initialized exactly once. Native clients use
      // the verified ID token plus the backend's one-use request nonce; a
      // per-request SDK nonce cannot be changed after initialization.
      await (_googleInitialization ??= signIn.initialize(
        clientId: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            ? clientId
            : null,
        serverClientId: serverClientId,
      ));
      if (!signIn.supportsAuthenticate()) {
        throw const AppException(message: 'Google girişi bu cihazda kullanılamıyor.');
      }
      await signIn.signOut();
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AppException(message: 'Google kimlik doğrulama belirteci alınamadı.');
      }
      return SocialIdentityCredential(provider: provider, idToken: token, nonce: nonce);
    }

    if (provider == 'apple') {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        throw const AppException(message: 'Apple ile giriş bu cihaz için henüz yapılandırılmadı.');
      }
      if (!await SignInWithApple.isAvailable()) {
        throw const AppException(message: 'Apple ile giriş bu cihazda kullanılamıyor.');
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.fullName, AppleIDAuthorizationScopes.email],
        nonce: nonce,
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty || credential.authorizationCode.isEmpty) {
        throw const AppException(message: 'Apple kimlik bilgisi alınamadı.');
      }
      return SocialIdentityCredential(
        provider: provider,
        idToken: token,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
      );
    }
    throw const AppException(message: 'Bilinmeyen giriş sağlayıcısı.');
  }
}
