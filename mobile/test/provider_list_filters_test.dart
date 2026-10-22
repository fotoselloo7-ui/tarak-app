import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/customer/appointments/repositories/customer_appointment_repository.dart';
import 'package:app/features/customer/models/service_item.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/offerings/repositories/offerings_repository.dart';
import 'package:app/features/offerings/screens/customer_offering_screens.dart';
import 'package:app/features/shared/widgets/provider_list_tools.dart';
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
    final named = invocation.namedArguments;
    if (invocation.memberName == #read) return Future<String?>.value(data[named[#key] as String]);
    if (invocation.memberName == #write) {
      data[named[#key] as String] = '${named[#value]}';
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      data.remove(named[#key] as String);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions o) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final r = handler(options);
    return ResponseBody.fromString(
      jsonEncode(r['body'] ?? {}),
      r['status'] as int? ?? 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeLocator implements DeviceLocator {
  final ListOrigin? origin;
  int calls = 0;
  _FakeLocator({this.origin});

  @override
  Future<ListOrigin> locate() async {
    calls++;
    if (origin == null) throw const DeviceLocationException(DeviceLocationStatus.denied);
    return origin!;
  }
}

Map<String, dynamic> _card(int id, String name, {double? rating = 4.5, int reviews = 10, double? km, bool sponsored = false}) => {
      'id': '$id',
      'user_id': '$id',
      'business_name': name,
      'name': name,
      'provider_type': 'barber',
      'city': 'İstanbul',
      'district': 'Şişli',
      'is_verified': true,
      'is_approved': true,
      'rating': rating,
      'review_count': reviews,
      'distance_km': km,
      if (sponsored) 'is_sponsored': true,
    };

/// Dio answers through several event-loop turns: pump a few frames instead of one.
Future<void> _pumpFor(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SecureStorageService(secureStorage: _FakeStorage());
    await storage.init();
  });

  ApiClient client(Map<String, dynamic> Function(RequestOptions o) handler) {
    final dio = Dio()..httpClientAdapter = _Adapter(handler);
    return ApiClient(storage: storage, customDio: dio);
  }

  group('filters', () {
    test('query carries only what is set; the position adds lat / lng and unlocks the radius and nearest sort', () {
      expect(const ProviderListFilters().toQuery(null), isEmpty);
      expect(const ProviderListFilters().isActive, isFalse);

      const filters = ProviderListFilters(q: '  Bursa ', minRating: 4, maxDistanceKm: 10, sort: ProviderSort.distance);
      expect(filters.isActive, isTrue);
      // No position: no radius, and "en yakın" cannot be asked for.
      expect(filters.toQuery(null), {'q': 'Bursa', 'min_rating': 4});
      expect(filters.toQuery(const ListOrigin(lat: 41.00821234, lng: 28.97844567)), {
        'q': 'Bursa',
        'min_rating': 4,
        'lat': 41.00821,
        'lng': 28.97845,
        'max_distance_km': 10,
        'sort': 'distance',
      });
      // The radius alone needs a position too.
      expect(const ProviderListFilters(maxDistanceKm: 5).toQuery(null), isEmpty);
    });

    test('distances read like on the web: metres under a kilometre, one decimal under ten', () {
      expect(formatDistanceKm(null), isNull);
      expect(formatDistanceKm(0.43), '400 m');
      expect(formatDistanceKm(2.4), '2,4 km');
      expect(formatDistanceKm(12.6), '13 km');
      expect(formatDistanceKm('3'), '3 km');
    });
  });

  group('origin', () {
    test('the device position is asked for once and wins over the saved address', () async {
      final locator = _FakeLocator(origin: const ListOrigin(lat: 39.9, lng: 32.8, fromDevice: true));
      final container = ProviderContainer(overrides: [deviceLocatorProvider.overrideWithValue(locator)]);
      addTearDown(container.dispose);

      expect(container.read(listOriginProvider), isNull);
      await container.read(providerListOriginProvider.notifier).useDevice();
      expect(locator.calls, 1);
      final origin = container.read(listOriginProvider);
      expect(origin?.lat, 39.9);
      expect(origin?.fromDevice, isTrue);
    });

    test('a refused permission leaves no position and says why', () async {
      final container = ProviderContainer(overrides: [deviceLocatorProvider.overrideWithValue(_FakeLocator())]);
      addTearDown(container.dispose);

      await container.read(providerListOriginProvider.notifier).useDevice();
      expect(container.read(listOriginProvider), isNull);
      expect(container.read(providerListOriginProvider).status, DeviceLocationStatus.denied);
    });
  });

  group('appointment provider step', () {
    test('discovery sends the filters and keeps list ads apart from the organic list', () async {
      final seen = <Map<String, dynamic>>[];
      final api = client((o) {
        seen.add(Map<String, dynamic>.from(o.queryParameters));
        return {
          'body': {
            'success': true,
            'data': [_card(1, 'Organik Berber', km: 3.2)],
            'sponsored': [_card(2, 'Reklamlı Berber', km: 1.1, sponsored: true)],
          },
        };
      });
      final repo = CustomerAppointmentRepository(api);

      final list = await repo.fetchProviderList(serviceIds: [1, 2], filters: const {'q': 'berber', 'min_rating': 4});
      expect(seen.single, {'service_ids': '1,2', 'q': 'berber', 'min_rating': 4});
      expect(list.providers.single.displayName, 'Organik Berber');
      expect(list.providers.single.distanceKm, 3.2);
      expect(list.providers.single.reviewCount, 10);
      expect(list.sponsored.single.isSponsored, isTrue);
      expect(list.all.first.displayName, 'Reklamlı Berber');
    });

    test('changing a filter asks the backend again with the position of the customer', () async {
      final seen = <Map<String, dynamic>>[];
      final api = client((o) {
        seen.add(Map<String, dynamic>.from(o.queryParameters));
        return {
          'body': {
            'success': true,
            'data': [_card(1, 'Organik Berber')],
            'sponsored': [_card(2, 'Reklamlı Berber', sponsored: true)],
          },
        };
      });
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(api),
        listOriginProvider.overrideWithValue(const ListOrigin(lat: 41.0, lng: 29.0)),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(appointmentWizardProvider.notifier);
      notifier.toggleService(const ServiceItem(id: 5, name: 'Saç Kesimi'));
      await _settle();
      expect(seen.last['service_ids'], '5');
      expect(seen.last['lat'], 41.0);
      expect(container.read(appointmentWizardProvider).sponsoredProviders.single.displayName, 'Reklamlı Berber');
      expect(container.read(appointmentWizardProvider).availableProviders.single.displayName, 'Organik Berber');

      notifier.setProviderFilters(const ProviderListFilters(minRating: 4, maxDistanceKm: 10, sort: ProviderSort.rating));
      await _settle();
      expect(seen.last['min_rating'], 4);
      expect(seen.last['max_distance_km'], 10);
      expect(seen.last['sort'], 'rating');
      // Same filters again: no new request.
      final count = seen.length;
      notifier.setProviderFilters(const ProviderListFilters(minRating: 4, maxDistanceKm: 10, sort: ProviderSort.rating));
      await _settle();
      expect(seen.length, count);
    });
  });

  group('recommended rotation', () {
    test('the wizard asks for just the recommended cards again and swaps them in', () async {
      var sets = 0;
      final seen = <Map<String, dynamic>>[];
      final api = client((o) {
        seen.add(Map<String, dynamic>.from(o.queryParameters));
        if (o.queryParameters['sponsored_only'] == 1) {
          sets++;
          return {
            'body': {'success': true, 'sponsored': [_card(10 + sets, 'Öneri $sets', sponsored: true)], 'meta': {'rotation_seconds': 20}},
          };
        }
        return {
          'body': {
            'success': true,
            'data': [_card(1, 'Organik Berber'), _card(11, 'Öneri 1')],
            'sponsored': [_card(11, 'Öneri 1', sponsored: true)],
            'meta': {'rotation_seconds': 20},
          },
        };
      });
      final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(api), listOriginProvider.overrideWithValue(null)]);
      addTearDown(container.dispose);

      final notifier = container.read(appointmentWizardProvider.notifier);
      notifier.toggleService(const ServiceItem(id: 5, name: 'Saç Kesimi'));
      await _settle();
      expect(container.read(appointmentWizardProvider).rotationSeconds, 20);
      expect(container.read(appointmentWizardProvider).sponsoredProviders.single.displayName, 'Öneri 1');

      await notifier.refreshRecommended();
      expect(seen.last['sponsored_only'], 1);
      expect(seen.last['service_ids'], '5');
      expect(container.read(appointmentWizardProvider).sponsoredProviders.single.displayName, 'Öneri 1');
      await notifier.refreshRecommended();
      expect(container.read(appointmentWizardProvider).sponsoredProviders.single.displayName, 'Öneri 2');
      expect(container.read(appointmentWizardProvider).availableProviders.length, 2, reason: 'the organic list is left alone');
    });
  });

  group('service providers list', () {
    Map<String, dynamic> row(int id, String name, {bool sponsored = false, double? km, double price = 200}) => {
          'provider': _card(id, name, km: km, sponsored: sponsored),
          'offering': {'provider_service_id': 10 + id, 'service_id': 1, 'name': 'Saç Kesimi', 'price': price, 'duration_minutes': 30},
          'availability': {'available': true, 'reason': null},
        };

    test('the repository sends search / stars / distance / sort and parses the sponsored cards', () async {
      RequestOptions? captured;
      final repo = CustomerOfferingsRepository(client((o) {
        captured = o;
        return {
          'body': {
            'success': true,
            'data': {
              'service': {'id': 1, 'name': 'Saç Kesimi'},
              'providers': [row(1, 'Organik', km: 4.0)],
              'sponsored': [row(2, 'Reklamlı', sponsored: true, km: 0.8)],
            },
          },
        };
      }));

      final list = await repo.fetchServiceProviderList(1, addressId: 4, filters: const {'q': 'a', 'sort': 'price'});
      expect(captured!.queryParameters, {'q': 'a', 'sort': 'price', 'customer_address_id': 4});
      expect(list.providers.single.provider.distanceKm, 4.0);
      expect(list.sponsored.single.provider.isSponsored, isTrue);
      // The older call still returns everyone, ads first.
      final all = await repo.fetchProvidersForService(1);
      expect(all.map((r) => r.provider.name), ['Reklamlı', 'Organik']);
    });

    testWidgets('the screen shows the filter bar, a "Önerilen" slot first and re-queries when a filter changes', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final seen = <Map<String, dynamic>>[];
      final api = client((o) {
        seen.add(Map<String, dynamic>.from(o.queryParameters));
        return {
          'body': {
            'success': true,
            'data': {
              'service': {'id': 1, 'name': 'Saç Kesimi'},
              'providers': [row(1, 'Organik Berber', km: 4.0)],
              'sponsored': [row(2, 'Reklamlı Berber', sponsored: true, km: 0.8)],
            },
          },
        };
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          customerAddressesProvider.overrideWith((ref) async => const []),
          listOriginProvider.overrideWithValue(const ListOrigin(lat: 41.0, lng: 29.0)),
        ],
        child: const MaterialApp(home: ServiceProvidersScreen(serviceId: 1, serviceName: 'Saç Kesimi')),
      ));
      await _pumpFor(tester);
      await _pumpFor(tester);

      expect(find.byKey(const Key('provider_filter_search')), findsOneWidget);
      expect(find.byKey(const Key('recommended_slot')), findsOneWidget);
      expect(find.text('Önerilen'), findsOneWidget);
      expect(find.text('Reklamlı Berber'), findsOneWidget);
      expect(find.text('Organik Berber'), findsOneWidget);
      expect(find.text('800 m'), findsOneWidget);
      expect(seen.last['lat'], 41.0);

      await tester.ensureVisible(find.byKey(const Key('filter_rating_4+')));

      await tester.tap(find.byKey(const Key('filter_rating_4+')));
      await tester.pump();
      await _pumpFor(tester);
      expect(seen.last['min_rating'], 4);

      await tester.ensureVisible(find.byKey(const Key('filter_sort_price')));

      await tester.tap(find.byKey(const Key('filter_sort_price')));
      await tester.pump();
      await _pumpFor(tester);
      expect(seen.last['sort'], 'price');
      expect(seen.last['min_rating'], 4, reason: 'filters combine');
    });

    testWidgets('the recommended cards of a service change every rotation period', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var asked = 0;
      final api = client((o) {
        final only = o.queryParameters['sponsored_only'] == 1;
        if (only) asked++;
        return {
          'body': {
            'success': true,
            'data': {
              'service': {'id': 1, 'name': 'Saç Kesimi'},
              if (!only) 'providers': [row(1, 'Organik Berber'), row(2, 'Birinci Öneri'), row(3, 'İkinci Öneri')],
              'sponsored': [row(only ? 3 : 2, only ? 'İkinci Öneri' : 'Birinci Öneri', sponsored: true)],
              'meta': {'rotation_seconds': 20},
            },
          },
        };
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          customerAddressesProvider.overrideWith((ref) async => const []),
          listOriginProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: ServiceProvidersScreen(serviceId: 1, serviceName: 'Saç Kesimi')),
      ));
      await _pumpFor(tester);
      await _pumpFor(tester);

      expect(find.text('Birinci Öneri'), findsOneWidget, reason: 'in the slot only, not again below');
      expect(find.text('İkinci Öneri'), findsOneWidget, reason: 'listed organically while it is not in the slot');
      expect(asked, 0);

      await tester.pump(const Duration(seconds: 21));
      await _pumpFor(tester);
      expect(asked, 1);
      expect(find.text('İkinci Öneri'), findsOneWidget, reason: 'now in the slot, hidden below');
      expect(find.text('Birinci Öneri'), findsOneWidget, reason: 'rotated out: listed organically again');
    });
  });
}
