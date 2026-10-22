import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/public_provider_screen.dart';
import 'package:app/features/customer/models/service_offer.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/customer/providers/home_content_providers.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/customer/screens/all_providers_screen.dart';
import 'package:app/features/provider/instant/models/provider_profile_model.dart';
import 'package:app/features/provider/instant/providers/provider_instant_providers.dart';
import 'package:app/features/provider/instant/screens/provider_home_tab.dart';
import 'package:app/features/provider/screens/provider_customer_view_screen.dart';
import 'package:app/features/provider/screens/provider_featured_screen.dart';
import 'package:app/features/shared/widgets/provider_preview_banner.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

/// Answers the public provider profile; every other path is a 404 (the home sections fall back to empty).
class _PublicAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    Object? body;
    if (options.path == '/providers/9') {
      body = {'data': {'user_id': 9, 'business_name': 'Salon Dokuz', 'provider_type': 'barber', 'city': 'İstanbul', 'district': 'Şişli', 'service_count': 3}};
    } else if (options.path == '/providers/9/reviews') {
      body = {'data': {'count': 0, 'average': null, 'reviews': <dynamic>[]}};
    }
    final status = body == null ? 404 : 200;
    return ResponseBody.fromString(jsonEncode(body ?? {'message': 'yok'}), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _FakeProfile extends ProviderProfileNotifier {
  @override
  Future<ProviderProfileModel> build() async => const ProviderProfileModel(userId: 2, businessName: 'Ahmet Berber', isOnline: true, isApproved: true);
}

class _FakeAssigned extends ProviderAssignedRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class _FakeOffers extends ProviderMyOffersNotifier {
  @override
  Future<List<ServiceOffer>> build() async => const [];
}

const _visibility = {
  'home': {'is_featured': false},
  'listing': {'running': true, 'slots': 3, 'rotation_seconds': 20, 'competitors': 2},
};

/// The signed-in provider's customer view, pushed from a stand-in panel screen the way the app does.
Future<List<ProviderListQuery>> _open(WidgetTester tester, {CustomerViewTab tab = CustomerViewTab.home, Map<String, dynamic> visibility = _visibility}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = SecureStorageService(secureStorage: _FakeStorage());
  await storage.init();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = _PublicAdapter();
  final asked = <ProviderListQuery>[];

  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final overrides = <Override>[
    apiClientProvider.overrideWithValue(ApiClient(storage: storage, customDio: dio, retries: 0)),
    providerAdVisibilityProvider.overrideWith((ref) async => visibility),
    providerFeaturedProvider.overrideWith((ref) async => {
          'packages': <dynamic>[],
          'wallet': {'usable_cash_balance': 0, 'is_frozen': false},
          'payment': {'wallet_enabled': true, 'card_enabled': false},
          'status': {'is_featured': false, 'active': <dynamic>[], 'upcoming': <dynamic>[]},
          'history': <dynamic>[],
        }),
    siteConfigDataProvider.overrideWith((ref) async => <String, dynamic>{}),
    homeCategoriesProvider.overrideWith((ref) async => [
          {'id': 1, 'name': 'Erkek Bakım', 'provider_type': 'barber'},
          {'id': 2, 'name': 'Kadın Kuaför', 'provider_type': 'coiffeur'},
        ]),
    homeServicesProvider.overrideWith((ref) async => [{'id': 1, 'name': 'Saç Kesimi'}]),
    featuredProvidersProvider.overrideWith((ref) async => [{'user_id': 9, 'business_name': 'Salon Dokuz', 'review_count': 2, 'rating': null}]),
    listOriginProvider.overrideWithValue(null),
    providerListLoaderProvider.overrideWithValue((q, page) async {
      asked.add(q);
      return ProviderListPage(items: [{'user_id': 9, 'business_name': 'Salon Dokuz', 'provider_type': 'barber'}], sponsored: [{'user_id': 1, 'business_name': 'Benim Salonum', 'is_sponsored': true}], total: 1);
    }),
  ];
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProviderCustomerViewScreen(initialTab: tab))),
              child: const Text('Müşteri görünümünü aç'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Müşteri görünümünü aç'));
  await tester.pumpAndSettle();
  return asked;
}

