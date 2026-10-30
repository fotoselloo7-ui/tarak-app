import 'dart:async';
import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Storage implements FlutterSecureStorage {
  final values = <String, String>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.namedArguments;
    if (invocation.memberName == #read) return Future<String?>.value(values[args[#key]]);
    if (invocation.memberName == #write) {
      values[args[#key] as String] = args[#value] as String;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream, Future<void>? cancel) {
    requests.add(Map<String, dynamic>.from(options.data as Map));
    if (!started.isCompleted) started.complete();
    return response.future;
  }
  void finish({String role = 'CUSTOMER', bool error = false}) {
    response.complete(ResponseBody.fromString(jsonEncode(error ? {
      'message': 'Girdiğiniz bilgileri kontrol edin.', 'errors': {'email': ['Bu e-posta adresi zaten kullanımda.']},
    } : {
      'success': true, 'data': {'token': 'registration-test-token', 'user': {'id': 1, 'role': role, 'name': 'Ayşe Test'}},
    }), error ? 422 : 201, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
  }
  @override
  void close({bool force = false}) {}
}

class _Push extends PushNotificationService {
  _Push({required super.apiClient, required super.storage});
  @override
  Future<void> registerDevice() async {}
  @override
  Future<void> requestPermissions() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecureStorageService storage;
  late _Adapter adapter;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SecureStorageService(secureStorage: _Storage());
    await storage.init();
    adapter = _Adapter();
    final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter);
    container = ProviderContainer(overrides: [authNotifierProvider.overrideWith(() => AuthNotifier(
      storage: storage, apiClient: api, pushService: _Push(apiClient: api, storage: storage),
    ))]);
  });
  tearDown(() => container.dispose());

  Future<bool> register({String role = 'CUSTOMER', String? socialProof, String? emailProof}) =>
    container.read(authNotifierProvider.notifier).register(firstName: ' Ayşe ', lastName: ' Test ',
      role: role, email: 'new@example.test', password: 'safe-password-123', passwordConfirmation: 'safe-password-123',
      businessName: role == 'PROVIDER' ? ' Test Salon ' : null, socialPrefillToken: socialProof,
      emailVerificationToken: emailProof, acceptTerms: true, acceptKvkk: true);

  test('two immediate registration submissions produce only one HTTP request', () async {
    final first = register(emailProof: 'email-proof');
    await adapter.started.future;
    expect(await register(emailProof: 'email-proof'), isFalse);
    expect(adapter.requests, hasLength(1));
    adapter.finish(error: true);
    expect(await first, isFalse);
    expect(await storage.getToken(), isNull);
  });

  test('verified normal registration sends consent and proof and persists its session', () async {
    final result = register(emailProof: 'email-proof');
    await adapter.started.future;
    expect(adapter.requests.single, containsPair('email_verification_token', 'email-proof'));
    expect(adapter.requests.single['first_name'], 'Ayşe');
    expect(adapter.requests.single['last_name'], 'Test');
    expect(adapter.requests.single['accept_terms'], isTrue);
    expect(adapter.requests.single['accept_kvkk'], isTrue);
    adapter.finish();
    expect(await result, isTrue);
    expect(await storage.getToken(), 'registration-test-token');
    expect(container.read(authNotifierProvider).isCustomer, isTrue);
  });

  test('social provider registration carries social proof without requesting email OTP', () async {
    final result = register(role: 'PROVIDER', socialProof: 'verified-social-proof');
    await adapter.started.future;
    expect(adapter.requests.single['social_prefill_token'], 'verified-social-proof');
    expect(adapter.requests.single.containsKey('email_verification_token'), isFalse);
    expect(adapter.requests.single['business_name'], 'Test Salon');
    adapter.finish(role: 'PROVIDER');
    expect(await result, isTrue);
    expect(container.read(authNotifierProvider).isProvider, isTrue);
  });

  test('server validation errors survive and clear the loading state', () async {
    final result = register();
    await adapter.started.future;
    adapter.finish(error: true);
    expect(await result, isFalse);
    expect(container.read(authNotifierProvider).errorMessage, 'Bu e-posta adresi zaten kullanımda.');
    expect(container.read(authNotifierProvider).isLoading, isFalse);
    expect(await storage.getToken(), isNull);
  });
}
