import 'dart:async';
import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/login_screen.dart';
import 'package:app/features/auth/screens/register_screen.dart';
import 'package:app/features/auth/services/social_identity_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Exercise the installed Google SDK through its existing platform test seam.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class _GooglePlatform extends GoogleSignInPlatform {
  final calls = <String>[];
  final initializations = <InitParameters>[];
  String selectedAccount = 'first';
  bool cancel = false;

  @override
  Stream<AuthenticationEvent> get authenticationEvents => const Stream.empty();

  @override
  Future<void> init(InitParameters params) async {
    initializations.add(params);
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<void> signOut(SignOutParams params) async {
    calls.add('signOut');
  }

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async {
    calls.add('authenticate');
    if (cancel) {
      throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
    }
    return AuthenticationResults(
      user: GoogleSignInUserData(email: '$selectedAccount@example.test', id: selectedAccount),
      authenticationTokens: AuthenticationTokenData(idToken: 'signed-$selectedAccount'),
    );
  }

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
      AttemptLightweightAuthenticationParameters params) {
    calls.add('lightweight');
    throw StateError('Manual actions must never restore an account silently.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthApi implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancel) async {
    paths.add(options.path);
    final Map<String, dynamic> data;
    if (options.path == '/auth/social/nonce') {
      data = {'nonce': 'nonce-${paths.length}'};
    } else if (options.path == '/auth/social/config') {
      data = {'google_client_id': 'server-test-client', 'google_ios_client_id': 'ios-test-client'};
    } else if (options.path == '/auth/verification/config') {
      data = {'sms_enabled': false};
    } else {
      throw StateError('Canceled picker must not submit ${options.path}');
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': data}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousPlatform = GoogleSignInPlatform.instance;
  final google = _GooglePlatform();

  setUpAll(() => GoogleSignInPlatform.instance = google);
  tearDownAll(() => GoogleSignInPlatform.instance = previousPlatform);

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    google.calls.clear();
    google.cancel = false;
    google.selectedAccount = 'first';
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  ApiClient client(_AuthApi adapter) => ApiClient(
      storage: SecureStorageService(), customDio: Dio()..httpClientAdapter = adapter);

  test('every manual action signs out then opens interactive selection; accounts can change', () async {
    final api = client(_AuthApi());
    final identity = SocialIdentityService(api);
    final first = await identity.acquire('google');
    google.selectedAccount = 'second';
    final second = await identity.acquire('google');
    expect(first.idToken, 'signed-first');
    expect(second.idToken, 'signed-second');
    expect(first.nonce, isNot(second.nonce));
    expect(google.calls, ['signOut', 'authenticate', 'signOut', 'authenticate']);
    expect(google.initializations, hasLength(1));
    expect(google.initializations.single.clientId, 'ios-test-client');
    expect(google.initializations.single.serverClientId, 'server-test-client');
  });

  test('cancel becomes a Turkish error and releases the acquisition guard for retry', () async {
    final adapter = _AuthApi();
    final identity = SocialIdentityService(client(adapter));
    google.cancel = true;
    await expectLater(identity.acquire('google'), throwsA(isA<AppException>()
        .having((error) => error.message, 'message', 'Google ile giriş iptal edildi.')));
    google.cancel = false;
    expect((await identity.acquire('google')).idToken, 'signed-first');
    expect(google.calls, ['signOut', 'authenticate', 'signOut', 'authenticate']);
    expect(adapter.paths.any((path) => path.endsWith('/login') || path.endsWith('/prefill')), isFalse);
  });

  for (final register in [false, true]) {
    testWidgets('${register ? 'register' : 'login'} cancellation shows Turkish error without backend submission', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = _AuthApi();
      final api = client(adapter);
      google.cancel = true;
      await tester.pumpWidget(ProviderScope(overrides: [
        apiClientProvider.overrideWithValue(api),
        socialIdentityServiceProvider.overrideWithValue(SocialIdentityService(api)),
      ], child: MaterialApp(home: register ? const RegisterScreen() : const LoginScreen())));
      await tester.pumpAndSettle();
      final button = find.text(register ? 'Google ile doldur' : 'Google ile giriş');
      await tester.ensureVisible(button);
      await tester.runAsync(() async {
        await tester.tap(button);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(find.text('Google ile giriş iptal edildi.'), findsOneWidget);
      expect(google.calls, ['signOut', 'authenticate']);
      expect(adapter.paths.any((path) => path.endsWith('/login') || path.endsWith('/prefill')), isFalse);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.tap(button);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(google.calls, ['signOut', 'authenticate', 'signOut', 'authenticate']);
      expect(adapter.paths.any((path) => path.endsWith('/login') || path.endsWith('/prefill')), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android ${register ? 'register' : 'login'} keeps Apple button hidden', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final api = client(_AuthApi());
      await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp(home: register ? const RegisterScreen() : const LoginScreen())));
      await tester.pumpAndSettle();
      expect(find.textContaining('Apple ile'), findsNothing);
      expect(find.byIcon(Icons.apple), findsNothing);
      expect(find.text(register ? 'Google ile doldur' : 'Google ile giriş'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
