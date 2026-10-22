import 'dart:convert';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/offerings/models/offering_models.dart';
import 'package:app/features/offerings/repositories/offerings_repository.dart';
import 'package:app/features/offerings/screens/customer_offering_screens.dart';
import 'package:app/features/offerings/screens/provider_offerings_screen.dart';
import 'package:app/features/provider/instant/repositories/provider_instant_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/app_theme.dart';
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

Map<String, dynamic> _providerJson({bool online = true}) => {
      'user_id': '7',
      'business_name': 'Mehmet Berber',
      'provider_type': 'barber',
      'city': 'İstanbul',
      'district': 'Şişli',
      'is_verified': true,
      'is_online': online,
      'rating': null,
      'review_count': 0,
    };

Map<String, dynamic> _bundleJson({bool serviceAvailable = true}) => {
      'provider': _providerJson(),
      'services': [
        {
          'provider_service_id': 11,
          'service_id': 1,
          'name': 'Saç Kesimi',
          'description': 'Yıkama dahil',
          'price': 450,
          'duration_minutes': 30,
          'availability': {
            'available': serviceAvailable,
            'reason': serviceAvailable ? null : 'Hizmet veren şu anda çalışma saatleri dışında.',
            'distance_km': serviceAvailable ? 0.2 : null,
          },
        },
      ],
      'packages': [
        {
          'provider_package_id': 5,
          'title': 'Damat Hazırlık Paketi',
          'description': null,
          'price': 1250,
          'duration_minutes': 90,
          'is_active': true,
          'services': [
            {'service_id': 1, 'name': 'Saç Kesimi'},
            {'service_id': 2, 'name': 'Sakal Tıraşı'},
          ],
          'availability': {'available': true, 'reason': null, 'distance_km': 0.2},
        },
      ],
    };

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

  group('Models', () {
    test('Provider offerings bundle parses services, packages and availability', () {
      final b = ProviderOfferingsBundle.fromJson(_bundleJson(serviceAvailable: false));
      expect(b.provider.userId, 7);
      expect(b.provider.rating, isNull);
      expect(b.provider.region, 'Şişli, İstanbul');
      expect(b.services.single.price, 450);
      expect(b.services.single.availability.available, isFalse);
      expect(b.services.single.availability.reason, contains('çalışma saatleri'));
      expect(b.packages.single.services.map((s) => s.name), ['Saç Kesimi', 'Sakal Tıraşı']);
      expect(b.packages.single.availability.available, isTrue);
    });

    test('Direct request carries immutable offering snapshot', () {
      final r = ServiceRequestModel.fromJson({
        'id': 99,
        'status': 'OPEN',
        'payment_method': 'CASH',
        'services': [],
        'is_direct': true,
        'target_provider': {'id': 7, 'business_name': 'Mehmet Berber'},
        'offering': {
          'type': 'PACKAGE',
          'title': 'Damat Hazırlık Paketi',
          'price': 1250,
          'duration_minutes': 90,
          'items': [
            {'service_id': 1, 'name': 'Saç Kesimi'},
            {'service_id': 2, 'name': 'Sakal Tıraşı'},
          ],
        },
      });
      expect(r.isDirect, isTrue);
      expect(r.offering!.isPackage, isTrue);
      expect(r.offering!.price, 1250);
      expect(r.offering!.items, ['Saç Kesimi', 'Sakal Tıraşı']);
      expect(r.targetProviderName, 'Mehmet Berber');
      expect(r.statusLabel, 'Uzman Yanıtı Bekleniyor');
    });

    test('Generic request stays non-direct', () {
      final r = ServiceRequestModel.fromJson({'id': 1, 'status': 'OPEN', 'payment_method': 'CASH', 'services': []});
      expect(r.isDirect, isFalse);
      expect(r.offering, isNull);
      expect(r.statusLabel, 'Teklif Bekleniyor');
    });

    test('formatTry uses Turkish thousands separator', () {
      expect(formatTry(1250), '₺1.250');
      expect(formatTry(450), '₺450');
    });
  });

  group('Provider repository', () {
    test('saveService PATCHes own price, duration, description and active flag', () async {
      RequestOptions? captured;
      final repo = ProviderOfferingsRepository(client((o) {
        captured = o;
        return {
          'body': {
            'success': true,
            'data': {'id': '3', 'service_id': '1', 'name': 'Saç Kesimi', 'price': 450, 'duration_min': 30, 'description': 'Yıkama dahil', 'is_active': false},
          },
        };
      }));

      final saved = await repo.saveService(serviceId: 1, price: 450, durationMinutes: 30, description: ' Yıkama dahil ', isActive: false);

      expect(captured!.method, 'PATCH');
      expect(captured!.path, '/provider/services');
      expect(captured!.data, {
        'service_id': 1,
        'custom_price': 450.0,
        'custom_duration_minutes': 30,
        'description': 'Yıkama dahil',
        'is_active': false,
      });
      expect(saved.isActive, isFalse);
      expect(saved.price, 450);
    });

    test('createPackage POSTs multiple services with price and duration', () async {
      RequestOptions? captured;
      final repo = ProviderOfferingsRepository(client((o) {
        captured = o;
        return {'status': 201, 'body': {'success': true, 'data': _bundleJson()['packages'][0]}};
      }));

      final pkg = await repo.createPackage(
        title: 'Damat Hazırlık Paketi',
        price: 1250,
        durationMinutes: 90,
        serviceIds: [1, 2, 3],
      );

      expect(captured!.method, 'POST');
      expect(captured!.path, '/provider/packages');
      final body = captured!.data as Map;
      expect(body['service_ids'], [1, 2, 3]);
      expect(body['price'], 1250.0);
      expect(body['duration_minutes'], 90);
      expect(pkg.title, 'Damat Hazırlık Paketi');
    });

    test('Provider accepts a direct call with ETA only (price comes from snapshot)', () async {
      RequestOptions? captured;
      final repo = ProviderInstantRepository(client((o) {
        captured = o;
        return {
          'body': {'success': true, 'data': {'id': 99, 'status': 'ASSIGNED', 'payment_method': 'CASH', 'services': [], 'is_direct': true}},
        };
      }));

      final r = await repo.acceptDirectRequest(99, estimatedArrivalMin: 15);
      expect(captured!.path, '/provider/service-requests/99/accept-direct');
      expect(captured!.data, {'estimated_arrival_min': 15});
      expect((captured!.data as Map).containsKey('price'), isFalse);
      expect(r.isAssigned, isTrue);
    });

    test('Provider declines a direct call', () async {
      RequestOptions? captured;
      final repo = ProviderInstantRepository(client((o) {
        captured = o;
        return {'body': {'success': true, 'message': 'Talep reddedildi.'}};
      }));
      await repo.declineDirectRequest(99, reason: 'Yoldayım');
      expect(captured!.path, '/provider/service-requests/99/decline-direct');
      expect(captured!.data, {'reason': 'Yoldayım'});
    });
  });

  group('Customer repository', () {
    test('Find providers by service sends customer address for radius/availability', () async {
      RequestOptions? captured;
      final repo = CustomerOfferingsRepository(client((o) {
        captured = o;
        return {
          'body': {
            'success': true,
            'data': {
              'service': {'id': 1, 'name': 'Saç Kesimi'},
              'providers': [
                {
                  'provider': _providerJson(),
                  'offering': _bundleJson()['services'][0],
                  'availability': {'available': true, 'reason': null, 'distance_km': 0.2},
                },
              ],
            },
          },
        };
      }));

      final list = await repo.fetchProvidersForService(1, addressId: 4);
      expect(captured!.path, '/customer/services/1/providers');
      expect(captured!.queryParameters, {'customer_address_id': 4});
      expect(list.single.offering.price, 450);
      expect(list.single.offering.availability.available, isTrue);
    });

    test('Direct call on a provider service targets the offering, not generic service_ids', () async {
      RequestOptions? captured;
      final repo = CustomerOfferingsRepository(client((o) {
        captured = o;
        return {
          'status': 201,
          'body': {'success': true, 'data': {'id': 50, 'status': 'OPEN', 'payment_method': 'CASH', 'services': [], 'is_direct': true}},
        };
      }));

      final created = await repo.createDirectRequest(providerServiceId: 11, addressId: 4, note: '  ');
      final body = captured!.data as Map;
      expect(captured!.path, '/customer/service-requests');
      expect(body['provider_service_id'], 11);
      expect(body.containsKey('provider_package_id'), isFalse);
      expect(body.containsKey('service_ids'), isFalse);
      expect(body.containsKey('customer_note'), isFalse);
      expect(body['payment_method'], 'CASH');
      expect(created.isDirect, isTrue);
    });

    test('Direct call on a package sends provider_package_id', () async {
      RequestOptions? captured;
      final repo = CustomerOfferingsRepository(client((o) {
        captured = o;
        return {
          'status': 201,
          'body': {'success': true, 'data': {'id': 51, 'status': 'OPEN', 'payment_method': 'ONLINE', 'services': [], 'is_direct': true}},
        };
      }));

      await repo.createDirectRequest(providerPackageId: 5, addressId: 4, paymentMethod: 'ONLINE');
      final body = captured!.data as Map;
      expect(body['provider_package_id'], 5);
      expect(body.containsKey('provider_service_id'), isFalse);
      expect(body['payment_method'], 'ONLINE');
    });
  });

  group('Screens', () {
    testWidgets('Provider Hizmetlerim shows catalog with own offering and packages tab', (tester) async {
      final api = client((o) {
        if (o.path == '/service-categories') {
          return {
            'body': {
              'success': true,
              'data': [
                {
                  'id': 'cat-1',
                  'name': 'Erkek Bakım',
                  'services': [
                    {'id': '1', 'name': 'Saç Kesimi', 'category_id': 'cat-1', 'duration_minutes': 30, 'base_price': 250},
                    {'id': '2', 'name': 'Sakal Tıraşı', 'category_id': 'cat-1', 'duration_minutes': 20, 'base_price': 150},
                  ],
                },
              ],
            },
          };
        }
        if (o.path == '/provider/services') {
          return {
            'body': {
              'success': true,
              'data': [
                {'id': '3', 'service_id': '1', 'name': 'Saç Kesimi', 'price': 450, 'duration_min': 30, 'description': null, 'is_active': true},
              ],
            },
          };
        }
        if (o.path == '/provider/packages') {
          return {'body': {'success': true, 'data': _bundleJson()['packages']}};
        }
        return {'status': 404, 'body': {}};
      });

      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: ProviderOfferingsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Saç Kesimi'), findsOneWidget);
      expect(find.textContaining('₺450'), findsOneWidget);
      expect(find.textContaining('Sunulmuyor'), findsOneWidget);

      await tester.tap(find.text('Özel Paketler'));
      await tester.pumpAndSettle();
      expect(find.text('Damat Hazırlık Paketi'), findsOneWidget);
      expect(find.text('₺1.250'), findsOneWidget);
      expect(find.byKey(const Key('new_package_button')), findsOneWidget);
    });

    testWidgets('Customer provider detail lists services & packages and disables unavailable CTA', (tester) async {
      final api = client((o) {
        if (o.path == '/customer/addresses') {
          return {
            'body': {
              'success': true,
              'data': [
                {'id': 4, 'title': 'Ev', 'province': 'İstanbul', 'district': 'Şişli', 'is_default': true},
              ],
            },
          };
        }
        if (o.path == '/customer/providers/7/offerings') {
          return {'body': {'success': true, 'data': _bundleJson(serviceAvailable: false)}};
        }
        return {'status': 404, 'body': {}};
      });

      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const ProviderOfferingsDetailScreen(providerUserId: 7)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mehmet Berber'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Henüz değerlendirme yok'), findsOneWidget);
      expect(find.text('Saç Kesimi'), findsOneWidget);
      expect(find.textContaining('çalışma saatleri'), findsOneWidget);

      final serviceCta = tester.widget<ButtonStyleButton>(
        find.ancestor(of: find.text('Hemen Çağır'), matching: find.bySubtype<ButtonStyleButton>()).first,
      );
      expect(serviceCta.onPressed, isNull);

      await tester.tap(find.textContaining('Paketler'));
      await tester.pumpAndSettle();
      expect(find.text('Damat Hazırlık Paketi'), findsOneWidget);

      await tester.tap(find.text('Hemen Çağır'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('direct_call_submit')), findsOneWidget);
      expect(find.text('₺1.250 ile Çağır'), findsOneWidget);
    });
  });
}