void main() {
  testWidgets('the customer view opens on the home page a customer sees, without sign-up prompts, and says where the ad stands', (tester) async {
    await _open(tester);

    expect(find.byKey(const Key('provider_customer_view')), findsOneWidget);
    expect(find.textContaining('Müşteri görünümündesin'), findsOneWidget);
    expect(find.byKey(const Key('provider_preview_status')), findsOneWidget);
    expect(find.textContaining('Liste reklamın yayında'), findsOneWidget);
    for (final label in ['Ana Sayfa', 'Hizmetler', 'Hizmet Verenler', 'Müşteri Modülleri']) {
      expect(find.descendant(of: find.byKey(const Key('customer_view_tabs')), matching: find.text(label)), findsOneWidget);
    }

    // The same home page as the signed-out one: hero, categories, services and the verified providers.
    expect(find.text('BERBER VE KUAFÖR PLATFORMU'), findsOneWidget);
    expect(find.text('Hizmet Kategorileri'), findsOneWidget);
    expect(find.text('Salon Dokuz'), findsWidgets);
    // A provider has no use for these on a customer home page.
    expect(find.text('Hizmet Veren Olarak Katıl'), findsNothing);
    expect(find.text('Hizmet Veren Olun'), findsNothing);
    expect(find.text('Giriş Yap'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Randevu Oluştur" moves to the provider list, which asks for the provider\'s own ad (preview) and has no banner of its own', (tester) async {
    final asked = await _open(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Randevu Oluştur').first);
    await tester.pumpAndSettle();

    expect(asked.last.preview, isTrue);
    expect(find.text('Benim Salonum'), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
    expect(find.byKey(const Key('provider_preview_banner')), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('a category on the services tab leads to the provider list', (tester) async {
    final asked = await _open(tester, tab: CustomerViewTab.services);

    expect(find.text('Erkek Bakım'), findsOneWidget);
    expect(find.text('Saç Kesimi'), findsOneWidget);
    expect(asked, isEmpty);

    await tester.tap(find.text('Erkek Bakım'));
    await tester.pumpAndSettle();

    expect(asked, isNotEmpty);
    expect(find.text('Benim Salonum'), findsOneWidget);
  });

  testWidgets('the modules tab lists the customer modules and says this account has none', (tester) async {
    await _open(tester, tab: CustomerViewTab.modules);

    expect(find.text('Taleplerim'), findsOneWidget);
    expect(find.text('Gelen Teklifler'), findsOneWidget);
    expect(find.text('Randevularım'), findsOneWidget);
    expect(find.text('Bu hesapta müşteri olarak kayıt yok.'), findsNWidgets(3));
  });

  testWidgets('a provider card opens the public profile in view-only mode (no sign-up prompt)', (tester) async {
    await _open(tester, tab: CustomerViewTab.providers);

    await tester.tap(find.text('Salon Dokuz'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicProviderScreen), findsOneWidget);
    expect(find.byKey(const Key('public_provider_view_only')), findsOneWidget);
    expect(find.text('Hemen Kayıt Ol'), findsNothing);
    expect(find.text('Giriş Yap'), findsNothing);
  });

  testWidgets('"Panel" goes back to the provider panel and "Reklamlarım" opens the ads screen', (tester) async {
    await _open(tester);

    await tester.tap(find.byKey(const Key('customer_view_ads')));
    await tester.pumpAndSettle();
    expect(find.text('Reklam & Öne Çıkarma'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('view_mode_panel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provider_customer_view')), findsNothing);
    expect(find.text('Müşteri görünümünü aç'), findsOneWidget);
  });

  testWidgets('the provider home screen carries the Panel | Müşteri switch and opens the customer view', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = SecureStorageService(secureStorage: _FakeStorage());
    await storage.init();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = _PublicAdapter();
    // The panel's own metric cards need more room than a phone-sized test surface gives the test font.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(ApiClient(storage: storage, customDio: dio, retries: 0)),
        providerProfileNotifierProvider.overrideWith(_FakeProfile.new),
        providerMarketplaceRequestsProvider.overrideWith((ref) async => const []),
        providerAssignedRequestsProvider.overrideWith(_FakeAssigned.new),
        providerMyOffersProvider.overrideWith(_FakeOffers.new),
        providerAdVisibilityProvider.overrideWith((ref) async => _visibility),
        siteConfigDataProvider.overrideWith((ref) async => <String, dynamic>{}),
        homeCategoriesProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
        homeServicesProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
        featuredProvidersProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
        listOriginProvider.overrideWithValue(null),
        providerListLoaderProvider.overrideWithValue((q, page) async => ProviderListPage(total: 0)),
      ],
      child: const MaterialApp(home: ProviderHomeTab()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('view_mode_panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('view_mode_customer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider_customer_view')), findsOneWidget);
    expect(find.text('BERBER VE KUAFÖR PLATFORMU'), findsOneWidget);
  });
}
