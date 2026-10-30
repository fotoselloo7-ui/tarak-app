import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/register_screen.dart';
import 'package:app/features/auth/services/social_identity_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends SocialIdentityService {
  _Identity(super.api);
  @override
  Future<SocialIdentityCredential> acquire(String provider) async => SocialIdentityCredential(
    provider: provider, idToken: 'test-signed-credential', nonce: 'test-nonce',
  );
}

class _RegistrationApi implements HttpClientAdapter {
  final paths = <String>[];
  Map<String, dynamic>? registration;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream, Future<void>? cancel) async {
    paths.add(options.path);
    final Map<String, dynamic> body;
    var status = 200;
    if (options.path.endsWith('/prefill')) {
      body = {'data': {'first_name': 'Ayşe', 'last_name': 'Test', 'email': 'new@example.test',
        'email_verified': true, 'social_prefill_token': 'verified-social-proof'}};
    } else if (options.path == '/auth/register') {
      registration = Map<String, dynamic>.from(options.data as Map);
      body = {'message': 'Bu e-posta adresi zaten kullanımda.', 'errors': {'email': ['Bu e-posta adresi zaten kullanımda.']}};
      status = 422;
    } else {
      body = {'data': {'sms_enabled': false}};
    }
    return ResponseBody.fromString(jsonEncode(body), status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  Future<_RegistrationApi> prefill(WidgetTester tester) async {
    // The test Ahem font is wider than the production font; this checks form behavior.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = _RegistrationApi();
    final api = ApiClient(storage: SecureStorageService(), customDio: Dio()..httpClientAdapter = adapter);
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api), socialIdentityServiceProvider.overrideWithValue(_Identity(api)),
    ], child: const MaterialApp(home: RegisterScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google ile doldur'));
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('Google fills first name surname email and verified email needs no second code', (tester) async {
    final adapter = await prefill(tester);
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller?.text, 'Ayşe');
    expect(fields[1].controller?.text, 'Test');
    expect(fields[2].controller?.text, 'new@example.test');
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(4), 'safe-password-123');
    await tester.enterText(find.byType(TextFormField).at(5), 'safe-password-123');
    for (var index = 0; index < 2; index++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(index));
      await tester.tap(find.byType(CheckboxListTile).at(index));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Müşteri Olarak Kaydol'));
    await tester.tap(find.text('Müşteri Olarak Kaydol'));
    await tester.pumpAndSettle();
    expect(adapter.registration?['social_prefill_token'], 'verified-social-proof');
    expect(adapter.registration?.containsKey('email_verification_token'), isFalse);
    expect(adapter.paths.any((path) => path.contains('/verification/email/send')), isFalse);
    expect(find.text('Bu e-posta adresi zaten kullanımda.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing a verified Google email restores verification and blocks unverified submission', (tester) async {
    final adapter = await prefill(tester);
    await tester.enterText(find.byType(TextFormField).at(2), 'changed@example.test');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('Kod gönder'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(4), 'safe-password-123');
    await tester.enterText(find.byType(TextFormField).at(5), 'safe-password-123');
    for (var index = 0; index < 2; index++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(index));
      await tester.tap(find.byType(CheckboxListTile).at(index));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Müşteri Olarak Kaydol'));
    await tester.tap(find.text('Müşteri Olarak Kaydol'));
    await tester.pumpAndSettle();
    expect(adapter.registration, isNull);
    expect(find.text('E-posta adresinizi doğrulayın.'), findsOneWidget);
  });
}
