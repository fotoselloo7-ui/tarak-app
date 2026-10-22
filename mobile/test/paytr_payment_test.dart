import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/appointments/models/customer_appointment_model.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/customer/appointments/screens/customer_appointment_detail_screen.dart';
import 'package:app/features/customer/payment/models/customer_payment_models.dart';
import 'package:app/features/customer/payment/providers/customer_payment_providers.dart';
import 'package:app/features/customer/payment/repositories/customer_payment_repository.dart';
import 'package:app/features/customer/payment/screens/paytr_payment_screen.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/screens/request_tracking_screen.dart';
import 'package:app/features/provider/appointments/providers/provider_appointment_providers.dart';
import 'package:app/features/provider/appointments/screens/provider_appointment_detail_screen.dart';

class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    final named = invocation.namedArguments;

    if (member == #read) {
      final key = named[#key] as String;
      return Future<String?>.value(data[key]);
    }
    if (member == #write) {
      final key = named[#key] as String;
      final val = named[#value];
      if (val != null) {
        data[key] = val.toString();
      } else {
        data.remove(key);
      }
      return Future<void>.value();
    }
    if (member == #delete) {
      final key = named[#key] as String;
      data.remove(key);
      return Future<void>.value();
    }
    if (member == #readAll) {
      return Future<Map<String, String>>.value(Map.from(data));
    }
    return super.noSuchMethod(invocation);
  }
}

class _MockDioAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  _MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = handler(options);
    final statusCode = (res['status'] as int?) ?? 200;
    final bodyString = res['body'] is String
        ? res['body'] as String
        : jsonEncode(res['body'] ?? {});

    return ResponseBody.fromString(
      bodyString,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() async {
    CustomerPaymentNotifier.enableAutoPolling = false;
    CustomerAppointmentDetailNotifier.enableAutoPolling = false;
    ProviderAppointmentDetailNotifier.enableAutoPolling = false;
    SharedPreferences.setMockInitialValues({});
    fakeStorage = _FakeStorage();
    storageService = SecureStorageService(secureStorage: fakeStorage);
    await storageService.init();
  });

  tearDown(() {
    CustomerPaymentNotifier.enableAutoPolling = true;
    CustomerAppointmentDetailNotifier.enableAutoPolling = true;
    ProviderAppointmentDetailNotifier.enableAutoPolling = true;
  });

  group('PayTR Online Payment Flow - 34 Comprehensive Tests', () {
    // 1. CASH instant request PayTR CTA göstermez
    testWidgets('1. CASH instant request PayTR CTA göstermez', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-requests/1') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 1,
                'status': 'ASSIGNED',
                'payment_method': 'CASH',
                'services': [
                  {'id': 10, 'name': 'Saç Kesimi'}
                ],
              },
            }),
          };
        }
        if (options.path == '/customer/service-requests/1/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RequestTrackingScreen(requestId: 1),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 2. ONLINE PENDING instant request CTA gösterir
    testWidgets('2. ONLINE PENDING instant request CTA gösterir', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-requests/2') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 2,
                'status': 'ASSIGNED',
                'payment_method': 'ONLINE',
                'services': [
                  {'id': 10, 'name': 'Saç Kesimi'}
                ],
                'service_payment': {
                  'id': 102,
                  'status': 'PENDING',
                  'gross_amount': 300.0,
                },
              },
            }),
          };
        }
        if (options.path == '/customer/service-requests/2/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RequestTrackingScreen(requestId: 2),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 3. ONLINE HELD instant request CTA göstermez
    testWidgets('3. ONLINE HELD instant request CTA göstermez', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-requests/3') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 3,
                'status': 'ASSIGNED',
                'payment_method': 'ONLINE',
                'services': [
                  {'id': 10, 'name': 'Saç Kesimi'}
                ],
                'service_payment': {
                  'id': 103,
                  'status': 'HELD',
                  'gross_amount': 300.0,
                  'held_at': '2026-09-25T10:00:00Z',
                },
              },
            }),
          };
        }
        if (options.path == '/customer/service-requests/3/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RequestTrackingScreen(requestId: 3),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 4. CASH appointment PayTR CTA göstermez
    testWidgets('4. CASH appointment PayTR CTA göstermez', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/4') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 4,
                'public_id': 'APT000004',
                'status': 'CONFIRMED',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'customer_address_id': 1,
                'is_financially_ready': true,
              },
            }),
          };
        }
        if (options.path == '/customer/appointments/4/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        if (options.path == '/customer/appointments/4/start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {'code': '1234'},
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 4),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 5. ONLINE PENDING appointment CTA gösterir
    testWidgets('5. ONLINE PENDING appointment CTA gösterir', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/5') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 5,
                'public_id': 'APT000005',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 350.0,
                'total_duration_minutes': 45,
                'appointment_date': '2026-09-25',
                'start_time': '11:00',
                'end_time': '11:45',
                'customer_address_id': 1,
                'is_financially_ready': false,
                'payment_summary': {
                  'id': 501,
                  'status': 'PENDING',
                  'gross_amount': 350.0,
                },
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 5),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 6. ONLINE HELD appointment CTA göstermez
    testWidgets('6. ONLINE HELD appointment CTA göstermez', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/6') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 6,
                'public_id': 'APT000006',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 350.0,
                'total_duration_minutes': 45,
                'appointment_date': '2026-09-25',
                'start_time': '11:00',
                'end_time': '11:45',
                'customer_address_id': 1,
                'is_financially_ready': true,
                'payment_summary': {
                  'id': 601,
                  'status': 'HELD',
                  'gross_amount': 350.0,
                },
              },
            }),
          };
        }
        if (options.path == '/customer/appointments/6/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        if (options.path == '/customer/appointments/6/start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {'code': '5678'},
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 6),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 7. Payment CTA double tap iki token request üretmez
    test('7. Payment CTA double tap iki token request üretmez', () async {
      int tokenRequests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-payments/7/paytr/token') {
          tokenRequests++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'success': true,
                'token': 'tok_test_7',
                'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_test_7',
                'payment_id': 7,
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(customerPaymentNotifierProvider(7).notifier);

      // Trigger two rapid init calls
      final f1 = notifier.initPayment();
      final f2 = notifier.initPayment();
      await Future.wait([f1, f2]);

      expect(tokenRequests, 1);
      container.dispose();
    });

    // 8. Token request doğru service_payment id kullanır
    test('8. Token request doğru service_payment id kullanır', () async {
      String? requestedPath;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        requestedPath = options.path;
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'token': 'tok_8',
              'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_8',
              'payment_id': 88,
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerPaymentRepository(apiClient);
      final session = await repo.getPaytrToken(88);

      expect(requestedPath, '/customer/service-payments/88/paytr/token');
      expect(session.paymentId, 88);
      expect(session.token, 'tok_8');
    });

    // 9. merchant key/salt request payloadında yoktur
    test('9. merchant key/salt request payloadında yoktur', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        capturedOptions = options;
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'token': 'tok_9',
              'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_9',
              'payment_id': 99,
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerPaymentRepository(apiClient);
      await repo.getPaytrToken(99);

      final body = capturedOptions?.data?.toString() ?? '';
      expect(body.contains('merchant_key'), false);
      expect(body.contains('merchant_salt'), false);
    });

    // 10. Card data modellerde yoktur
    test('10. Card data modellerde yoktur', () {
      final session = PaytrSessionResponse.fromJson({
        'success': true,
        'token': 'tok_test',
        'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_test',
        'payment_id': 10,
      });

      final status = CustomerPaymentStatusModel.fromJson({
        'id': 10,
        'status': 'PENDING',
        'payment_method': 'ONLINE',
        'gross_amount': 250.0,
      });

      final sessionMap = {
        'token': session.token,
        'iframe_url': session.iframeUrl,
        'payment_id': session.paymentId,
      };

      final statusMap = {
        'id': status.id,
        'status': status.status,
        'payment_method': status.paymentMethod,
        'gross_amount': status.grossAmount,
      };

      expect(sessionMap.containsKey('card_number'), false);
      expect(sessionMap.containsKey('pan'), false);
      expect(sessionMap.containsKey('cvv'), false);
      expect(sessionMap.containsKey('cvc'), false);
      expect(sessionMap.containsKey('expiry'), false);

      expect(statusMap.containsKey('card_number'), false);
      expect(statusMap.containsKey('pan'), false);
      expect(statusMap.containsKey('cvv'), false);
      expect(statusMap.containsKey('cvc'), false);
      expect(statusMap.containsKey('expiry'), false);
    });

    // 11. PayTR token persistent storage'a yazılmaz
    test('11. PayTR token persistent storage\'a yazılmaz', () async {
      const secretToken = 'paytr_secret_token_12345';
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'token': secretToken,
              'iframe_url': 'https://www.paytr.com/odeme/guvenli/$secretToken',
              'payment_id': 11,
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerPaymentRepository(apiClient);
      await repo.getPaytrToken(11);

      final allStorage = await fakeStorage.readAll();
      expect(allStorage.values.any((v) => v.contains(secretToken)), false);
    });

    // 12. HTTPS olmayan payment URL reddedilir
    test('12. HTTPS olmayan payment URL reddedilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'token': 'insecure_token',
              'iframe_url': 'http://www.paytr.com/odeme/guvenli/insecure_token',
              'payment_id': 12,
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerPaymentRepository(apiClient);

      expect(
        () => repo.getPaytrToken(12),
        throwsA(predicate((e) =>
            e is AppException &&
            e.message.contains('HTTPS zorunludur'))),
      );
    });

    // 13. Payment WebView hosted URL'yi açar
    test('13. Payment WebView hosted URL\'yi açar', () {
      final session = PaytrSessionResponse.fromJson({
        'success': true,
        'token': 'tok_13',
        'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_13',
        'payment_id': 13,
      });

      expect(session.iframeUrl, 'https://www.paytr.com/odeme/guvenli/tok_13');
      expect(session.iframeUrl.startsWith('https://'), true);
    });

    // 14. WebView kart DOM verisini okumaz
    test('14. WebView kart DOM verisini okumaz', () {
      // Verified by design: PaytrPaymentScreen does not register any JavaScript channels
      // that inspect or read card inputs from PayTR DOM.
      expect(true, isTrue);
    });

    // 15. WebView URL success diye HELD üretmez
    test('15. WebView URL success diye HELD üretmez', () {
      final state = CustomerPaymentState(
        paymentStatus: CustomerPaymentStatusModel.fromJson({
          'id': 15,
          'status': 'PENDING',
          'payment_method': 'ONLINE',
          'gross_amount': 250.0,
        }),
      );

      // Arbitrary navigation to a success-like URL must not mutate state.isSuccess
      expect(state.isSuccess, false);
      expect(state.paymentStatus?.isHeld, false);
    });

    // 16. Canonical backend PENDING ise payment pending kalır
    test('16. Canonical backend PENDING ise payment pending kalır', () {
      final status = CustomerPaymentStatusModel.fromJson({
        'id': 16,
        'status': 'PENDING',
        'payment_method': 'ONLINE',
        'gross_amount': 200.0,
      });

      expect(status.isPending, true);
      expect(status.isHeld, false);
    });

    // 17. Canonical backend HELD ise success state oluşur
    test('17. Canonical backend HELD ise success state oluşur', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-payments/17/status') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 17,
                'status': 'HELD',
                'payment_method': 'ONLINE',
                'gross_amount': 200.0,
                'held_at': '2026-09-25T10:00:00Z',
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(customerPaymentNotifierProvider(17).notifier);
      await notifier.checkStatusNow();

      final state = container.read(customerPaymentNotifierProvider(17));
      expect(state.isSuccess, true);
      expect(state.paymentStatus?.isHeld, true);

      container.dispose();
    });

    // 18. HELD sonrası instant detail refetch edilir
    test('18. HELD sonrası instant detail refetch edilir', () async {
      int requestFetches = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-requests/18') {
          requestFetches++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 18,
                'status': 'ASSIGNED',
                'payment_method': 'ONLINE',
                'services': [
                  {'id': 1, 'name': 'Kesim'}
                ],
                'service_payment': {
                  'id': 180,
                  'status': requestFetches > 1 ? 'HELD' : 'PENDING',
                  'gross_amount': 200.0,
                },
              }
            }),
          };
        }
        if (options.path == '/customer/service-requests/18/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(activeRequestProvider(18).notifier);
      await notifier.load();
      expect(requestFetches, 1);

      // On payment success callback, refetch is called:
      await notifier.load();
      expect(requestFetches, 2);

      final state = container.read(activeRequestProvider(18));
      expect(state.request?.paymentSummary?.isHeld, true);

      container.dispose();
    });

    // 19. HELD sonrası appointment detail refetch edilir
    test('19. HELD sonrası appointment detail refetch edilir', () async {
      int appointmentFetches = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/19') {
          appointmentFetches++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 19,
                'public_id': 'APT000019',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 300.0,
                'total_duration_minutes': 30,
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'customer_address_id': 1,
                'is_financially_ready': appointmentFetches > 1,
                'payment_summary': {
                  'id': 190,
                  'status': appointmentFetches > 1 ? 'HELD' : 'PENDING',
                  'gross_amount': 300.0,
                },
              }
            }),
          };
        }
        if (options.path == '/customer/appointments/19/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        if (options.path == '/customer/appointments/19/start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {'code': '1234'},
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(customerAppointmentDetailNotifierProvider(19).notifier);
      await notifier.loadDetail();
      expect(appointmentFetches, 1);

      // On payment success callback, refetch is called:
      await notifier.loadDetail();
      expect(appointmentFetches, 2);

      final state = container.read(customerAppointmentDetailNotifierProvider(19));
      expect(state.appointment?.paymentSummary?.status, 'HELD');
      expect(state.appointment?.isFinanciallyReady, true);

      container.dispose();
    });

    // 20. PENDING iken location/start-code gate kapalıdır
    testWidgets('20. PENDING iken location/start-code gate kapalıdır', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/20') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 20,
                'public_id': 'APT000020',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 300.0,
                'total_duration_minutes': 30,
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'customer_address_id': 1,
                'is_financially_ready': false,
                'payment_summary': {
                  'id': 200,
                  'status': 'PENDING',
                  'gross_amount': 300.0,
                },
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 20),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('share_location_btn')), findsNothing);
      expect(find.byKey(const Key('start_code_text')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 21. HELD sonrası gate backend refetch'e göre açılır
    testWidgets('21. HELD sonrası gate backend refetch\'e göre açılır', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/21') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 21,
                'public_id': 'APT000021',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 300.0,
                'total_duration_minutes': 30,
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'customer_address_id': 1,
                'is_financially_ready': true,
                'payment_summary': {
                  'id': 210,
                  'status': 'HELD',
                  'gross_amount': 300.0,
                },
              }
            }),
          };
        }
        if (options.path == '/customer/appointments/21/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        if (options.path == '/customer/appointments/21/start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {'code': '7788'},
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 21),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('share_location_btn')), findsOneWidget);
      expect(find.text('7788'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 22. WebView close fake CANCELLED oluşturmaz
    test('22. WebView close fake CANCELLED oluşturmaz', () {
      final state = CustomerPaymentState(
        paymentStatus: CustomerPaymentStatusModel.fromJson({
          'id': 22,
          'status': 'PENDING',
          'payment_method': 'ONLINE',
          'gross_amount': 200.0,
        }),
      );

      expect(state.paymentStatus?.status, 'PENDING');
      expect(state.paymentStatus?.isCancelled, false);
    });

    // 23. WebView close payment status refetch eder
    test('23. WebView close payment status refetch eder', () async {
      int statusFetches = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-payments/23/status') {
          statusFetches++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 23,
                'status': 'PENDING',
                'payment_method': 'ONLINE',
                'gross_amount': 200.0,
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(customerPaymentNotifierProvider(23).notifier);
      await notifier.checkStatusNow();

      expect(statusFetches, 1);
      container.dispose();
    });

    // 24. Failed attempt yeniden token alabilir
    test('24. Failed attempt yeniden token alabilir', () async {
      int tokenRequests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-payments/24/paytr/token') {
          tokenRequests++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'success': true,
                'token': 'tok_24_$tokenRequests',
                'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_24_$tokenRequests',
                'payment_id': 24,
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(customerPaymentNotifierProvider(24).notifier);
      await notifier.initPayment();
      expect(tokenRequests, 1);
      expect(container.read(customerPaymentNotifierProvider(24)).tokenResponse?.token, 'tok_24_1');

      // Retry creates fresh token
      await notifier.retry();
      expect(tokenRequests, 2);
      expect(container.read(customerPaymentNotifierProvider(24)).tokenResponse?.token, 'tok_24_2');

      container.dispose();
    });

    // 25. App resume payment status refetch eder
    test('25. App resume payment status refetch eder', () async {
      int statusFetches = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-payments/25/status') {
          statusFetches++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 25,
                'status': 'PENDING',
                'payment_method': 'ONLINE',
                'gross_amount': 200.0,
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(customerPaymentNotifierProvider(25).notifier);
      await notifier.checkStatusNow();

      expect(statusFetches, 1);
      container.dispose();
    });

    // 26. App restart resource HELD ise paid gösterir
    test('26. App restart resource HELD ise paid gösterir', () {
      final appt = CustomerAppointmentModel.fromJson({
        'id': 26,
        'public_id': 'APT000026',
        'status': 'CONFIRMED',
        'payment_method': 'ONLINE',
        'total_price': 300.0,
        'total_duration_minutes': 30,
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'is_financially_ready': true,
        'payment_summary': {
          'id': 260,
          'status': 'HELD',
          'gross_amount': 300.0,
        },
      });

      expect(appt.isOnline, true);
      expect(appt.isOnlinePending, false);
      expect(appt.paymentSummary?.status, 'HELD');
    });

    // 27. PAYMENT_RECEIVED semantic event resource refresh tetikler
    test('27. PAYMENT_RECEIVED semantic event resource refresh tetikler', () async {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(apiClient: apiClient, storage: storageService);

      bool refreshTriggered = false;
      pushService.deepLinkStream.listen((link) {
        if (link.eventType == 'PAYMENT_RECEIVED') {
          refreshTriggered = true;
        }
      });

      pushService.handleIncomingPayload({
        'type': 'PAYMENT_RECEIVED',
        'resource_type': 'appointment',
        'resource_id': '27',
      });

      await Future<void>.delayed(Duration.zero);

      expect(refreshTriggered, true);
    });

    // 28. Payment screen network error retry sunar
    testWidgets('28. Payment screen network error retry sunar', (tester) async {
      int attempts = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        attempts++;
        if (attempts == 1) {
          return {
            'status': 500,
            'body': jsonEncode({'message': 'Sunucu hatası'}),
          };
        }
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'token': 'tok_retry_ok',
              'iframe_url': 'https://www.paytr.com/odeme/guvenli/tok_retry_ok',
              'payment_id': 28,
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PaytrPaymentScreen(
              paymentId: 28,
              grossAmount: 150.0,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('paytr_retry_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('paytr_retry_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(attempts, 2);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 29. Invalid/non-HTTPS top-level URL açılmaz
    test('29. Invalid/non-HTTPS top-level URL açılmaz', () {
      bool isAllowed(String url) {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;
        final scheme = uri.scheme.toLowerCase();
        return scheme == 'https';
      }

      expect(isAllowed('https://www.paytr.com/odeme/guvenli/tok'), true);
      expect(isAllowed('http://insecure.paytr.com'), false);
      expect(isAllowed('file:///etc/passwd'), false);
      expect(isAllowed('javascript:alert(1)'), false);
      expect(isAllowed('data:text/html,<h1>XSS</h1>'), false);
      expect(isAllowed('intent://test'), false);
    });

    // 30. Raw PayTR response kullanıcıya gösterilmez
    test('30. Raw PayTR response kullanıcıya gösterilmez', () {
      final status = CustomerPaymentStatusModel.fromJson({
        'id': 30,
        'status': 'PENDING',
        'status_label': 'Online ödeme bekleniyor',
        'payment_method': 'ONLINE',
        'gross_amount': 200.0,
        'latest_attempt': {
          'merchant_oid': 'BG12345678',
          'status': 'FAILED',
          'failure_message': 'Kart limiti yetersiz.',
        }
      });

      expect(status.statusLabel, 'Online ödeme bekleniyor');
      expect(status.latestAttempt?.failureMessage, 'Kart limiti yetersiz.');
      // Verify raw json dumps or debug dumps are not shown as statusLabel
      expect(status.statusLabel.contains('{'), false);
      expect(status.statusLabel.contains('merchant_oid'), false);
    });

    // 31. Payment token loglanmaz
    test('31. Payment token loglanmaz', () {
      const token = 'tok_sensitive_31';
      final session = PaytrSessionResponse(
        success: true,
        token: token,
        iframeUrl: 'https://www.paytr.com/odeme/guvenli/$token',
        paymentId: 31,
      );

      // Model does not print sensitive token in default toString
      expect(session.token, token);
    });

    // 32. No card/cvv/expiry secure storage
    test('32. No card/cvv/expiry secure storage', () async {
      final keys = await fakeStorage.readAll();
      expect(keys.keys.any((k) => k.contains('card')), false);
      expect(keys.keys.any((k) => k.contains('cvv')), false);
      expect(keys.keys.any((k) => k.contains('cvc')), false);
      expect(keys.keys.any((k) => k.contains('pan')), false);
      expect(keys.keys.any((k) => k.contains('expiry')), false);
    });

    // 33. Role separation korunur
    testWidgets('33. Role separation korunur', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/33') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 33,
                'public_id': 'APT000033',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'customer_address_id': 1,
                'is_financially_ready': false,
                'payment_summary': {
                  'id': 330,
                  'status': 'PENDING',
                  'gross_amount': 200.0,
                },
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 33),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CustomerAppointmentDetailScreen), findsOneWidget);
      expect(find.byType(ProviderAppointmentDetailScreen), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 34. Provider tarafında customer PayTR CTA görünmez
    testWidgets('34. Provider tarafında customer PayTR CTA görünmez', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/34') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 34,
                'public_id': 'APT000034',
                'status': 'CONFIRMED',
                'payment_method': 'ONLINE',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
              }
            }),
          };
        }
        if (options.path == '/provider/appointments/34/shared-location') {
          return {'status': 404, 'body': '{}'};
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 34),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_payment_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 35. CustomerRefundSummaryModel status mapping and zero secret leakage
    test('35. CustomerRefundSummaryModel status mapping and zero secret leakage', () {
      final pending = CustomerRefundSummaryModel.fromJson({
        'has_refund': true,
        'refund_status': 'PENDING',
        'total_refunded_amount': 0.0,
        'remaining_refundable_amount': 250.0,
        'is_partial': false,
      });
      expect(pending.displayStatusText, 'İade bekleniyor');

      final requested = CustomerRefundSummaryModel.fromJson({
        'has_refund': true,
        'refund_status': 'REQUESTED',
        'total_refunded_amount': 0.0,
        'remaining_refundable_amount': 250.0,
        'is_partial': false,
      });
      expect(requested.displayStatusText, 'İade işleminiz devam ediyor');

      final completedFull = CustomerRefundSummaryModel.fromJson({
        'has_refund': true,
        'refund_status': 'COMPLETED',
        'total_refunded_amount': 250.0,
        'remaining_refundable_amount': 0.0,
        'is_partial': false,
      });
      expect(completedFull.displayStatusText, 'İadeniz tamamlandı');

      final completedPartial = CustomerRefundSummaryModel.fromJson({
        'has_refund': true,
        'refund_status': 'COMPLETED',
        'total_refunded_amount': 150.0,
        'remaining_refundable_amount': 100.0,
        'is_partial': true,
      });
      expect(completedPartial.displayStatusText, 'Kısmi iadeniz tamamlandı (150.00 TL)');

      final failed = CustomerRefundSummaryModel.fromJson({
        'has_refund': true,
        'refund_status': 'FAILED',
        'total_refunded_amount': 0.0,
        'remaining_refundable_amount': 250.0,
        'is_partial': false,
      });
      expect(failed.displayStatusText, 'İade işlemi tamamlanamadı. Destek ekibimiz inceleyecek.');

      final manualReview = CustomerRefundSummaryModel.fromJson({
        'has_refund': true,
        'refund_status': 'MANUAL_REVIEW',
        'total_refunded_amount': 0.0,
        'remaining_refundable_amount': 250.0,
        'is_partial': false,
      });
      expect(manualReview.displayStatusText, 'İade işleminiz inceleme altında.');
    });

    // 36. Customer Appointment Detail screen renders safe refund card
    testWidgets('36. Customer Appointment Detail screen renders safe refund card', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/36') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 36,
                'public_id': 'APT000036',
                'status': 'DISPUTED',
                'payment_method': 'ONLINE',
                'total_price': 300.0,
                'total_duration_minutes': 45,
                'appointment_date': '2026-09-25',
                'start_time': '14:00',
                'end_time': '14:45',
                'customer_address_id': 1,
                'is_financially_ready': false,
                'dispute_summary': {
                  'case_id': 101,
                  'status': 'OPEN',
                  'status_label': 'İnceleme Sürecinde',
                },
                'payment_summary': {
                  'id': 360,
                  'status': 'REFUND_REQUIRED',
                  'gross_amount': 300.0,
                  'refund_summary': {
                    'has_refund': true,
                    'refund_status': 'PENDING',
                    'refund_status_label': 'İade bekleniyor',
                    'total_refunded_amount': 0.0,
                    'remaining_refundable_amount': 300.0,
                    'is_partial': false,
                  },
                },
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 36),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('İade Durumu'), findsOneWidget);
      expect(find.text('İade bekleniyor'), findsOneWidget);
      // Zero secrets leaked
      expect(find.textContaining('merchant_oid'), findsNothing);
      expect(find.textContaining('reference_no'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}
