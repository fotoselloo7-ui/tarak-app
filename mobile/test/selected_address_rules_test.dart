import 'dart:async';
import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/appointments/models/scheduled_provider_model.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/customer/appointments/screens/create_appointment_screen.dart';
import 'package:app/features/customer/models/customer_address.dart';
import 'package:app/features/customer/models/service_item.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/customer/screens/home_sections.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements HttpClientAdapter {
  final queries = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode({'data': [], 'sponsored': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('no provider request precedes address choice; selected address replaces device and resets dependent selections', () async {
    final adapter = _Api();
    final api = ApiClient(
      storage: SecureStorageService(),
      customDio: Dio()..httpClientAdapter = adapter,
    );
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        listOriginProvider.overrideWithValue(
          const ListOrigin(lat: 36.49, lng: 32.09, fromDevice: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(appointmentWizardProvider.notifier);
    notifier.toggleService(const ServiceItem(id: 1, name: 'Saç Kesimi'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(adapter.queries, isEmpty);
    notifier.selectAddress(
      const CustomerAddress(id: 2, latitude: 41.06, longitude: 28.99),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(adapter.queries.last, containsPair('customer_address_id', 2));
    expect(adapter.queries.last, containsPair('lat', 41.06));
    expect(adapter.queries.last, containsPair('sort', 'distance'));
    expect(adapter.queries.last, containsPair('max_distance_km', 50));
    notifier.selectProvider(const ScheduledProviderModel(id: 1, userId: 8));
    notifier.selectSlot('10:00');
    notifier.selectAddress(
      const CustomerAddress(id: 1, latitude: 36.49, longitude: 32.09),
    );
    expect(container.read(appointmentWizardProvider).selectedProvider, isNull);
    expect(container.read(appointmentWizardProvider).selectedSlot, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      adapter.queries.where((q) => q['customer_address_id'] == 1),
      isNotEmpty,
    );
  });

  testWidgets(
    'the first scheduled step requires explicit saved-address selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerAddressesProvider.overrideWith(
              (ref) async => const [
                CustomerAddress(
                  id: 1,
                  title: 'Ev',
                  isDefault: true,
                  latitude: 36.49,
                  longitude: 32.09,
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: CreateAppointmentScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1. Adres Seçimi'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('wizard_next_btn')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('address_item_1')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('wizard_next_btn')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'changing the default address refreshes the mounted home nearby query',
    (tester) async {
      final adapter = _Api();
      final api = ApiClient(
        storage: SecureStorageService(),
        customDio: Dio()..httpClientAdapter = adapter,
      );
      var addresses = const [
        CustomerAddress(
          id: 8,
          isDefault: true,
          latitude: 41.06,
          longitude: 28.99,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authNotifierProvider.overrideWith(
              () => AuthNotifier(
                initialState: const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(id: 1, role: 'CUSTOMER', name: 'Test'),
                ),
              ),
            ),
            customerAddressesProvider.overrideWith((ref) async => addresses),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HomeNearbyProvidersSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(adapter.queries.last['customer_address_id'], 8);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeNearbyProvidersSection)),
      );
      addresses = const [
        CustomerAddress(
          id: 12,
          isDefault: true,
          latitude: 36.49,
          longitude: 32.09,
        ),
      ];
      container.invalidate(customerAddressesProvider);
      await tester.pumpAndSettle();
      expect(adapter.queries.last['customer_address_id'], 12);
      expect(adapter.queries.last['lat'], 36.49);
    },
  );

  for (final gender in ['female', 'male', 'unspecified']) {
    testWidgets(
      'nearby title and API type follow $gender and use the default address id',
      (tester) async {
        final adapter = _Api();
        final api = ApiClient(
          storage: SecureStorageService(),
          customDio: Dio()..httpClientAdapter = adapter,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              authNotifierProvider.overrideWith(
                () => AuthNotifier(
                  initialState: AuthState(
                    status: AuthStatus.authenticated,
                    user: UserModel(
                      id: 1,
                      role: 'CUSTOMER',
                      name: 'Test',
                      gender: gender,
                    ),
                  ),
                ),
              ),
              customerAddressesProvider.overrideWith(
                (ref) async => const [
                  CustomerAddress(
                    id: 8,
                    isDefault: true,
                    latitude: 41.06,
                    longitude: 28.99,
                  ),
                ],
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HomeNearbyProvidersSection(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            gender == 'male' ? 'Size Yakın Berberler' : 'Size Yakın Kuaförler',
          ),
          findsOneWidget,
        );
        expect(adapter.queries.last['customer_address_id'], 8);
        expect(
          adapter.queries.last['type'],
          gender == 'male'
              ? 'barber'
              : gender == 'female'
              ? 'coiffeur'
              : null,
        );
      },
    );
  }
}
