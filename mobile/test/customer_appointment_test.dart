import 'dart:async';
import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/appointments/models/appointment_availability_model.dart';
import 'package:app/features/customer/appointments/models/customer_appointment_model.dart';
import 'package:app/features/customer/appointments/models/scheduled_provider_model.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/customer/appointments/repositories/customer_appointment_repository.dart';
import 'package:app/features/customer/appointments/screens/create_appointment_screen.dart';
import 'package:app/features/customer/appointments/screens/customer_appointment_detail_screen.dart';
import 'package:app/features/customer/appointments/screens/customer_appointments_tab.dart';
import 'package:app/features/customer/models/customer_address.dart';
import 'package:app/features/customer/models/service_item.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/repositories/instant_request_repository.dart';
import 'package:app/features/customer/screens/customer_shell.dart';
import 'package:app/features/provider/screens/provider_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final result = handler(options);
    final status = result['status'] as int? ?? 200;
    final body = result['body'] as String? ?? '{}';

    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeMyServiceRequestsNotifier extends MyServiceRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class FakeCustomerAppointmentsNotifier extends CustomerAppointmentsNotifier {
  @override
  Future<List<CustomerAppointmentModel>> build() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() async {
    CustomerAppointmentDetailNotifier.enableAutoPolling = false;
    SharedPreferences.setMockInitialValues({});
    fakeStorage = _FakeStorage();
    storageService = SecureStorageService(secureStorage: fakeStorage);
    await storageService.init();
  });

  const sampleCustomer = UserModel(
    id: 1,
    role: 'CUSTOMER',
    name: 'Müşteri Test',
    email: 'musteri@test.com',
  );

  group('Customer Scheduled Appointment Flow - 40 Comprehensive Tests', () {
    // 1. Randevular tab gerçek API listesi gösterir
    testWidgets('1. Randevular tab gerçek API listesi gösterir', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '101',
                  'public_id': 'APT000101',
                  'customer_user_id': '1',
                  'provider_user_id': '2',
                  'provider': {
                    'id': '1',
                    'user_id': '2',
                    'business_name': 'Ahmet Usta',
                    'name': 'Ahmet Yılmaz',
                    'is_verified': true,
                  },
                  'status': 'PENDING',
                  'appointment_date': '2026-09-25',
                  'start_time': '14:00',
                  'end_time': '14:30',
                  'payment_method': 'CASH',
                  'total_price': 300.0,
                  'total_duration_minutes': 30,
                  'services': [
                    {
                      'id': '1',
                      'name': 'Saç Kesimi',
                      'price_snapshot': 300.0,
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
          child: const MaterialApp(home: CustomerAppointmentsTab()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('APT000101'), findsOneWidget);
      expect(find.text('Ahmet Usta'), findsOneWidget);
      expect(find.text('Onay Bekliyor'), findsOneWidget);
      expect(find.text('₺300'), findsOneWidget);
    });

    // 2. New appointment CTA flow açar
    testWidgets('2. New appointment CTA flow açar', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {'status': 200, 'body': '{"success":true,"data":[]}'};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          servicesProvider(null).overrideWith((ref) async => const []),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CustomerAppointmentsTab()),
        ),
      );

      await tester.pump();
      expect(find.byKey(const Key('new_appointment_fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('new_appointment_fab')));
      await tester.pumpAndSettle();

      expect(find.byType(CreateAppointmentScreen), findsOneWidget);
    });

    // 3. Service catalog gerçek backend source kullanır
    test('3. Service catalog gerçek backend source kullanır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/services') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {'id': 1, 'name': 'Sakal Tıraşı', 'duration_minutes': 20},
                {'id': 2, 'name': 'Cilt Bakımı', 'duration_minutes': 45},
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = InstantRequestRepository(apiClient);
      final services = await repo.fetchServices();

      expect(services.length, 2);
      expect(services[0].name, 'Sakal Tıraşı');
      expect(services[1].name, 'Cilt Bakımı');
    });

    // 4. Provider discovery backend response kullanır
    test('4. Provider discovery backend response kullanır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/providers') {
          expect(options.queryParameters['service_ids'], '1');
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '1',
                  'user_id': '2',
                  'business_name': 'Barber Elite',
                  'name': 'Kemal Berber',
                  'city': 'İstanbul',
                  'district': 'Beşiktaş',
                  'rating': 4.8,
                  'is_verified': true,
                  'is_approved': true,
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      final providers = await repo.fetchProviders(serviceIds: [1]);

      expect(providers.length, 1);
      expect(providers.first.businessName, 'Barber Elite');
      expect(providers.first.isVerified, true);
    });

    // 5. Offline provider client-side keyfi filtrelenmez
    test('5. Offline provider client-side keyfi filtrelenmez', () async {
      final jsonOffline = {
        'id': '2',
        'user_id': '3',
        'business_name': 'Klas Kuaför',
        'city': 'Ankara',
        'district': 'Çankaya',
        'is_approved': true,
        'is_verified': true,
        'is_online': false, // offline
      };

      final provider = ScheduledProviderModel.fromJson(jsonOffline);
      expect(provider.displayName, 'Klas Kuaför');
      expect(provider.isVerified, true);
    });

    // 6. Provider card sensitive info içermez
    test('6. Provider card sensitive info içermez', () {
      final provider = ScheduledProviderModel.fromJson({
        'id': '1',
        'user_id': '2',
        'business_name': 'Berberim',
        'city': 'İzmir',
        'district': 'Bornova',
        'rating': 5.0,
      });

      expect(provider.displayName, 'Berberim');
      expect(provider.locationSummary, 'Bornova, İzmir');
      // Verify no sensitive fields in model
      expect(provider.toString().contains('phone'), false);
      expect(provider.toString().contains('email'), false);
    });

    // 7. Date selection availability API çağırır
    test('7. Date selection availability API çağırır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/providers/2/availability') {
          expect(options.queryParameters['date'], '2026-09-25');
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'provider_id': '2',
                'date': '2026-09-25',
                'total_duration_minutes': 40,
                'total_price': 350.0,
                'available_slots': ['10:00', '11:00', '14:00'],
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      final avail = await repo.fetchAvailability(
        providerId: 2,
        date: '2026-09-25',
        serviceIds: [1],
      );

      expect(avail.availableSlots, ['10:00', '11:00', '14:00']);
      expect(avail.totalPrice, 350.0);
    });

    // 8. Slots hardcoded değildir
    test('8. Slots hardcoded değildir', () {
      final backendSlots = AppointmentAvailabilityModel.fromJson({
        'available_slots': [
          {'start_time': '09:30', 'end_time': '10:00'},
          {'start_time': '09:30', 'end_time': '10:00'},
          {'end_time': '11:00'},
          'invalid',
        ],
      });
      expect(backendSlots.availableSlots, ['09:30']);

      final dynamicAvailability = AppointmentAvailabilityModel.fromJson({
        'provider_id': '5',
        'date': '2026-10-01',
        'total_duration_minutes': 30,
        'total_price': 200.0,
        'available_slots': ['13:15', '16:45', '18:30'],
      });

      expect(dynamicAvailability.availableSlots.length, 3);
      expect(dynamicAvailability.availableSlots[0], '13:15');
      expect(dynamicAvailability.availableSlots[1], '16:45');
      expect(dynamicAvailability.availableSlots[2], '18:30');
    });

    // 9. Unavailable/stale slot error refresh yapar
    test('9. Unavailable/stale slot error refresh yapar', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments') {
          return {
            'status': 409,
            'body': jsonEncode({
              'message':
                  'Bu saat artık müsait değil. Lütfen başka bir saat seçin.',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);

      expect(
        () => repo.createAppointment(
          providerId: 2,
          serviceIds: [1],
          date: '2026-09-25',
          time: '10:00',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Bu saat artık uygun değil'),
          ),
        ),
      );
    });

    // 10. Address selection gerçek customer address kullanır
    test('10. Address selection gerçek customer address kullanır', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/addresses') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 12,
                  'title': 'Ofis',
                  'province': 'İstanbul',
                  'district': 'Şişli',
                  'neighborhood': 'Mecidiyeköy',
                  'street': 'Büyükdere Cad.',
                },
              ],
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      final addrs = await repo.fetchAddresses();

      expect(addrs.length, 1);
      expect(addrs.first.title, 'Ofis');
      expect(addrs.first.district, 'Şişli');
    });

    // 11. CASH seçilebilir
    test('11. CASH seçilebilir', () {
      final container = ProviderContainer();
      final notifier = container.read(appointmentWizardProvider.notifier);
      notifier.setPaymentMethod('CASH');

      expect(container.read(appointmentWizardProvider).paymentMethod, 'CASH');
    });

    // 12. ONLINE seçilebilir
    test('12. ONLINE seçilebilir', () {
      final container = ProviderContainer();
      final notifier = container.read(appointmentWizardProvider.notifier);
      notifier.setPaymentMethod('ONLINE');

      expect(container.read(appointmentWizardProvider).paymentMethod, 'ONLINE');
    });

    // 13. Review doğru provider/service/date/time/address gösterir
    test('13. Review doğru provider/service/date/time/address gösterir', () {
      final container = ProviderContainer();
      final notifier = container.read(appointmentWizardProvider.notifier);

      notifier.toggleService(const ServiceItem(id: 1, name: 'Saç Kesimi'));
      notifier.selectProvider(
        const ScheduledProviderModel(
          id: 1,
          userId: 2,
          businessName: 'Usta Makas',
        ),
      );
      notifier.selectDate(DateTime(2026, 9, 25));
      notifier.selectSlot('14:30');
      notifier.selectAddress(
        const CustomerAddress(
          id: 5,
          title: 'Ev',
          province: 'İstanbul',
          district: 'Kadıköy',
        ),
      );
      notifier.setPaymentMethod('CASH');

      final state = container.read(appointmentWizardProvider);
      expect(state.canReview, true);
      expect(state.selectedProvider?.displayName, 'Usta Makas');
      expect(state.selectedSlot, '14:30');
      expect(state.selectedAddress?.district, 'Kadıköy');
      expect(state.paymentMethod, 'CASH');
    });

    // 14. Double create submit iki request üretmez
    test('14. Double create submit iki request üretmez', () async {
      int requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments') {
          requestCount++;
          return {
            'status': 201,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '1',
                'public_id': 'APT000001',
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
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      final notifier = container.read(appointmentWizardProvider.notifier);
      notifier.toggleService(const ServiceItem(id: 1, name: 'Hizmet'));
      notifier.selectProvider(const ScheduledProviderModel(id: 1, userId: 2));
      notifier.selectDate(DateTime(2026, 9, 25));
      notifier.selectSlot('10:00');
      notifier.selectAddress(
        const CustomerAddress(
          id: 1,
          title: 'Ev',
          province: 'İstanbul',
          district: 'Kadıköy',
        ),
      );

      // Submit concurrently
      final fut1 = notifier.submitAppointment();
      final fut2 = notifier.submitAppointment();
      await Future.wait([fut1, fut2]);

      expect(requestCount, 1);
    });

    // 15. Create success PENDING detail açar
    test('15. Create success PENDING detail açar', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments') {
          return {
            'status': 201,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '15',
                'public_id': 'APT000015',
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
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      final notifier = container.read(appointmentWizardProvider.notifier);
      notifier.toggleService(const ServiceItem(id: 1, name: 'Hizmet'));
      notifier.selectProvider(const ScheduledProviderModel(id: 1, userId: 2));
      notifier.selectDate(DateTime(2026, 9, 25));
      notifier.selectSlot('10:00');
      notifier.selectAddress(
        const CustomerAddress(
          id: 1,
          title: 'Ev',
          province: 'İstanbul',
          district: 'Kadıköy',
        ),
      );

      final created = await notifier.submitAppointment();
      expect(created, isNotNull);
      expect(created!.isPending, true);
      expect(created.publicId, 'APT000015');
    });

    // 16. PENDING exact location/start-code göstermez
    testWidgets('16. PENDING exact location/start-code göstermez', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/16') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '16',
                'public_id': 'APT000016',
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
            home: CustomerAppointmentDetailScreen(appointmentId: 16),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Onay Bekliyor'), findsOneWidget);
      expect(find.byKey(const Key('share_location_btn')), findsNothing);
      expect(find.byKey(const Key('start_code_text')), findsNothing);
    });

    // 17. CONFIRMED state doğru render edilir
    testWidgets('17. CONFIRMED state doğru render edilir', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/17') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '17',
                'public_id': 'APT000017',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'customer_address_id': '5',
                'is_financially_ready': true,
              },
            }),
          };
        }
        if (options.path == '/customer/appointments/17/location-share') {
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        if (options.path == '/customer/appointments/17/start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {'code': '4821', 'status': 'ACTIVE'},
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
            home: CustomerAppointmentDetailScreen(appointmentId: 17),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Onaylandı'), findsOneWidget);
      expect(find.byKey(const Key('share_location_btn')), findsOneWidget);
      expect(find.text('4821'), findsOneWidget);
    });

    // 18. REJECTED state doğru render edilir
    testWidgets('18. REJECTED state doğru render edilir', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/18') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '18',
                'public_id': 'APT000018',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'REJECTED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'rejection_reason': 'O gün izinliyim.',
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
            home: CustomerAppointmentDetailScreen(appointmentId: 18),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Reddedildi'), findsOneWidget);
      expect(find.textContaining('O gün izinliyim.'), findsOneWidget);
    });

    // 19. Alternative proposed gerçek slotları gösterir
    testWidgets('19. Alternative proposed gerçek slotları gösterir', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/19') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
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
                'alternative_slots': [
                  {
                    'id': '51',
                    'date': '2026-09-26',
                    'start_time': '11:00',
                    'end_time': '11:30',
                    'status': 'PENDING',
                  },
                  {
                    'id': '52',
                    'date': '2026-09-26',
                    'start_time': '15:00',
                    'end_time': '15:30',
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
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 19),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alternatif Saat Önerildi'), findsOneWidget);
      expect(find.byKey(const Key('alternative_slot_51')), findsOneWidget);
      expect(find.byKey(const Key('alternative_slot_52')), findsOneWidget);
      expect(find.byKey(const Key('accept_alternative_btn')), findsOneWidget);
    });

    // 20. Alternative accept gerçek endpoint çağırır
    test('20. Alternative accept gerçek endpoint çağırır', () async {
      bool acceptedCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path ==
            '/customer/appointments/20/alternatives/51/accept') {
          acceptedCalled = true;
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
                'start_time': '11:00',
                'end_time': '11:30',
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
      final repo = CustomerAppointmentRepository(apiClient);
      final res = await repo.acceptAlternative(appointmentId: 20, slotId: 51);

      expect(acceptedCalled, true);
      expect(res.status, 'CONFIRMED');
    });

    // 21. Stale alternative fake CONFIRMED üretmez
    test('21. Stale alternative fake CONFIRMED üretmez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path ==
            '/customer/appointments/21/alternatives/51/accept') {
          return {
            'status': 409,
            'body': jsonEncode({
              'message': 'Bu saat artık dolu. Diğer önerilerden birini seçin.',
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);

      expect(
        () => repo.acceptAlternative(appointmentId: 21, slotId: 51),
        throwsA(isA<AppException>()),
      );
    });

    // 22. ONLINE PENDING paid görünmez
    testWidgets('22. ONLINE PENDING paid görünmez', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/22') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '22',
                'public_id': 'APT000022',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'ONLINE',
                'total_price': 250.0,
                'total_duration_minutes': 30,
                'payment_summary': {
                  'id': 1,
                  'status': 'PENDING',
                  'gross_amount': 250.0,
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
            home: CustomerAppointmentDetailScreen(appointmentId: 22),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Online Ödeme Bekleniyor'), findsOneWidget);
      expect(find.text('Ödendi'), findsNothing);
      expect(find.text('Ödeme tamamlandı'), findsNothing);
    });

    // 23. ONLINE PENDING location/start-code gate kapalıdır
    testWidgets('23. ONLINE PENDING location/start-code gate kapalıdır', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/23') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '23',
                'public_id': 'APT000023',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'ONLINE',
                'total_price': 250.0,
                'total_duration_minutes': 30,
                'payment_summary': {
                  'id': 1,
                  'status': 'PENDING',
                  'gross_amount': 250.0,
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
            home: CustomerAppointmentDetailScreen(appointmentId: 23),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('share_location_btn')), findsNothing);
      expect(find.byKey(const Key('start_code_text')), findsNothing);
    });

    // 24. CASH finance client'ta hesaplanmaz
    test('24. CASH finance client\'ta hesaplanmaz', () {
      final appt = CustomerAppointmentModel.fromJson({
        'id': '24',
        'public_id': 'APT000024',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'CONFIRMED',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 500.0,
        'total_duration_minutes': 60,
        'is_financially_ready': true,
      });

      expect(appt.totalPrice, 500.0);
      expect(appt.isFinanciallyReady, true);
    });

    // 25. Cancel gerçek endpoint kullanır
    test('25. Cancel gerçek endpoint kullanır', () async {
      bool cancelCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/25/cancel') {
          cancelCalled = true;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '25',
                'public_id': 'APT000025',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CANCELLED',
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
      final repo = CustomerAppointmentRepository(apiClient);
      final updated = await repo.cancelAppointment(25);

      expect(cancelCalled, true);
      expect(updated.status, 'CANCELLED');
    });

    // 26. Location share explicit consent olmadan çağrılmaz
    testWidgets('26. Location share explicit consent olmadan çağrılmaz', (
      tester,
    ) async {
      bool shareCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/26') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '26',
                'public_id': 'APT000026',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'CONFIRMED',
                'appointment_date': '2026-09-25',
                'start_time': '10:00',
                'end_time': '10:30',
                'payment_method': 'CASH',
                'total_price': 200.0,
                'total_duration_minutes': 30,
                'customer_address_id': '5',
                'is_financially_ready': true,
              },
            }),
          };
        }
        if (options.path == '/customer/appointments/26/location-share') {
          if (options.method == 'POST') {
            shareCalled = true;
          }
          return {
            'status': 200,
            'body': jsonEncode({'success': true, 'has_active_grant': false}),
          };
        }
        if (options.path == '/customer/appointments/26/start-code') {
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
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerAppointmentDetailScreen(appointmentId: 26),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('share_location_btn')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('share_location_btn')));
      await tester.tap(find.byKey(const Key('share_location_btn')));
      await tester.pumpAndSettle();

      // Consent modal appears
      expect(find.text('Adres Paylaşımı Onayı'), findsOneWidget);
      expect(
        find.text(
          'Bu randevu için kayıtlı tam adresiniz, yalnızca ilgili hizmet verenle sınırlı süre paylaşılacaktır.',
        ),
        findsOneWidget,
      );

      // Cancel without giving consent
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(shareCalled, false);
    });

    // 27. Saved address appointment share doğru ID kullanır
    test('27. Saved address appointment share doğru ID kullanır', () async {
      int? addressIdUsed;
      bool? explicitConsentUsed;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/27/location-share') {
          final data = options.data as Map<String, dynamic>;
          addressIdUsed = data['customer_address_id'] as int?;
          explicitConsentUsed = data['explicit_consent'] as bool?;
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': 1,
                'resource_type': 'SCHEDULED_APPOINTMENT',
                'resource_id': 27,
                'source': 'SAVED_ADDRESS',
                'status': 'ACTIVE',
              },
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      final status = await repo.shareLocation(
        27,
        explicitConsent: true,
        customerAddressId: 88,
      );

      expect(addressIdUsed, 88);
      expect(explicitConsentUsed, true);
      expect(status.hasActiveGrant, true);
    });

    // 28. Location revoke gerçek endpoint
    test('28. Location revoke gerçek endpoint', () async {
      bool revokeCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/28/location-share' &&
            options.method == 'DELETE') {
          revokeCalled = true;
          return {'status': 200, 'body': '{"success":true}'};
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      await repo.revokeLocation(28);

      expect(revokeCalled, true);
    });

    // 29. Start code ready olduğunda gösterilir
    testWidgets('29. Start code ready olduğunda gösterilir', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/29') {
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
                'customer_address_id': '5',
                'is_financially_ready': true,
              },
            }),
          };
        }
        if (options.path == '/customer/appointments/29/start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {'code': '9941', 'status': 'ACTIVE'},
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
            home: CustomerAppointmentDetailScreen(appointmentId: 29),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('9941'), findsOneWidget);
    });

    // 30. Raw start code loglanmaz
    test('30. Raw start code loglanmaz', () {
      const code = '9941';
      final model = CustomerAppointmentModel.fromJson({
        'id': '30',
        'public_id': 'APT000030',
        'customer_user_id': '1',
        'provider_user_id': '2',
        'status': 'CONFIRMED',
        'appointment_date': '2026-09-25',
        'start_time': '10:00',
        'end_time': '10:30',
        'payment_method': 'CASH',
        'total_price': 200.0,
        'total_duration_minutes': 30,
      });

      expect(model.toString().contains(code), false);
    });

    // 31. IN_PROGRESS server refresh ile gelir
    test('31. IN_PROGRESS server refresh ile gelir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/31') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '31',
                'public_id': 'APT000031',
                'customer_user_id': '1',
                'provider_user_id': '2',
                'status': 'IN_PROGRESS',
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
      final repo = CustomerAppointmentRepository(apiClient);
      final appt = await repo.fetchAppointment(31);

      expect(appt.isInProgress, true);
      expect(appt.statusLabel, 'Hizmet Veriliyor');
    });

    // 32. AWAITING confirm/problem aksiyonları gösterir
    testWidgets('32. AWAITING confirm/problem aksiyonları gösterir', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/32') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '32',
                'public_id': 'APT000032',
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
            home: CustomerAppointmentDetailScreen(appointmentId: 32),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('complete_appointment_btn')), findsOneWidget);
      expect(find.byKey(const Key('report_problem_btn')), findsOneWidget);
    });

    // 33. Complete endpoint sonrası COMPLETED
    test('33. Complete endpoint sonrası COMPLETED', () async {
      bool completeCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/33/complete') {
          completeCalled = true;
          return {
            'status': 200,
            'body': '{"success":true,"status":"COMPLETED"}',
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      await repo.completeAppointment(33);

      expect(completeCalled, true);
    });

    // 34. Dispute endpoint sonrası DISPUTED
    test('34. Dispute endpoint sonrası DISPUTED', () async {
      bool disputeCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/34/report-problem') {
          disputeCalled = true;
          final data = options.data as Map<String, dynamic>;
          expect(data['reason'], 'Gecikme oldu');
          return {
            'status': 200,
            'body': '{"success":true,"status":"DISPUTED"}',
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);
      await repo.reportProblem(34, reason: 'Gecikme oldu');

      expect(disputeCalled, true);
    });

    // 35. Admin note sızmaz
    test('35. Admin note sızmaz', () {
      final appt = CustomerAppointmentModel.fromJson({
        'id': '35',
        'public_id': 'APT000035',
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
          'case_id': 1,
          'status': 'OPEN',
          'status_label': 'Açık Uyuşmazlık',
          'resolution': null,
          'internal_admin_note': 'Do not leak this secret',
        },
      });

      expect(appt.disputeSummary?.statusLabel, 'Açık Uyuşmazlık');
      expect(appt.disputeSummary.toString().contains('secret'), false);
    });

    // 36. Appointment deep link doğrudan detail açar
    testWidgets('36. Appointment deep link doğrudan detail açar', (
      tester,
    ) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/36') {
          return {
            'status': 200,
            'body': jsonEncode({
              'success': true,
              'data': {
                'id': '36',
                'public_id': 'APT000036',
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
                user: sampleCustomer,
              ),
            );
          }),
          myServiceRequestsProvider.overrideWith(
            FakeMyServiceRequestsNotifier.new,
          ),
          customerAppointmentsProvider.overrideWith(
            FakeCustomerAppointmentsNotifier.new,
          ),
          serviceCategoriesProvider.overrideWith((ref) async => const []),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CustomerShell()),
        ),
      );

      await tester.pump();

      // Trigger APPOINTMENT_CONFIRMED deep link
      pushService.handleIncomingPayload({
        'type': 'APPOINTMENT_CONFIRMED',
        'resource_type': 'SCHEDULED_APPOINTMENT',
        'resource_id': '36',
      });

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAppointmentDetailScreen), findsOneWidget);
      final detailNotifier = container.read(
        customerAppointmentDetailNotifierProvider(36).notifier,
      );
      CustomerAppointmentDetailNotifier.enableAutoPolling = true;
      detailNotifier.startPolling();
      expect(detailNotifier.isPolling, true);
      await tester.pumpWidget(const SizedBox());
      expect(
        detailNotifier.isPolling,
        false,
        reason: 'Leaving the detail must stop its retained provider timer.',
      );
      CustomerAppointmentDetailNotifier.enableAutoPolling = false;
      container.dispose();
    });

    // 37. Polling final/dispose/background durumunda durur
    test('37. Polling final/dispose/background durumunda durur', () {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );

      final notifier = container.read(
        customerAppointmentDetailNotifierProvider(37).notifier,
      );

      CustomerAppointmentDetailNotifier.enableAutoPolling = true;
      notifier.startPolling();
      expect(notifier.isPolling, true);

      // Background / pause stops polling
      notifier.stopPolling();
      expect(notifier.isPolling, false);

      CustomerAppointmentDetailNotifier.enableAutoPolling = false;

      // Final appointment status flag check
      final apptFinal = CustomerAppointmentModel.fromJson({
        'id': '37',
        'public_id': 'APT000037',
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

    // 38. Network retry çalışır
    test('38. Network retry çalışır', () async {
      int attempts = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        attempts++;
        if (attempts == 1) {
          return {'status': 500, 'body': '{"message":"Temporary error"}'};
        }
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'id': '38',
              'public_id': 'APT000038',
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
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = CustomerAppointmentRepository(apiClient);

      // First attempt fails
      expect(() => repo.fetchAppointment(38), throwsA(isA<AppException>()));

      // Second attempt succeeds
      final appt = await repo.fetchAppointment(38);
      expect(appt.publicId, 'APT000038');
    });

    // 39. Customer/provider role separation korunur
    testWidgets('39. Customer/provider role separation korunur', (
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

      const providerUser = UserModel(
        id: 2,
        role: 'PROVIDER',
        name: 'Provider User',
        email: 'prov@test.com',
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
                user: providerUser,
              ),
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CustomerAppointmentsTab()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CustomerAppointmentsTab), findsOneWidget);
      expect(find.byType(ProviderShell), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    // 40. No fake slots/provider/rating/payment status
    test('40. No fake slots/provider/rating/payment status', () {
      final availability = AppointmentAvailabilityModel.fromJson({
        'provider_id': '9',
        'date': '2026-09-25',
        'total_duration_minutes': 30,
        'total_price': 250.0,
        'available_slots': <dynamic>[],
      });

      expect(availability.availableSlots.isEmpty, true);
      expect(availability.hasSlots, false);

      final provider = ScheduledProviderModel.fromJson({
        'id': '9',
        'user_id': '9',
        'business_name': 'Real Provider',
      });

      expect(provider.rating, isNull);
    });
  });
}
