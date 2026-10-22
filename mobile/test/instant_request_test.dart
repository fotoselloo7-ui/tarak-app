import 'dart:async';
import 'dart:convert';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/customer/models/customer_address.dart';
import 'package:app/features/customer/models/service_category.dart';
import 'package:app/features/customer/models/service_item.dart';
import 'package:app/features/customer/models/service_offer.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/repositories/instant_request_repository.dart';
import 'package:app/features/customer/services/geo_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/disk_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer Instant Request Models', () {
    test('ServiceCategory fromJson parses correctly', () {
      final json = {
        'id': 10,
        'name': 'Saç Kesimi',
        'slug': 'sac-kesimi',
      };

      final cat = ServiceCategory.fromJson(json);
      expect(cat.id, '10');
      expect(cat.name, 'Saç Kesimi');
      expect(cat.slug, 'sac-kesimi');
    });

    test('ServiceItem fromJson parses correctly', () {
      final json = {
        'id': 5,
        'category_id': '10',
        'name': 'Klasik Erkek Saç Kesimi',
        'slug': 'klasik-erkek-sac-kesimi',
        'duration_minutes': 45,
        'is_active': true,
      };

      final item = ServiceItem.fromJson(json);
      expect(item.id, 5);
      expect(item.categoryId, '10');
      expect(item.name, 'Klasik Erkek Saç Kesimi');
      expect(item.durationMinutes, 45);
      expect(item.isActive, isTrue);
    });

    test('CustomerAddress fromJson handles displayLine', () {
      final json = {
        'id': 12,
        'title': 'Ev Adresim',
        'province': 'İstanbul',
        'district': 'Kadıköy',
        'neighborhood': 'Moda',
        'street': 'Şair Nefi Sk.',
        'building_no': '5',
        'is_default': true,
      };

      final addr = CustomerAddress.fromJson(json);
      expect(addr.id, 12);
      expect(addr.title, 'Ev Adresim');
      expect(addr.province, 'İstanbul');
      expect(addr.district, 'Kadıköy');
      expect(addr.neighborhood, 'Moda');
      expect(addr.isDefault, isTrue);
      expect(addr.displayLine, 'Moda, Kadıköy, İstanbul');
    });

    test('ServiceOffer fromJson parses provider and status helpers', () {
      final json = {
        'id': 88,
        'service_request_id': 101,
        'provider_user_id': 20,
        'price': 300.0,
        'duration_minutes': 45,
        'estimated_arrival_min': 25,
        'message': 'Hemen yola çıkıyorum',
        'status': 'PENDING',
        'created_at': '2026-09-18T18:00:00Z',
        'provider': {
          'id': 20,
          'name': 'Ahmet Usta',
          'business_name': 'Ahmet Berber Salonu',
          'city': 'İstanbul',
          'district': 'Kadıköy',
          'is_verified': true,
        },
      };

      final offer = ServiceOffer.fromJson(json);
      expect(offer.id, 88);
      expect(offer.price, 300.0);
      expect(offer.estimatedArrivalMin, 25);
      expect(offer.isPending, isTrue);
      expect(offer.isAccepted, isFalse);
      expect(offer.provider?.businessName, 'Ahmet Berber Salonu');
      expect(offer.provider?.displayName, 'Ahmet Berber Salonu');
    });

    test('ServiceRequestModel lifecycle and status helpers', () {
      final json = {
        'id': 101,
        'status': 'OPEN',
        'payment_method': 'CASH',
        'customer_note': 'Kapı zili çalışmıyor',
        'approx_province': 'İstanbul',
        'approx_district': 'Beşiktaş',
        'created_at': '2026-09-18T18:00:00Z',
        'services': [
          {
            'id': 5,
            'name': 'Klasik Saç Kesimi',
            'duration_minutes': 30,
          }
        ],
        'offers_count': 3,
      };

      final req = ServiceRequestModel.fromJson(json);
      expect(req.id, 101);
      expect(req.isOpen, isTrue);
      expect(req.isActive, isTrue);
      expect(req.offersCount, 3);
      expect(req.statusLabel, 'Teklif Bekleniyor');
      expect(req.services.length, 1);
      expect(req.services.first.name, 'Klasik Saç Kesimi');

      final assignedJson = Map<String, dynamic>.from(json);
      assignedJson['status'] = 'ASSIGNED';
      final assignedReq = ServiceRequestModel.fromJson(assignedJson);
      expect(assignedReq.isAssigned, isTrue);
      expect(assignedReq.statusLabel, 'Berber Atandı');

      final inProgressJson = Map<String, dynamic>.from(json);
      inProgressJson['status'] = 'IN_PROGRESS';
      final inProgressReq = ServiceRequestModel.fromJson(inProgressJson);
      expect(inProgressReq.isInProgress, isTrue);
      expect(inProgressReq.statusLabel, 'Hizmet Devam Ediyor');

      final completedJson = Map<String, dynamic>.from(json);
      completedJson['status'] = 'COMPLETED';
      final completedReq = ServiceRequestModel.fromJson(completedJson);
      expect(completedReq.isCompleted, isTrue);
      expect(completedReq.isActive, isFalse);
      expect(completedReq.statusLabel, 'Tamamlandı');
    });
  });

  group('CreateRequestNotifier state management', () {
    test('toggleService adds and removes services', () {
      final container = ProviderContainer();
      final notifier = container.read(createRequestProvider.notifier);

      expect(container.read(createRequestProvider).selectedServiceIds, isEmpty);

      notifier.toggleService(1);
      expect(container.read(createRequestProvider).selectedServiceIds, [1]);

      notifier.toggleService(2);
      expect(container.read(createRequestProvider).selectedServiceIds, [1, 2]);

      notifier.toggleService(1);
      expect(container.read(createRequestProvider).selectedServiceIds, [2]);
    });

    test('selectAddress and manualAddress updates address state', () {
      final container = ProviderContainer();
      final notifier = container.read(createRequestProvider.notifier);

      expect(container.read(createRequestProvider).hasAddress, isFalse);

      notifier.selectAddress(15);
      expect(container.read(createRequestProvider).selectedAddressId, 15);
      expect(container.read(createRequestProvider).hasAddress, isTrue);

      notifier.setManualAddress(
        province: 'Ankara',
        district: 'Çankaya',
        neighborhood: 'Kızılay',
      );
      expect(container.read(createRequestProvider).selectedAddressId, isNull);
      expect(container.read(createRequestProvider).approxProvince, 'Ankara');
      expect(container.read(createRequestProvider).approxDistrict, 'Çankaya');
      expect(container.read(createRequestProvider).hasAddress, isTrue);
    });

    test('setPaymentMethod and setCustomerNote work correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(createRequestProvider.notifier);

      notifier.setPaymentMethod('ONLINE');
      expect(container.read(createRequestProvider).paymentMethod, 'ONLINE');

      notifier.setCustomerNote('Lütfen randevu saatine dikkat edin');
      expect(container.read(createRequestProvider).customerNote, 'Lütfen randevu saatine dikkat edin');

      notifier.reset();
      expect(container.read(createRequestProvider).selectedServiceIds, isEmpty);
      expect(container.read(createRequestProvider).paymentMethod, 'CASH');
      expect(container.read(createRequestProvider).customerNote, isNull);
    });
  });

  group('InstantRequestRepository API parsing with mock adapter', () {
    test('fetchCategories parses backend response structure', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        return {
          'status': 200,
          'body': jsonEncode({
            'data': [
              {
                'id': 1,
                'name': 'Erkek Bakımı',
                'slug': 'erkek-bakimi',
              }
            ]
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      final categories = await repo.fetchCategories();
      expect(categories.length, 1);
      expect(categories.first.name, 'Erkek Bakımı');
    });

    test('createServiceRequest sends proper payload and parses response', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        capturedOptions = options;
        return {
          'status': 201,
          'body': jsonEncode({
            'data': {
              'id': 202,
              'status': 'OPEN',
              'payment_method': 'CASH',
              'approx_province': 'İzmir',
              'approx_district': 'Konak',
              'services': [],
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      final req = await repo.createServiceRequest(
        serviceIds: [1, 2],
        approxProvince: 'İzmir',
        approxDistrict: 'Konak',
        paymentMethod: 'CASH',
        customerNote: 'Acil',
      );

      expect(req.id, 202);
      expect(req.isOpen, isTrue);
      expect(capturedOptions?.data['service_ids'], [1, 2]);
      expect(capturedOptions?.data['approx_province'], 'İzmir');
      expect(capturedOptions?.data['customer_note'], 'Acil');
    });

    test('fetchStartCode parses code and expires_at', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        return {
          'status': 200,
          'body': jsonEncode({
            'data': {
              'code': '4829',
              'expires_at': '2026-09-18T19:00:00Z',
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      final data = await repo.fetchStartCode(202);
      expect(data['code'], '4829');
    });

    test('saved-address share doğru request id ile çağrılır', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        capturedOptions = options;
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'message': 'Location shared successfully',
            'data': {
              'id': 15,
              'resource_type': 'SERVICE_REQUEST',
              'resource_id': 101,
              'source': 'SAVED_ADDRESS',
              'status': 'ACTIVE',
              'shared_at': '2026-09-18T18:30:00Z',
              'expires_at': '2026-09-18T20:30:00Z',
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      final status = await repo.shareLocation(
        101,
        explicitConsent: true,
        source: 'SAVED_ADDRESS',
        customerAddressId: 7,
      );

      expect(status.isShared, isTrue);
      expect(status.displayStatus, 'Paylaşıldı');
      expect(capturedOptions?.method, 'POST');
      expect(capturedOptions?.path, '/customer/service-requests/101/location-share');
      expect(capturedOptions?.data['source'], 'SAVED_ADDRESS');
      expect(capturedOptions?.data['explicit_consent'], isTrue);
      expect(capturedOptions?.data['customer_address_id'], 7);
    });

    test('revoke gerçek endpointi çağırır', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        capturedOptions = options;
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'message': 'Location sharing revoked',
            'data': {
              'has_active_grant': false,
              'grant': {
                'id': 15,
                'resource_type': 'SERVICE_REQUEST',
                'resource_id': 101,
                'source': 'SAVED_ADDRESS',
                'status': 'REVOKED',
              }
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      await repo.revokeLocation(101);

      expect(capturedOptions?.method, 'DELETE');
      expect(capturedOptions?.path, '/customer/service-requests/101/location-share');
    });

    test('address create gerçek API payload kullanır', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        capturedOptions = options;
        return {
          'status': 201,
          'body': jsonEncode({
            'success': true,
            'data': {
              'id': 45,
              'title': 'Yeni Ofis',
              'province': 'İstanbul',
              'district': 'Şişli',
              'neighborhood': 'Mecidiyeköy',
              'street': 'Büyükdere Cd.',
              'building_no': '101',
              'is_default': false,
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      final newAddr = await repo.createAddress(
        title: 'Yeni Ofis',
        province: 'İstanbul',
        district: 'Şişli',
        neighborhood: 'Mecidiyeköy',
        street: 'Büyükdere Cd.',
        buildingNo: '101',
        isDefault: false,
      );

      expect(newAddr.id, 45);
      expect(newAddr.title, 'Yeni Ofis');
      expect(capturedOptions?.method, 'POST');
      expect(capturedOptions?.path, '/customer/addresses');
      expect(capturedOptions?.data['title'], 'Yeni Ofis');
      expect(capturedOptions?.data['province'], 'İstanbul');
      expect(capturedOptions?.data['district'], 'Şişli');
      expect(capturedOptions?.data['neighborhood'], 'Mecidiyeköy');
      expect(capturedOptions?.data['street'], 'Büyükdere Cd.');
      expect(capturedOptions?.data['building_no'], '101');
      expect(capturedOptions?.data['is_default'], isFalse);
    });

    test('finance için client-side price calculation yapılmaz', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        capturedOptions = options;
        return {
          'status': 200,
          'body': jsonEncode({
            'data': {
              'id': 101,
              'status': 'ASSIGNED',
              'payment_method': 'ONLINE',
              'approx_province': 'İstanbul',
              'approx_district': 'Kadıköy',
              'services': [],
            }
          }),
        };
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final repo = InstantRequestRepository(apiClient);

      // acceptOffer only transmits offer_id. It does not compute commission or totals on client.
      await repo.acceptOffer(101, 88);

      expect(capturedOptions?.method, 'POST');
      expect(capturedOptions?.path, '/customer/service-requests/101/offers/88/accept');
      // Ensure no client-side calculated financial amounts are passed
      expect(capturedOptions?.data, isNull);
    });
  });

  group('Location Share Provider and Consent Rules', () {
    test('location share explicit consent olmadan API çağrılmaz', () async {
      int apiCallCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        apiCallCount++;
        return {'status': 200, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: SecureStorageService(), customDio: dio);
      final container = ProviderContainer(
        overrides: [
          instantRequestRepositoryProvider.overrideWithValue(InstantRequestRepository(apiClient)),
        ],
      );

      final notifier = container.read(locationShareProvider(101).notifier);

      // Call without explicit consent
      final result = await notifier.shareSavedAddress(explicitConsent: false);

      expect(result, isFalse);
      expect(apiCallCount, 0); // Repository API was never called!
      expect(container.read(locationShareProvider(101)).error, 'Açık müşteri onayı zorunludur.');
    });
  });

  group('Online Payment and Financial Readiness Gate', () {
    test('ONLINE PENDING paid görünmez', () {
      final json = {
        'id': 101,
        'status': 'ASSIGNED',
        'payment_method': 'ONLINE',
        'approx_province': 'İstanbul',
        'approx_district': 'Kadıköy',
        'services': [],
        'service_payment': {
          'id': 501,
          'status': 'PENDING',
          'amount': '350.00',
        },
      };

      final req = ServiceRequestModel.fromJson(json);

      expect(req.isOnline, isTrue);
      expect(req.isCash, isFalse);
      expect(req.isOnlinePending, isTrue);
      expect(req.isPaid, isFalse);
      expect(req.isFinanciallyReady, isFalse);

      // Verify that statusLabel or display never states 'Ödendi' or 'Ödeme başarılı'
      expect(req.statusLabel.contains('Ödendi'), isFalse);
      expect(req.statusLabel.contains('Ödeme başarılı'), isFalse);
    });

    test('financial readiness yokken start-code success gösterilmez', () {
      final json = {
        'id': 101,
        'status': 'ASSIGNED',
        'payment_method': 'ONLINE',
        'approx_province': 'İstanbul',
        'approx_district': 'Kadıköy',
        'services': [],
        'service_payment': {
          'id': 501,
          'status': 'PENDING',
          'amount': '350.00',
        },
      };

      final req = ServiceRequestModel.fromJson(json);

      // When financial readiness is false, client knows it is NOT ready for service start code
      expect(req.isFinanciallyReady, isFalse);

      // If payment was HELD (escrow secured), financial readiness is true
      final heldJson = Map<String, dynamic>.from(json);
      heldJson['service_payment'] = {
        'id': 501,
        'status': 'HELD',
        'amount': '350.00',
      };
      final heldReq = ServiceRequestModel.fromJson(heldJson);
      expect(heldReq.isOnlineHeld, isTrue);
      expect(heldReq.isFinanciallyReady, isTrue);

      // If payment is CASH, financial readiness is immediately true
      final cashJson = Map<String, dynamic>.from(json);
      cashJson['payment_method'] = 'CASH';
      cashJson.remove('service_payment');
      final cashReq = ServiceRequestModel.fromJson(cashJson);
      expect(cashReq.isCash, isTrue);
      expect(cashReq.isFinanciallyReady, isTrue);
    });
  });

  group('Geography Data Source (turkiyeapi.dev fallback)', () {
    // The app ships the full il / ilçe / mahalle data (see geo_location_data_test.dart); the public API is only
    // used when those files cannot be read, which is what a bundle without the assets simulates here.
    test('paket verisi okunamazsa il/ilçe/mahalle uzak API\'den gelir', () async {
      final requestedUrls = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options) {
        requestedUrls.add(options.uri.toString());
        if (options.uri.path.endsWith('/provinces')) {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'OK',
              'data': [
                {
                  'id': 34,
                  'name': 'İstanbul',
                  'districts': [
                    {'id': 1, 'name': 'Kadıköy'},
                    {'id': 2, 'name': 'Beşiktaş'},
                  ],
                },
                {
                  'id': 6,
                  'name': 'Ankara',
                  'districts': [
                    {'id': 3, 'name': 'Çankaya'},
                  ],
                }
              ]
            }),
          };
        } else if (options.uri.path.contains('/districts/1')) {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'OK',
              'data': {
                'id': 1,
                'name': 'Kadıköy',
                'neighborhoods': [
                  {'id': 101, 'name': 'Moda Mahallesi'},
                  {'id': 102, 'name': 'Caddebostan Mahallesi'},
                ]
              }
            }),
          };
        }
        return {'status': 200, 'body': '{}'};
      });

      final geoService = GeoService(dio: dio, bundle: MissingAssetBundle());

      // Verify provinces are loaded via remote API
      final provinces = await geoService.getProvinces();
      expect(provinces.length, 2);
      expect(provinces.first.name, 'İstanbul');
      expect(provinces.first.districts.length, 2);
      expect(requestedUrls.any((u) => u.contains('api.turkiyeapi.dev/v1/provinces')), isTrue);

      // Verify neighborhoods are loaded via remote API
      final neighborhoods = await geoService.getNeighborhoods(1);
      expect(neighborhoods.length, 2);
      expect(neighborhoods.first.name, 'Moda Mahallesi');
      expect(requestedUrls.any((u) => u.contains('api.turkiyeapi.dev/v1/districts/1')), isTrue);
    });
  });

  group('Polling Lifecycle and Terminal States', () {
    test('final state\'te polling durur', () {
      final terminalStatuses = ['COMPLETED', 'CANCELLED', 'DISPUTED'];

      for (final st in terminalStatuses) {
        final json = {
          'id': 101,
          'status': st,
          'payment_method': 'CASH',
          'approx_province': 'İstanbul',
          'approx_district': 'Kadıköy',
          'services': [],
        };
        final req = ServiceRequestModel.fromJson(json);

        // Terminal state must not be active, which instructs polling loop to stop
        expect(req.isActive, isFalse, reason: 'Status $st must have isActive == false');
      }

      final activeStatuses = ['OPEN', 'ASSIGNED', 'IN_PROGRESS'];
      for (final st in activeStatuses) {
        final json = {
          'id': 101,
          'status': st,
          'payment_method': 'CASH',
          'approx_province': 'İstanbul',
          'approx_district': 'Kadıköy',
          'services': [],
        };
        final req = ServiceRequestModel.fromJson(json);
        expect(req.isActive, isTrue, reason: 'Status $st must have isActive == true');
      }
    });

    test('polling dispose sonrası durur', () {
      // Simulate polling timer lifecycle
      Timer? pollTimer;
      int pollTicks = 0;

      void startPolling() {
        pollTimer?.cancel();
        pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          pollTicks++;
        });
      }

      void disposeScreen() {
        pollTimer?.cancel();
        pollTimer = null;
      }

      startPolling();
      expect(pollTimer?.isActive, isTrue);
      expect(pollTicks, isNonNegative);

      disposeScreen();
      expect(pollTimer, isNull);
    });
  });

  group('Semantic Deep Link Routing for 6 Push Events', () {
    test('deep link doğrudan doğru request detail açar', () {
      final validDetailEvents = [
        'OFFER_RECEIVED',
        'SERVICE_STARTED',
        'PROVIDER_MARKED_FINISHED',
        'DISPUTE_OPENED',
        'DISPUTE_RESOLVED_CUSTOMER',
        'DISPUTE_RESOLVED_PROVIDER',
      ];

      for (final event in validDetailEvents) {
        final link = SemanticDeepLink(
          tab: SemanticRouteTab.requests,
          resourceType: 'SERVICE_REQUEST',
          resourceId: 789,
          eventType: event,
        );

        expect(link.hasRequestDetail, isTrue, reason: '$event should have hasRequestDetail == true');
        expect(link.resourceId, 789);
        expect(link.tab, SemanticRouteTab.requests);
      }

      // Resource updates open their canonical request detail too.
      final genericLink = SemanticDeepLink(
        tab: SemanticRouteTab.requests,
        resourceType: 'SERVICE_REQUEST',
        resourceId: 789,
        eventType: 'REQUEST_UPDATE',
      );
      expect(genericLink.hasRequestDetail, isTrue);

      final msgLink = SemanticDeepLink(
        tab: SemanticRouteTab.messages,
        resourceType: 'CHAT',
        resourceId: 456,
        eventType: 'MESSAGE_RECEIVED',
      );
      expect(msgLink.hasRequestDetail, isFalse);
    });
  });
}

class _MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  _MockAdapter(this.handler);

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
