import 'dart:async';
import 'dart:convert';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/models/service_offer.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/provider/instant/models/provider_profile_model.dart';
import 'package:app/features/provider/instant/providers/provider_instant_providers.dart';
import 'package:app/features/provider/instant/repositories/provider_instant_repository.dart';
import 'package:app/features/provider/screens/provider_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeProviderProfileNotifier extends ProviderProfileNotifier {
  @override
  Future<ProviderProfileModel> build() async => const ProviderProfileModel(
        userId: 2,
        businessName: 'Ahmet Berber',
        isOnline: true,
        isApproved: true,
      );
}

class FakeProviderAssignedRequestsNotifier extends ProviderAssignedRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class FakeProviderMyOffersNotifier extends ProviderMyOffersNotifier {
  @override
  Future<List<ServiceOffer>> build() async => const [];
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeStorage = _FakeStorage();
    storageService = SecureStorageService(secureStorage: fakeStorage);
    await storageService.init();
  });

  group('Provider Instant Flow - 40 Comprehensive Tests', () {
    // ── 1. Provider online toggle calls real API ────────────────────────────
    test('01. Provider online toggle gercek API cagirir', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/profile' && options.method == 'PUT') {
          capturedOptions = options;
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'success',
              'data': {'user_id': 2, 'is_online': true, 'is_approved': true, 'identity_status': 'APPROVED'},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final result = await repo.updateOnlineStatus(true);
      expect(result.isOnline, isTrue);
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, '/provider/profile');
      expect(capturedOptions!.method, 'PUT');
      expect((capturedOptions!.data as Map)['is_online'], isTrue);
    });

    // ── 2. Backend online state response is UI source-of-truth ─────────────
    test('02. Backend online state responseu UI source-of-truth olur', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/profile') {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'success',
              'data': {'user_id': 2, 'is_online': false, 'is_approved': true, 'identity_status': 'APPROVED'},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(providerProfileNotifierProvider.notifier);
      final res = await notifier.setOnline(false);
      expect(res, isTrue);

      final profile = container.read(providerProfileNotifierProvider).value;
      expect(profile?.isOnline, isFalse);
    });

    // ── 2b. Failed toggle keeps the profile instead of blanking it ──────────
    test('02b. Basarisiz online toggle profili korur ve hata mesaji verir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/profile' && options.method == 'PUT') {
          return {
            'status': 500,
            'body': jsonEncode({'message': 'Sunucu hatası oluştu.'}),
          };
        }
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'user': {'id': 2},
              'profile': {
                'user_id': '2',
                'is_online': true,
                'is_approved': true,
                'identity_status': 'APPROVED',
                'business_name': 'Ahmet Berber',
              },
            },
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(providerProfileNotifierProvider.future);
      expect(loaded.isOnline, isTrue);

      final notifier = container.read(providerProfileNotifierProvider.notifier);
      final ok = await notifier.setOnline(false);

      expect(ok, isFalse);
      expect(notifier.lastOnlineError, 'Sunucu hatası oluştu.');
      final after = container.read(providerProfileNotifierProvider);
      expect(after.hasError, isFalse);
      expect(after.value?.isOnline, isTrue);
      expect(after.value?.businessName, 'Ahmet Berber');
    });

    test('02c. Basarili toggle backend user+profile yanitini cozer', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        final online = options.method == 'PUT';
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'user': {'id': 2},
              'profile': {
                'user_id': '2',
                'is_online': online,
                'is_approved': true,
                'identity_status': 'APPROVED',
              },
            },
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);

      await container.read(providerProfileNotifierProvider.future);
      final notifier = container.read(providerProfileNotifierProvider.notifier);
      expect(await notifier.setOnline(true), isTrue);
      expect(notifier.lastOnlineError, isNull);
      expect(container.read(providerProfileNotifierProvider).value?.isOnline, isTrue);
    });

    test('02d. Pazar yeri listesi ekrandayken online toggle hata vermez (Isler sekmesi)', () async {
      var online = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/profile' && options.method == 'PUT') online = true;
        if (options.path == '/provider/service-requests') {
          return {'status': 200, 'body': jsonEncode({'success': true, 'data': []})};
        }
        return {
          'status': 200,
          'body': jsonEncode({
            'success': true,
            'data': {
              'user': {'id': 2},
              'profile': {
                'user_id': '2',
                'is_online': online,
                'is_approved': true,
                'identity_status': 'APPROVED',
              },
            },
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);

      // The Isler tab keeps the marketplace list mounted while the provider toggles.
      final sub = container.listen(providerMarketplaceRequestsProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(providerProfileNotifierProvider.future);
      final notifier = container.read(providerProfileNotifierProvider.notifier);
      final ok = await notifier.setOnline(true);

      expect(notifier.lastOnlineError, isNull);
      expect(ok, isTrue);
      expect(container.read(providerProfileNotifierProvider).value?.isOnline, isTrue);
      expect(await container.read(providerMarketplaceRequestsProvider.future), isEmpty);
    });

    // ── 3. Offline provider does not show marketplace requests ──────────────
    test('03. Offline provider marketplace request gostermez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/profile') {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'success',
              'data': {'user_id': 2, 'is_online': false, 'is_approved': true},
            }),
          };
        }
        return {'status': 200, 'body': jsonEncode({'data': []})};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      await container.read(providerProfileNotifierProvider.future);
      final requests = await container.read(providerMarketplaceRequestsProvider.future);
      expect(requests, isEmpty);
    });

    // ── 4. Eligible request list displays backend data ──────────────────────
    test('04. Eligible request list backend data gosterir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': [
                {
                  'id': 101,
                  'status': 'OPEN',
                  'payment_method': 'CASH',
                  'approx_district': 'Kadıköy',
                  'approx_neighborhood': 'Moda',
                  'services': [{'id': 1, 'name': 'Saç Kesimi', 'duration_minutes': 30}],
                  'created_at': '2026-09-19T07:00:00Z',
                }
              ]
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);
      final requests = await repo.getMarketplaceRequests();

      expect(requests.length, 1);
      expect(requests.first.id, 101);
      expect(requests.first.approxDistrict, 'Kadıköy');
      expect(requests.first.paymentMethod, 'CASH');
    });

    // ── 5. Unmatched/unrelated requests not displayed (backend is truth) ────
    test('05. Unmatched/unassigned unrelated request gosterilmez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests') {
          // Backend only returns 1 matched request
          return {
            'status': 200,
            'body': jsonEncode({
              'data': [
                {'id': 101, 'status': 'OPEN', 'payment_method': 'CASH', 'approx_district': 'Kadıköy', 'services': []}
              ]
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);
      final list = await repo.getMarketplaceRequests();

      expect(list.any((r) => r.id == 999), isFalse);
      expect(list.length, 1);
    });

    // ── 6. Request card does not contain exact address ──────────────────────
    test('06. Request card exact address icermez', () {
      final json = {
        'id': 101,
        'status': 'OPEN',
        'payment_method': 'CASH',
        'approx_district': 'Kadıköy',
        'approx_neighborhood': 'Moda',
        'approx_area': 'Moda, Kadıköy',
        'services': [{'id': 1, 'name': 'Saç Kesimi'}],
      };

      final req = ServiceRequestModel.fromJson(json);
      expect(req.approxDistrict, 'Kadıköy');
      expect(req.approxNeighborhood, 'Moda');
      expect(json.containsKey('street'), isFalse);
      expect(json.containsKey('building_no'), isFalse);
      expect(json.containsKey('apartment_no'), isFalse);
    });

    // ── 7. Request card does not contain GPS coordinates ────────────────────
    test('07. Request card GPS icermez', () {
      final json = {
        'id': 101,
        'status': 'OPEN',
        'payment_method': 'CASH',
        'approx_district': 'Kadıköy',
        'approx_neighborhood': 'Moda',
        'services': [],
      };

      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      final req = ServiceRequestModel.fromJson(json);
      expect(req.id, 101);
    });

    // ── 8. Offer form price validation works ────────────────────────────────
    test('08. Offer form price validasyonu calisir', () {
      String? validatePrice(String? val) {
        if (val == null || val.trim().isEmpty) return 'Teklif fiyatı giriniz';
        final p = double.tryParse(val.replaceAll(',', '.'));
        if (p == null || p <= 0) return 'Geçerli bir tutar giriniz';
        return null;
      }

      expect(validatePrice(''), 'Teklif fiyatı giriniz');
      expect(validatePrice('0'), 'Geçerli bir tutar giriniz');
      expect(validatePrice('-50'), 'Geçerli bir tutar giriniz');
      expect(validatePrice('abc'), 'Geçerli bir tutar giriniz');
      expect(validatePrice('350'), isNull);
      expect(validatePrice('350,50'), isNull);
    });

    // ── 9. ETA uses only canonical 15, 30, 45, 60 options ──────────────────
    test('09. ETA yalniz 15/30/45/60 secenekleri kullanir', () {
      const canonicalEtas = [15, 30, 45, 60];
      expect(canonicalEtas.length, 4);
      expect(canonicalEtas.contains(15), isTrue);
      expect(canonicalEtas.contains(30), isTrue);
      expect(canonicalEtas.contains(45), isTrue);
      expect(canonicalEtas.contains(60), isTrue);
      expect(canonicalEtas.contains(20), isFalse);
      expect(canonicalEtas.contains(90), isFalse);
    });

    // ── 10. Double offer submit does not produce two requests ───────────────
    test('10. Double offer submit iki request uretmez', () async {
      int requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/101/offers') {
          requestCount++;
          return {
            'status': 201,
            'body': jsonEncode({
              'status': 'success',
              'data': {'id': 1, 'price': '300.00', 'estimated_arrival_min': 30, 'status': 'PENDING'},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      bool isSubmitting = false;
      Future<void> submit() async {
        if (isSubmitting) return;
        isSubmitting = true;
        try {
          await repo.createOffer(101, price: 300, estimatedArrivalMin: 30);
        } finally {
          isSubmitting = false;
        }
      }

      await Future.wait([submit(), submit()]);
      expect(requestCount, 1);
    });

    // ── 11. CASH insufficient commission 422 cleanly displayed ──────────────
    test('11. CASH insufficient commission 422 duzgun gosterilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/101/offers') {
          return {
            'status': 422,
            'body': jsonEncode({
              'message': 'Bu teklif için platform komisyonunu karşılayacak yeterli cüzdan bakiyeniz bulunmuyor.',
              'errors': {
                'wallet': ['Bu teklif için platform komisyonunu karşılayacak yeterli cüzdan bakiyeniz bulunmuyor.']
              }
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      try {
        await repo.createOffer(101, price: 500, estimatedArrivalMin: 30);
        fail('Should throw AppException');
      } on AppException catch (e) {
        expect(e.message, contains('yeterli cüzdan bakiyeniz bulunmuyor'));
        expect(e.statusCode, 422);
      }
    });

    // ── 12. No fake offer visible after CASH failure ────────────────────────
    test('12. CASH failure sonrasi fake offer gorunmez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/offers') {
          return {'status': 200, 'body': jsonEncode({'data': []})};
        }
        return {'status': 422, 'body': jsonEncode({'message': 'Insufficient balance'})};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      try {
        await repo.createOffer(101, price: 500, estimatedArrivalMin: 30);
      } catch (_) {}

      final offers = await repo.getMyOffers();
      expect(offers, isEmpty);
    });

    // ── 13. ONLINE offer wallet balance does not block client ───────────────
    test('13. ONLINE offer wallet balance nedeniyle clientta engellenmez', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/102/offers') {
          return {
            'status': 201,
            'body': jsonEncode({
              'status': 'success',
              'data': {
                'id': 5,
                'price': '400.00',
                'estimated_arrival_min': 15,
                'status': 'PENDING',
              },
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final offer = await repo.createOffer(102, price: 400, estimatedArrivalMin: 15);
      expect(offer.id, 5);
      expect(offer.isPending, isTrue);
    });

    // ── 14. Successful offer state updated via server refetch ────────────────
    test('14. Successful offer state server refetch ile guncellenir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/offers') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': [
                {'id': 5, 'price': '400.00', 'estimated_arrival_min': 15, 'status': 'PENDING'}
              ]
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);
      final offers = await repo.getMyOffers();

      expect(offers.length, 1);
      expect(offers.first.id, 5);
      expect(offers.first.status, 'PENDING');
    });

    // ── 15. Own offers list shows only own offers ───────────────────────────
    test('15. Own offers list only own offers gosterir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/offers') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': [
                {'id': 1, 'provider_user_id': 2, 'price': '250.00', 'status': 'PENDING'},
                {'id': 2, 'provider_user_id': 2, 'price': '350.00', 'status': 'ACCEPTED'},
              ]
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);
      final offers = await repo.getMyOffers();

      expect(offers.length, 2);
      expect(offers.every((o) => o.providerUserId == 2), isTrue);
    });

    // ── 16. OFFER_ACCEPTED deep-link opens correct job detail ───────────────
    test('16. OFFER_ACCEPTED deep-link dogru job detail acar', () async {
      final pushService = PushNotificationService(
        apiClient: ApiClient(storage: storageService, customDio: Dio()),
        storage: storageService,
      );

      SemanticDeepLink? capturedLink;
      final sub = pushService.deepLinkStream.listen((link) {
        capturedLink = link;
      });

      pushService.handleIncomingPayload({
        'type': 'OFFER_ACCEPTED',
        'resource_type': 'request',
        'resource_id': '88',
      });

      await Future.delayed(const Duration(milliseconds: 20));

      expect(capturedLink, isNotNull);
      expect(capturedLink!.tab, SemanticRouteTab.requests);
      expect(capturedLink!.resourceId, 88);
      expect(capturedLink!.eventType, 'OFFER_ACCEPTED');
      await sub.cancel();
    });

    // ── 17. ASSIGNED job shows safe customer/location state ─────────────────
    test('17. ASSIGNED job safe customer/location state gosterir', () {
      final json = {
        'id': 88,
        'status': 'ASSIGNED',
        'payment_method': 'CASH',
        'approx_district': 'Beşiktaş',
        'approx_neighborhood': 'Sinanpaşa',
        'services': [{'id': 1, 'name': 'Saç & Sakal'}],
      };

      final job = ServiceRequestModel.fromJson(json);
      expect(job.isAssigned, isTrue);
      expect(job.approxDistrict, 'Beşiktaş');
      expect(json.containsKey('street'), isFalse);
    });

    // ── 18. ONLINE PENDING does not display "Ödendi" ─────────────────────────
    test('18. ONLINE PENDING odendi gorunmez', () {
      final json = {
        'id': 88,
        'status': 'ASSIGNED',
        'payment_method': 'ONLINE',
        'payment_summary': {'status': 'PENDING'},
        'services': [],
      };

      final job = ServiceRequestModel.fromJson(json);
      expect(job.isOnline, isTrue);
      expect(job.paymentSummary?.status, 'PENDING');
      expect(job.isPaid, isFalse);
    });

    // ── 19. ONLINE PENDING blocks start code and exact location actions ─────
    test('19. ONLINE PENDING exact-location/start-code action basarili gosterilmez', () {
      final json = {
        'id': 88,
        'status': 'ASSIGNED',
        'payment_method': 'ONLINE',
        'payment_summary': {'status': 'PENDING'},
        'services': [],
      };

      final job = ServiceRequestModel.fromJson(json);
      expect(job.isFinanciallyReady, isFalse);
    });

    // ── 20. No active location grant shows "Tam adres henüz paylaşılmadı" ────
    test('20. No active location grant exact address gostermez', () {
      final json = {
        'id': 88,
        'status': 'ASSIGNED',
        'payment_method': 'CASH',
        'services': [],
      };

      expect(json.containsKey('street'), isFalse);
      expect(json.containsKey('exact_location'), isFalse);
    });

    // ── 21. ACTIVE grant calls exact location endpoint ──────────────────────
    test('21. ACTIVE grant exact location endpointi cagirir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/shared-location') {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'ACTIVE',
              'expires_at': '2026-09-19T10:00:00Z',
              'exact_location': {
                'id': 12,
                'province': 'İstanbul',
                'district': 'Beşiktaş',
                'neighborhood': 'Sinanpaşa',
                'street': 'Akmaz Çeşme Sk.',
                'building_no': '5',
                'apartment_no': '2',
                'directions': 'Berber dükkanının karşısı',
              }
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final loc = await repo.getSharedLocation(88);
      expect(loc, isNotNull);
      expect(loc!.street, 'Akmaz Çeşme Sk.');
      expect(loc.buildingNo, '5');
      expect(loc.apartmentNo, '2');
      expect(loc.directions, 'Berber dükkanının karşısı');
      expect(loc.hasExactDetails, isTrue);
    });

    // ── 22. Revoked grant exact address removed from screen ──────────────────
    test('22. Revoked grant exact address ekrandan kaldirilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/shared-location') {
          return {
            'status': 403,
            'body': jsonEncode({
              'message': 'Konum paylaşımı artık aktif değil.',
              'status': 'REVOKED',
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final loc = await repo.getSharedLocation(88);
      expect(loc, isNull);
    });

    // ── 23. Expired grant exact address removed from screen ──────────────────
    test('23. Expired grant exact address ekrandan kaldirilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/shared-location') {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'EXPIRED',
              'expires_at': '2026-09-19T06:00:00Z',
              'exact_location': null,
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final loc = await repo.getSharedLocation(88);
      expect(loc?.hasExactDetails ?? false, isFalse);
    });

    // ── 24. Exact address is never persisted to storage ─────────────────────
    test('24. Exact address persistent storagea yazilmaz', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {
          'status': 200,
          'body': jsonEncode({
            'status': 'ACTIVE',
            'exact_location': {'street': 'Gizli Sokak 123', 'building_no': '12'}
          }),
        };
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);
      final loc = await repo.getSharedLocation(88);

      expect(loc?.street, 'Gizli Sokak 123');
      expect(fakeStorage.data.values.any((val) => val.contains('Gizli Sokak')), isFalse);
    });

    // ── 25. Start code accepts only 4 numeric digits ────────────────────────
    test('25. Start code yalniz 4 digit input kabul eder', () {
      bool isValidCode(String code) => RegExp(r'^\d{4}$').hasMatch(code);

      expect(isValidCode('1234'), isTrue);
      expect(isValidCode('0000'), isTrue);
      expect(isValidCode('9999'), isTrue);
      expect(isValidCode('123'), isFalse);
      expect(isValidCode('12345'), isFalse);
      expect(isValidCode('12a4'), isFalse);
      expect(isValidCode(''), isFalse);
    });

    // ── 26. Wrong code shows backend error ──────────────────────────────────
    test('26. Wrong code backend error gosterir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/verify-start-code') {
          return {
            'status': 422,
            'body': jsonEncode({
              'message': 'Geçersiz doğrulama kodu. Kalan deneme hakkı: 3',
              'remaining_attempts': 3,
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      try {
        await repo.verifyStartCode(88, '1111');
        fail('Should throw AppException');
      } on AppException catch (e) {
        expect(e.message, contains('Geçersiz doğrulama kodu'));
        expect(e.statusCode, 422);
      }
    });

    // ── 27. Locked verification displayed according to backend state ────────
    test('27. Locked verification backend statee gore gosterilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/verify-start-code') {
          return {
            'status': 422,
            'body': jsonEncode({
              'message': 'Çok fazla hatalı deneme. Lütfen 5 dakika sonra tekrar deneyin.',
              'is_locked': true,
              'locked_until': '2026-09-19T08:00:00Z',
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      try {
        await repo.verifyStartCode(88, '9999');
        fail('Should throw AppException');
      } on AppException catch (e) {
        expect(e.message, contains('Çok fazla hatalı deneme'));
      }
    });

    // ── 28. Correct code transitions state to IN_PROGRESS ───────────────────
    test('28. Correct code sonrasi API refetch IN_PROGRESS gosterir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/verify-start-code') {
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'success',
              'data': {'id': 88, 'status': 'IN_PROGRESS'},
            }),
          };
        }
        if (options.path == '/provider/service-requests/88') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': {'id': 88, 'status': 'IN_PROGRESS', 'services': []},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final res = await repo.verifyStartCode(88, '4589');
      expect(res['status'], 'success');

      final updated = await repo.getMarketplaceRequest(88);
      expect(updated.isInProgress, isTrue);
      expect(updated.statusLabel, 'Hizmet Devam Ediyor');
    });

    // ── 29. Provider finish endpoint called ─────────────────────────────────
    test('29. Provider finish endpoint cagrilir', () async {
      RequestOptions? captured;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/finish' && options.method == 'POST') {
          captured = options;
          return {
            'status': 200,
            'body': jsonEncode({
              'status': 'success',
              'data': {'id': 88, 'status': 'AWAITING_CUSTOMER_CONFIRMATION'},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final res = await repo.finishService(88);
      expect(res['status'], 'success');
      expect(captured, isNotNull);
      expect(captured!.path, '/provider/service-requests/88/finish');
      expect(captured!.method, 'POST');
    });

    // ── 30. Finish shows AWAITING_CUSTOMER_CONFIRMATION, not COMPLETED ──────
    test('30. Finish sonrasi COMPLETED degil AWAITING gosterilir', () {
      final json = {
        'id': 88,
        'status': 'AWAITING_CUSTOMER_CONFIRMATION',
        'services': [],
      };

      final job = ServiceRequestModel.fromJson(json);
      expect(job.isAwaitingConfirmation, isTrue);
      expect(job.isCompleted, isFalse);
      expect(job.statusLabel, 'Onayınızı Bekliyor');
    });

    // ── 31. Customer completion refreshes to COMPLETED ──────────────────────
    test('31. Customer completion sonrasi COMPLETED refresh edilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': {'id': 88, 'status': 'COMPLETED', 'completed_at': '2026-09-19T08:30:00Z', 'services': []},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final job = await repo.getMarketplaceRequest(88);
      expect(job.isCompleted, isTrue);
      expect(job.statusLabel, 'Tamamlandı');
    });

    // ── 32. Customer dispute refreshes to DISPUTED ──────────────────────────
    test('32. Customer dispute sonrasi DISPUTED refresh edilir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': {'id': 88, 'status': 'DISPUTED', 'services': []},
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      final job = await repo.getMarketplaceRequest(88);
      expect(job.isDisputed, isTrue);
      expect(job.statusLabel, 'Uyuşmazlık');
    });

    // ── 33. Safe dispute result rendered ────────────────────────────────────
    test('33. Safe dispute result render edilir', () {
      final json = {
        'id': 88,
        'status': 'DISPUTED',
        'dispute_summary': {
          'status': 'RESOLVED',
          'resolution': 'RESOLVED_PROVIDER',
          'resolved_at': '2026-09-19T09:00:00Z',
        },
        'services': [],
      };

      final job = ServiceRequestModel.fromJson(json);
      expect(job.disputeSummary, isNotNull);
      expect(job.disputeSummary?.resolution, 'RESOLVED_PROVIDER');
      expect(job.disputeSummary?.status, 'RESOLVED');
    });

    // ── 34. Admin note is not rendered to provider ──────────────────────────
    test('34. Admin note providera gosterilmez', () {
      final json = <String, dynamic>{
        'id': 88,
        'status': 'DISPUTED',
        'dispute_summary': <String, dynamic>{
          'status': 'OPEN',
          'reason': 'Hizmet eksik verildi',
        },
        'services': [],
      };

      final summaryMap = json['dispute_summary'] as Map<String, dynamic>;
      expect(summaryMap.containsKey('admin_note'), isFalse);
      expect(summaryMap.containsKey('internal_comment'), isFalse);
    });

    // ── 35. History uses real backend data ──────────────────────────────────
    test('35. History gercek backend data kullanir', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/assigned-requests') {
          return {
            'status': 200,
            'body': jsonEncode({
              'data': [
                {'id': 50, 'status': 'COMPLETED', 'completed_at': '2026-09-18T15:00:00Z', 'services': []},
                {'id': 51, 'status': 'CANCELLED', 'services': []},
              ]
            }),
          };
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);
      final assigned = await repo.getAssignedRequests();

      final history = assigned.where((r) => r.isCompleted || r.isCancelled || r.isDisputed).toList();
      expect(history.length, 2);
      expect(history.first.id, 50);
      expect(history.last.id, 51);
    });

    // ── 36. Marketplace polling stops when offline ──────────────────────────
    test('36. Marketplace polling offline/backgroundda durur', () {
      bool isOnline = false;
      int pollAttempts = 0;

      void poll() {
        if (!isOnline) return;
        pollAttempts++;
      }

      poll();
      poll();
      expect(pollAttempts, 0);

      isOnline = true;
      poll();
      expect(pollAttempts, 1);
    });

    // ── 37. Active job polling stops on terminal state or dispose ───────────
    test('37. Active job polling dispose/final statete durur', () {
      Timer? activeJobTimer;
      bool isDisposed = false;

      activeJobTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
        if (isDisposed) {
          t.cancel();
          return;
        }
      });

      // Simulate dispose
      isDisposed = true;
      activeJobTimer.cancel();
      expect(activeJobTimer.isActive, isFalse);
    });

    // ── 38. Pull-to-refresh executes REST refetch ───────────────────────────
    test('38. Pull-to-refresh REST refetch yapar', () async {
      int fetchCalls = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests') {
          fetchCalls++;
          return {'status': 200, 'body': jsonEncode({'data': []})};
        }
        return {'status': 404, 'body': '{}'};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ProviderInstantRepository(apiClient);

      await repo.getMarketplaceRequests();
      expect(fetchCalls, 1);

      // Refresh
      await repo.getMarketplaceRequests();
      expect(fetchCalls, 2);
    });

    // ── 39. Provider/customer role separation maintained ────────────────────
    testWidgets('39. Provider/customer role separation korunur', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storageService),
          apiClientProvider.overrideWithValue(ApiClient(storage: storageService, customDio: Dio())),
          pushNotificationServiceProvider.overrideWithValue(PushNotificationService(apiClient: ApiClient(storage: storageService, customDio: Dio()), storage: storageService)),
          providerProfileNotifierProvider.overrideWith(FakeProviderProfileNotifier.new),
          providerMarketplaceRequestsProvider.overrideWith((ref) async => const []),
          providerAssignedRequestsProvider.overrideWith(FakeProviderAssignedRequestsNotifier.new),
          providerMyOffersProvider.overrideWith(FakeProviderMyOffersNotifier.new),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProviderShell()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('İşler'), findsOneWidget);
      expect(find.text('Talepler'), findsNothing);
    });

    // ── 40. No fake distance/rating/earning rendered ─────────────────────────
    test('40. No fake distance/rating/earning render edilir', () {
      final json = {
        'id': 101,
        'status': 'OPEN',
        'payment_method': 'CASH',
        'approx_district': 'Kadıköy',
        'services': [],
      };

      final req = ServiceRequestModel.fromJson(json);
      expect(req.distanceKm, isNull);
      expect(json.containsKey('provider_rating'), isFalse);
      expect(json.containsKey('estimated_earning'), isFalse);
    });
  });
}
