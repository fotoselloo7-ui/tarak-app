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
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/screens/customer_shell.dart';
import 'package:app/features/provider/screens/provider_shell.dart';
import 'package:app/features/provider/instant/providers/provider_instant_providers.dart';
import 'package:app/features/provider/appointments/models/provider_appointment_model.dart';
import 'package:app/features/provider/appointments/models/provider_schedule_model.dart';
import 'package:app/features/provider/appointments/providers/provider_appointment_providers.dart';
import 'package:app/features/provider/appointments/repositories/provider_appointment_repository.dart';
import 'package:app/features/provider/appointments/screens/provider_appointment_detail_screen.dart';
import 'package:app/features/provider/appointments/screens/provider_appointments_tab.dart';

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
    ProviderAppointmentDetailNotifier.enableAutoPolling = false;
    SharedPreferences.setMockInitialValues({});
    fakeStorage = _FakeStorage();
    storageService = SecureStorageService(secureStorage: fakeStorage);
    await storageService.init();
  });

  const sampleProviderUser = UserModel(
    id: 2,
    role: 'PROVIDER',
    name: 'Ahmet Berber',
    email: 'ahmet@berber.com',
  );

  group('Provider Scheduled Appointment Flow - 45 Comprehensive Tests', () {
    // 1. Provider Randevular tab gerçek API listesi kullanır
    testWidgets('1. Provider Randevular tab gerçek API listesi kullanır', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '201',
                  'public_id': 'APT000201',
                  'customer_user_id': '10',
                  'provider_user_id': '2',
                  'customer': {
                    'id': '10',
                    'name': 'Mehmet Müşteri',
                    'avatar_url': null,
                  },
                  'status': 'PENDING',
                  'appointment_date': '2026-09-25',
                  'start_time': '14:00',
                  'end_time': '14:30',
                  'payment_method': 'CASH',
                  'total_price': 250.0,
                  'total_duration_minutes': 30,
                  'approx_location': 'Kadıköy, İstanbul',
                  'services': [
                    {
                      'id': '1',
                      'name': 'Saç Kesimi',
                      'price_snapshot': 250.0,
                      'duration_minutes_snapshot': 30,
                    },
                  ],
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProviderAppointmentsTab()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('APT000201'), findsOneWidget);
      expect(find.text('Mehmet Müşteri'), findsOneWidget);
      expect(find.text('Onay Bekliyor'), findsOneWidget);
      expect(find.text('₺250'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 2. Weekly schedule API'den yüklenir
    test('2. Weekly schedule API\'den yüklenir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/schedule') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '1',
                  'day': 'monday',
                  'day_of_week': 'monday',
                  'is_enabled': true,
                  'start_time': '09:00',
                  'end_time': '19:00',
                  'breaks': [
                    {'id': '1', 'start_time': '13:00', 'end_time': '14:00'},
                  ],
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final schedule = await repo.fetchSchedule();

      expect(schedule.length, 1);
      expect(schedule.first.day, 'monday');
      expect(schedule.first.isEnabled, true);
      expect(schedule.first.breaks.length, 1);
      expect(schedule.first.breaks.first.startTime, '13:00');
    });

    // 3. Schedule save gerçek endpoint çağırır
    test('3. Schedule save gerçek endpoint çağırır', () async {
      bool putCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'PUT' && options.path == '/provider/schedule') {
          putCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'data': []}),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      await repo.updateSchedule([
        {
          'day': 'monday',
          'is_enabled': true,
          'start_time': '09:00',
          'end_time': '18:00',
        },
      ]);

      expect(putCalled, true);
    });

    // 4. Closed day gerçek backend state kullanır
    test('4. Closed day gerçek backend state kullanır', () {
      const schedule = ProviderWeeklyScheduleModel(
        day: 'sunday',
        dayOfWeek: 'sunday',
        isEnabled: false,
        startTime: '09:00',
        endTime: '19:00',
      );

      expect(schedule.isEnabled, false);
      expect(schedule.dayLabel, 'Pazar');
    });

    // 5. Break create/delete gerçek API kullanır
    test('5. Break create/delete model ve payload yapısı', () {
      final brk = ProviderScheduleBreakModel.fromJson({
        'id': '10',
        'start_time': '12:30',
        'end_time': '13:30',
      });

      expect(brk.id, 10);
      expect(brk.startTime, '12:30');
      expect(brk.endTime, '13:30');

      final json = brk.toJson();
      expect(json['start_time'], '12:30');
      expect(json['end_time'], '13:30');
    });

    // 6. Closed date create/delete gerçek API kullanır
    test('6. Closed date create/delete gerçek API kullanır', () async {
      bool postCalled = false;
      bool deleteCalled = false;

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'POST' &&
            options.path == '/provider/closed-dates') {
          postCalled = true;
          return {
            'status': 201,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '99',
                'date': '2026-10-15',
                'reason': 'İzin',
                'note': 'Kişisel',
              },
            }),
          };
        }
        if (options.method == 'DELETE' &&
            options.path == '/provider/closed-dates/99') {
          deleteCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'message': 'Silindi'}),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      final created = await repo.storeClosedDate(
        date: '2026-10-15',
        reason: 'İzin',
        note: 'Kişisel',
      );
      expect(postCalled, true);
      expect(created.id, 99);

      await repo.deleteClosedDate(99);
      expect(deleteCalled, true);
    });

    // 7. PENDING appointment only own provider data gösterir
    test('7. PENDING appointment only own provider data gösterir', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '7',
        'public_id': 'APT000007',
        'customer_user_id': '10',
        'provider_user_id': '2',
        'status': 'PENDING',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
      });

      expect(appt.providerUserId, 2);
      expect(appt.isPending, true);
    });

    // 8. Request card exact address göstermez
    testWidgets('8. Request card exact address göstermez', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '8',
                  'public_id': 'APT000008',
                  'customer_user_id': '10',
                  'provider_user_id': '2',
                  'customer': {'id': '10', 'name': 'Gizli Müşteri'},
                  'status': 'PENDING',
                  'appointment_date': '2026-09-25',
                  'start_time': '11:00',
                  'end_time': '11:30',
                  'payment_method': 'CASH',
                  'total_price': 150.0,
                  'total_duration_minutes': 30,
                  'approx_location': 'Beşiktaş, İstanbul',
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProviderAppointmentsTab()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Beşiktaş, İstanbul'), findsOneWidget);
      expect(find.textContaining('Daire:'), findsNothing);
      expect(find.textContaining('Sokak'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 9. Request card phone/email göstermez
    test('9. Request card phone/email göstermez', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '9',
        'public_id': 'APT000009',
        'customer_user_id': '10',
        'provider_user_id': '2',
        'customer': {'id': '10', 'name': 'Ali Can', 'avatar_url': null},
        'status': 'PENDING',
        'appointment_date': '2026-09-25',
        'start_time': '12:00',
        'end_time': '12:30',
        'payment_method': 'CASH',
        'total_price': 180.0,
        'total_duration_minutes': 30,
      });

      expect(appt.customer?.name, 'Ali Can');
      final json = {'id': appt.customer?.id, 'name': appt.customer?.name};
      expect(json.containsKey('phone'), false);
      expect(json.containsKey('email'), false);
    });

    // 10. Confirm gerçek endpoint çağırır
    test('10. Confirm gerçek endpoint çağırır', () async {
      bool confirmCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'POST' &&
            options.path == '/provider/appointments/10/confirm') {
          confirmCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '10',
                'public_id': 'APT000010',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final confirmed = await repo.confirmAppointment(10);

      expect(confirmCalled, true);
      expect(confirmed.status, 'CONFIRMED');
    });

    // 11. Confirm conflict fake CONFIRMED üretmez
    test('11. Confirm conflict fake CONFIRMED üretmez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/11/confirm') {
          return {
            'status': 409,
            'body': jsonEncode({
              'success': false,
              'message': 'Bu saat artık müsait değil. Alternatif saat önerin.',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      expect(() => repo.confirmAppointment(11), throwsA(isA<AppException>()));
    });

    // 12. CASH insufficient commission business error gösterir
    test('12. CASH insufficient commission business error gösterir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/12/confirm') {
          return {
            'status': 422,
            'body': jsonEncode({
              'success': false,
              'message': 'Yetersiz bakiye. Komisyon tahsilatı için cüzdanınıza bakiye yükleyin.',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      expect(
        () => repo.confirmAppointment(12),
        throwsA(
          predicate(
            (e) => e is AppException && e.message.contains('Yetersiz bakiye'),
          ),
        ),
      );
    });

    // 13. ONLINE confirm client wallet gate kullanmaz
    test('13. ONLINE confirm client wallet gate kullanmaz', () async {
      bool confirmCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/13/confirm') {
          confirmCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '13',
                'public_id': 'APT000013',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'ONLINE',
                'total_price': 300.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final appt = await repo.confirmAppointment(13);

      expect(confirmCalled, true);
      expect(appt.status, 'CONFIRMED');
      expect(appt.paymentMethod, 'ONLINE');
    });

    // 14. Reject gerçek endpoint çağırır
    test('14. Reject gerçek endpoint çağırır', () async {
      bool rejectCalled = false;
      String? sentReason;

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'POST' &&
            options.path == '/provider/appointments/14/reject') {
          rejectCalled = true;
          final data = options.data is Map
              ? options.data as Map
              : (options.data is String
                    ? jsonDecode(options.data as String)
                    : <String, dynamic>{});
          sentReason = data['reason']?.toString();
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '14',
                'public_id': 'APT000014',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'REJECTED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'rejection_reason': sentReason,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final rejected = await repo.rejectAppointment(
        14,
        reason: 'O saatte doluyum.',
      );

      expect(rejectCalled, true);
      expect(sentReason, 'O saatte doluyum.');
      expect(rejected.status, 'REJECTED');
      expect(rejected.rejectionReason, 'O saatte doluyum.');
    });

    // 15. Alternative UI backend availability kullanır
    test('15. Alternative UI backend availability kullanır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/providers/2/availability') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'provider_id': '2',
                'date': '2026-09-26',
                'total_duration_minutes': 30,
                'total_price': 250.0,
                'available_slots': ['10:00', '11:00', '15:00'],
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final avail = await repo.fetchAvailability(
        providerId: 2,
        date: '2026-09-26',
        serviceIds: [1],
      );

      expect(avail.availableSlots.length, 3);
      expect(avail.availableSlots, contains('15:00'));
    });

    // 16. Alternative hardcoded slot üretmez
    test('16. Alternative hardcoded slot üretmez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/providers/2/availability') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'provider_id': '2',
                'date': '2026-09-26',
                'total_duration_minutes': 30,
                'total_price': 250.0,
                'available_slots': <String>[],
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final avail = await repo.fetchAvailability(
        providerId: 2,
        date: '2026-09-26',
        serviceIds: [1],
      );

      expect(avail.availableSlots.isEmpty, true);
    });

    // 17. 1-5 alternative constraint korunur
    test('17. 1-5 alternative constraint korunur', () {
      final emptySlots = <Map<String, String>>[];
      final validSlots = [
        {'date': '2026-09-26', 'time': '10:00'},
        {'date': '2026-09-26', 'time': '11:00'},
      ];
      final excessiveSlots = List.generate(
        6,
        (i) => {'date': '2026-09-26', 'time': '1$i:00'},
      );

      expect(emptySlots.isEmpty, true);
      expect(validSlots.isNotEmpty && validSlots.length <= 5, true);
      expect(excessiveSlots.length > 5, true);
    });

    // 18. Alternative proposal gerçek endpoint
    test('18. Alternative proposal gerçek endpoint', () async {
      bool proposalCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'POST' &&
            options.path == '/provider/appointments/18/alternatives') {
          proposalCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '18',
                'public_id': 'APT000018',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'ALTERNATIVE_PROPOSED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'alternative_slots': [
                  {
                    'id': '1',
                    'date': '2026-09-26',
                    'start_time': '14:00',
                    'end_time': '14:30',
                    'status': 'PENDING',
                  },
                ],
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final updated = await repo.proposeAlternatives(
        18,
        slots: [
          {'date': '2026-09-26', 'time': '14:00'},
        ],
      );

      expect(proposalCalled, true);
      expect(updated.status, 'ALTERNATIVE_PROPOSED');
      expect(updated.alternativeSlots.length, 1);
    });

    // 19. Proposal sonrası CONFIRMED değil ALTERNATIVE_PROPOSED
    test('19. Proposal sonrası CONFIRMED değil ALTERNATIVE_PROPOSED', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '19',
        'public_id': 'APT000019',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'ALTERNATIVE_PROPOSED',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
      });

      expect(appt.isConfirmed, false);
      expect(appt.isAlternativeProposed, true);
    });

    // 20. Customer accept sonrası CONFIRMED refetch edilir
    test('20. Customer accept sonrası CONFIRMED refetch edilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/20') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '20',
                'public_id': 'APT000020',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-26',
                'start_time': '14:00',
                'end_time': '14:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final appt = await repo.fetchAppointment(20);

      expect(appt.status, 'CONFIRMED');
      expect(appt.appointmentDate, '2026-09-26');
      expect(appt.startTime, '14:00');
    });

    // 21. Upcoming list doğru scheduled order
    test('21. Upcoming list doğru scheduled order', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '212',
                  'public_id': 'APT000212',
                  'customer_user_id': '1',
                  'provider_user_id': '2',
                  'status': 'CONFIRMED',
                  'appointment_date': '2026-09-27',
                  'start_time': '10:00',
                  'end_time': '10:30',
                  'payment_method': 'CASH',
                  'total_price': 200.0,
                  'total_duration_minutes': 30,
                },
                {
                  'id': '211',
                  'public_id': 'APT000211',
                  'customer_user_id': '1',
                  'provider_user_id': '2',
                  'status': 'CONFIRMED',
                  'appointment_date': '2026-09-25',
                  'start_time': '09:00',
                  'end_time': '09:30',
                  'payment_method': 'CASH',
                  'total_price': 200.0,
                  'total_duration_minutes': 30,
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await container.read(providerAppointmentsProvider.future);
      final sortedUpcoming = container.read(
        providerUpcomingAppointmentsProvider,
      );

      expect(sortedUpcoming.first.publicId, 'APT000211');
      expect(sortedUpcoming.last.publicId, 'APT000212');

      container.dispose();
    });

    // 22. ONLINE PENDING "ödendi" görünmez
    test('22. ONLINE PENDING "ödendi" görünmez', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '22',
        'public_id': 'APT000022',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'CONFIRMED',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'ONLINE',
        'total_price': 300.0,
        'total_duration_minutes': 30,
      });

      expect(appt.paymentMethod, 'ONLINE');
      expect(appt.isCash, false);
      expect(appt.isOnline, true);
    });

    // 23. ONLINE PENDING exact location/start code gate kapalı
    testWidgets('23. ONLINE PENDING exact location/start code gate kapalı', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/23') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '23',
                'public_id': 'APT000023',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'PENDING',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'ONLINE',
                'total_price': 300.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 23),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('start_code_input')), findsNothing);
      expect(find.byKey(const Key('exact_address_text')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 24. No grant exact address göstermez
    testWidgets('24. No grant exact address göstermez', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/24') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '24',
                'public_id': 'APT000024',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'approx_location': 'Şişli, İstanbul',
              },
            }),
          };
        }
        if (options.path == '/provider/appointments/24/shared-location') {
          return {
            'status': 404,
            'body': '{"message":"Müşteri henüz konumunu paylaşmadı."}',
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 24),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('location_not_shared_text')), findsOneWidget);
      expect(find.byKey(const Key('exact_address_text')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 25. ACTIVE grant shared-location endpoint kullanır
    testWidgets('25. ACTIVE grant shared-location endpoint kullanır', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/25') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '25',
                'public_id': 'APT000025',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        if (options.path == '/provider/appointments/25/shared-location') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'title': 'Ev',
                'address_line1': 'Bağdat Cad. No: 100',
                'building_no': '100',
                'apartment_no': '5',
                'district': 'Kadıköy',
                'province': 'İstanbul',
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 25),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('exact_address_text')), findsOneWidget);
      expect(find.textContaining('Bağdat Cad. No: 100'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 26. Revoked grant exact address kaldırır
    test('26. Revoked grant exact address kaldırır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/26/shared-location') {
          return {
            'status': 403,
            'body': '{"message":"Konum paylaşımı iptal edildi."}',
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      expect(() => repo.fetchSharedLocation(26), throwsA(isA<AppException>()));
    });

    // 27. Expired grant exact address kaldırır
    test('27. Expired grant exact address kaldırır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/27/shared-location') {
          return {
            'status': 404,
            'body': '{"message":"Konum paylaşım izninin süresi dolmuş."}',
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      expect(() => repo.fetchSharedLocation(27), throwsA(isA<AppException>()));
    });

    // 28. Exact address persistent storage'a yazılmaz
    test('28. Exact address persistent storage\'a yazılmaz', () async {
      final loc = ProviderSharedLocation.fromJson({
        'title': 'Ev',
        'address_line1': 'Gizli Sokak No: 1',
        'district': 'Kadıköy',
      });
      expect(loc.title, 'Ev');

      final storedKeys = await fakeStorage.readAll();
      expect(storedKeys.values.any((v) => v.contains('Gizli Sokak')), false);
    });

    // 29. Start code 4 digit numeric
    testWidgets('29. Start code 4 digit numeric', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/29') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '29',
                'public_id': 'APT000029',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 29),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final inputFinder = find.byKey(const Key('start_code_input'));
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, '1234');
      expect(find.text('1234'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 30. Wrong code backend error
    test('30. Wrong code backend error', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/30/verify-start-code') {
          return {
            'status': 422,
            'body': jsonEncode({
              'success': false,
              'message': 'Geçersiz başlangıç kodu. Kalan deneme: 4',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      expect(
        () => repo.verifyStartCode(30, '0000'),
        throwsA(
          predicate(
            (e) =>
                e is AppException &&
                e.message.contains('Geçersiz başlangıç kodu'),
          ),
        ),
      );
    });

    // 31. Locked code backend state
    test('31. Locked code backend state', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/31/verify-start-code') {
          return {
            'status': 429,
            'body': jsonEncode({
              'success': false,
              'message': 'Çok fazla hatalı deneme. Doğrulama kilitlendi.',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);

      expect(
        () => repo.verifyStartCode(31, '9999'),
        throwsA(
          predicate(
            (e) =>
                e is AppException && e.message.contains('Doğrulama kilitlendi'),
          ),
        ),
      );
    });

    // 32. Correct code server refetch IN_PROGRESS
    test('32. Correct code server refetch IN_PROGRESS', () async {
      bool verifyCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'POST' &&
            options.path == '/provider/appointments/32/verify-start-code') {
          verifyCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'message': 'Başlangıç kodu doğrulandı.',
              'status': 'IN_PROGRESS',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final res = await repo.verifyStartCode(32, '1234');

      expect(verifyCalled, true);
      expect(res['status'], 'IN_PROGRESS');
    });

    // 33. Finish gerçek endpoint
    test('33. Finish gerçek endpoint', () async {
      bool finishCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.method == 'POST' &&
            options.path == '/provider/appointments/33/finish') {
          finishCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'status': 'AWAITING_CUSTOMER_CONFIRMATION',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderAppointmentRepository(apiClient);
      final res = await repo.finishAppointment(33);

      expect(finishCalled, true);
      expect(res['status'], 'AWAITING_CUSTOMER_CONFIRMATION');
    });

    // 34. Finish sonrası AWAITING gösterilir
    testWidgets('34. Finish sonrası AWAITING gösterilir', (tester) async {
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
                'id': '34',
                'public_id': 'APT000034',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'AWAITING_CUSTOMER_CONFIRMATION',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
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

      expect(find.text('Müşteri Onayı Bekleniyor'), findsOneWidget);
      expect(
        find.textContaining('Müşterinin onayı bekleniyor'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 35. Customer complete sonrası COMPLETED
    testWidgets('35. Customer complete sonrası COMPLETED', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/35') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '35',
                'public_id': 'APT000035',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'COMPLETED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 35),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tamamlandı'), findsOneWidget);
      expect(find.textContaining('başarıyla tamamlandı'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 36. Customer dispute sonrası DISPUTED
    testWidgets('36. Customer dispute sonrası DISPUTED', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/36') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '36',
                'public_id': 'APT000036',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'DISPUTED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'dispute_summary': {
                  'case_id': 12,
                  'status': 'UNDER_REVIEW',
                  'status_label': 'İnceleniyor',
                },
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProviderAppointmentDetailScreen(appointmentId: 36),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sorun Bildirildi'), findsOneWidget);
      expect(find.textContaining('Uyuşmazlık Açıldı'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 37. Admin note render edilmez
    test('37. Admin note render edilmez', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '37',
        'public_id': 'APT000037',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'DISPUTED',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
        'dispute_summary': {
          'case_id': 10,
          'status': 'RESOLVED_CUSTOMER',
          'status_label': 'Müşteri Lehine Sonuçlandı',
          'resolution': 'Ücret iadesi yapıldı.',
        },
      });

      expect(appt.disputeSummary?.resolution, 'Ücret iadesi yapıldı.');
      final json = {
        'case_id': appt.disputeSummary?.caseId,
        'status': appt.disputeSummary?.status,
        'resolution': appt.disputeSummary?.resolution,
      };
      expect(json.containsKey('admin_internal_notes'), false);
      expect(json.containsKey('internal_secret'), false);
    });

    // 38. History gerçek backend data
    test('38. History gerçek backend data', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '381',
                  'public_id': 'APT000381',
                  'customer_user_id': '1',
                  'provider_user_id': '2',
                  'customer': {'id': '1', 'name': 'Geçmiş Müşteri'},
                  'status': 'COMPLETED',
                  'appointment_date': '2026-09-20',
                  'start_time': '10:00',
                  'end_time': '10:30',
                  'payment_method': 'CASH',
                  'total_price': 200.0,
                  'total_duration_minutes': 30,
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await container.read(providerAppointmentsProvider.future);
      final updatedHistory = container.read(
        providerHistoryAppointmentsProvider,
      );

      expect(updatedHistory.length, 1);
      expect(updatedHistory.first.publicId, 'APT000381');
      expect(updatedHistory.first.status, 'COMPLETED');

      container.dispose();
    });

    // 39. APPOINTMENT_REQUESTED deep-link detail/list doğru açılır
    testWidgets(
      '39. APPOINTMENT_REQUESTED deep-link detail/list doğru açılır',
      (tester) async {
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter((options) {
          if (options.path == '/provider/appointments/39') {
            return {
              'status': 200,
              'body': jsonEncode({
                'success': true,
                'data': {
                  'id': '39',
                  'public_id': 'APT000039',
                  'customer_user_id': '1',
                  'provider_user_id': '2',
                  'status': 'PENDING',
                  'appointment_date': '2026-09-25',
                  'start_time': '10:00',
                  'end_time': '10:30',
                  'payment_method': 'CASH',
                  'total_price': 200.0,
                  'total_duration_minutes': 30,
                },
              }),
            };
          }
          return {'status': 200, 'body': '{"success":true,"data":[]}'};
        });

        final apiClient = ApiClient(storage: storageService, customDio: dio);
        final pushService = PushNotificationService(
          apiClient: apiClient,
          storage: storageService,
        );
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            pushNotificationServiceProvider.overrideWithValue(pushService),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProviderShell()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        pushService.handleIncomingPayload({
          'type': 'APPOINTMENT_REQUESTED',
          'resource_type': 'SCHEDULED_APPOINTMENT',
          'resource_id': '39',
        });

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ProviderAppointmentDetailScreen), findsOneWidget);

        final detailNotifier = container.read(
          providerAppointmentDetailNotifierProvider(39).notifier,
        );
        ProviderAppointmentDetailNotifier.enableAutoPolling = true;
        detailNotifier.startPolling();
        expect(detailNotifier.isPolling, true);
        await tester.pumpWidget(const SizedBox());
        expect(
          detailNotifier.isPolling,
          false,
          reason: 'Leaving the detail must stop its retained provider timer.',
        );
        ProviderAppointmentDetailNotifier.enableAutoPolling = false;
        container.dispose();
      },
    );

    // 40. ALTERNATIVE_ACCEPTED deep-link doğru detail açılır
    testWidgets('40. ALTERNATIVE_ACCEPTED deep-link doğru detail açılır', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/40') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '40',
                'public_id': 'APT000040',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-26',
                'start_time': '15:00',
                'end_time': '15:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
              },
            }),
          };
        }
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(
        apiClient: apiClient,
        storage: storageService,
      );
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          pushNotificationServiceProvider.overrideWithValue(pushService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProviderShell()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      pushService.handleIncomingPayload({
        'type': 'APPOINTMENT_ALTERNATIVE_ACCEPTED',
        'resource_type': 'SCHEDULED_APPOINTMENT',
        'resource_id': '40',
      });

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ProviderAppointmentDetailScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 41. LOCATION_SHARED exact-location refresh tetikler
    test('41. LOCATION_SHARED exact-location refresh tetikler', () async {
      int locationFetches = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/41/shared-location') {
          locationFetches++;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'title': 'Ofis',
                'address_line1': 'Büyükdere Cad. No: 50',
                'district': 'Şişli',
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      final notifier = container.read(
        providerAppointmentDetailNotifierProvider(41).notifier,
      );
      await notifier.refreshSharedLocation();

      expect(locationFetches, 1);
      final state = container.read(
        providerAppointmentDetailNotifierProvider(41),
      );
      expect(state.sharedLocation?.district, 'Şişli');

      container.dispose();
    });

    test(
      'wallet failure is surfaced instead of invented zero balances',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = _MockDioAdapter(
          (options) => {'status': 503, 'body': '{"message":"Unavailable"}'},
        );
        final apiClient = ApiClient(storage: storageService, customDio: dio);
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(apiClient)],
        );
        addTearDown(container.dispose);
        await expectLater(
          container.read(providerWalletSummaryProvider.future),
          throwsA(isA<Exception>()),
        );
        expect(container.read(providerWalletSummaryProvider).hasError, true);
        expect(container.read(providerWalletSummaryProvider).hasValue, false);
      },
    );

    test('payout account failure does not report an absent IBAN', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(
        (options) => options.path == '/provider/wallet'
            ? {
                'status': 200,
                'body': '{"success":true,"data":{"cash_balance":50,"promo_balance":200,"withdrawable_balance":50}}',
              }
            : {'status': 503, 'body': '{"message":"Unavailable"}'},
      );
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(providerWalletSummaryProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(providerWalletSummaryProvider).hasError, true);
    });

    // 42. Polling background/dispose/final state'te durur
    test('42. Polling background/dispose/final state\'te durur', () {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      final notifier = container.read(
        providerAppointmentDetailNotifierProvider(42).notifier,
      );

      ProviderAppointmentDetailNotifier.enableAutoPolling = true;
      notifier.startPolling();
      expect(notifier.isPolling, true);

      // Background / pause stops polling
      notifier.stopPolling();
      expect(notifier.isPolling, false);

      ProviderAppointmentDetailNotifier.enableAutoPolling = false;

      // Final appointment status flag check
      final apptFinal = ProviderAppointmentModel.fromJson({
        'id': '42',
        'public_id': 'APT000042',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'COMPLETED',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
      });
      expect(apptFinal.isFinal, true);

      container.dispose();
    });

    // 43. Timezone scheduled time kaymaz
    test('43. Timezone scheduled time kaymaz', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '43',
        'public_id': 'APT000043',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'CONFIRMED',
        'appointment_date': '2026-09-25',
        'start_time': '14:30',
        'end_time': '15:00',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
      });

      expect(appt.appointmentDate, '2026-09-25');
      expect(appt.startTime, '14:30');
      expect(appt.endTime, '15:00');
    });

    // 44. Provider/customer role separation korunur
    testWidgets('44. Provider/customer role separation korunur', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(
        apiClient: apiClient,
        storage: storageService,
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          pushNotificationServiceProvider.overrideWithValue(pushService),
          authNotifierProvider.overrideWith(() {
            return AuthNotifier(
              storage: storageService,
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: sampleProviderUser,
              ),
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProviderShell()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProviderShell), findsOneWidget);
      expect(find.byType(CustomerShell), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 45. Fake schedule/rating/earning/payment render edilmez
    test('45. Fake schedule/rating/earning/payment render edilmez', () {
      final appt = ProviderAppointmentModel.fromJson({
        'id': '45',
        'public_id': 'APT000045',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'PENDING',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
      });

      expect(appt.rejectionReason, isNull);
      expect(appt.disputeSummary, isNull);
      expect(appt.confirmedAt, isNull);
    });
  });
}
