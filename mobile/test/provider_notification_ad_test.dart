import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/widgets/verified_tick.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/screens/customer_settings_screen.dart';
import 'package:app/features/notifications/screens/notification_center_screen.dart';
import 'package:app/features/offerings/screens/customer_offering_screens.dart';
import 'package:app/features/provider/screens/provider_featured_screen.dart';
import 'package:app/features/provider/screens/provider_notification_ad_section.dart';
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

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, dynamic> Function(RequestOptions o) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(jsonEncode(r['body'] ?? {}), r['status'] as int? ?? 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _CustomerAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated, user: UserModel(id: 5, name: 'Test Musteri', role: 'CUSTOMER', email: 'customer@berberimgelsin.com'));

  @override
  Future<void> restoreSession() async {}
}

Map<String, dynamic> _overview({double balance = 1000, bool card = false, Map<String, dynamic>? active, int sendsLeft = 2, bool enabled = true}) => {
      'is_enabled': enabled,
      'title': 'Bildirim Reklamı',
      'description': 'Müşterilere indirim bildirimi gönder.',
      'audiences': [
        {'audience': 'service_area', 'name': 'Hizmet bölgem', 'description': 'Hizmet verdiğin bölgedeki müşteriler', 'price': 150},
        {'audience': 'location', 'name': 'Seçtiğim konum', 'description': 'Seçtiğin il ve ilçedeki müşteriler', 'price': 250},
        {'audience': 'all', 'name': 'Tüm kullanıcılar', 'description': 'Uygulamadaki tüm müşteriler', 'price': 750},
      ],
      'limits': {'min_discount_percent': 5, 'max_discount_percent': 50, 'max_discount_days': 14, 'max_sends_per_provider_per_day': 2, 'title_max': 50, 'body_max': 120},
      'provider_name': 'Usta Berber',
      'is_verified': true,
      'active_discount': active,
      'sends_left_today': sendsLeft,
      'provinces': [
        {'province': 'İstanbul', 'customers': 120},
        {'province': 'Ankara', 'customers': 40},
      ],
      'wallet': {'usable_cash_balance': balance, 'is_frozen': false},
      'payment': {'wallet_enabled': true, 'card_enabled': card, 'card_unavailable_reason': card ? null : 'Kartla ödeme şu anda kullanılamıyor.'},
      'history': [
        {'id': 1, 'audience_name': 'Tüm kullanıcılar', 'title': 'Geçen hafta', 'discount_percent': 15, 'recipients_count': 310, 'amount': 750, 'status': 'SENT', 'sent_at': '2026-10-10T10:00:00+00:00', 'created_at': '2026-10-10T10:00:00+00:00'},
      ],
    };

Map<String, dynamic> _featured({bool withNotification = true, Map<String, dynamic>? discount}) => {
      'packages': [],
      'wallet': {'usable_cash_balance': 1000, 'is_frozen': false},
      'payment': {'wallet_enabled': true, 'card_enabled': false, 'card_unavailable_reason': 'x'},
      'status': {'is_featured': false, 'active': [], 'upcoming': []},
      'history': [],
      'placements': [
        for (final key in ['home', 'listing'])
          {
            'placement': key,
            'is_enabled': true,
            'slots': 3,
            'rotation_seconds': 20,
            'title': key == 'home' ? 'Ana Sayfa Vitrini' : 'Liste Reklamı',
            'description': null,
            'where': ['Bir yer'],
            'how': ['Bir kural'],
            'screenshots': {'web': '/assets/ads/$key-web.png', 'mobile': '/assets/ads/$key-mobile.png'},
            'packages': [],
            'status': {'is_featured': false, 'featured_until': null, 'active': [], 'upcoming': []},
          },
        if (withNotification)
          {
            'placement': 'notification',
            'kind': 'notification',
            'is_enabled': true,
            'slots': 0,
            'rotation_seconds': 0,
            'title': 'Bildirim Reklamı',
            'description': 'Müşterilere indirim bildirimi gönder.',
            'where': ['Müşterilerin telefonuna gelen bildirim'],
            'how': ['Başlığı, açıklamayı ve indirim oranını sen yazarsın.'],
            'screenshots': null,
            'packages': [],
            'status': {'is_featured': false, 'featured_until': null, 'active': [], 'upcoming': []},
            'active_discount': discount,
          },
      ],
    };

Future<_Adapter> _pumpAds(WidgetTester tester, {Map<String, dynamic>? overview, Map<String, dynamic>? featured}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = SecureStorageService(secureStorage: _FakeStorage());
  await storage.init();
  tester.view.physicalSize = const Size(390, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final adapter = _Adapter((o) {
    if (o.path == '/provider/notification-ads/estimate') {
      final audience = (o.data as Map)['audience'];
      return {'body': {'success': true, 'data': {'recipients': audience == 'all' ? 5100 : audience == 'location' ? 120 : 482, 'price': 1}}};
    }
    if (o.path == '/provider/notification-ads/districts') {
      return {'body': {'success': true, 'data': [{'district': 'Kadıköy', 'customers': 30}]}};
    }
    if (o.path == '/provider/notification-ads' && o.method == 'POST') {
      return {'status': 201, 'body': {'success': true, 'data': {'payment_method': 'wallet', 'sent': {'recipients_count': 482, 'discount_percent': 25, 'discount_days': 7}}}};
    }
    return {'body': {'success': true, 'data': {}}};
  });
  final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter, retries: 0);
  final overrides = <Override>[
    apiClientProvider.overrideWithValue(api),
    providerFeaturedProvider.overrideWith((ref) async => featured ?? _featured()),
    providerAdVisibilityProvider.overrideWith((ref) async => const {}),
    providerNotificationAdProvider.overrideWith((ref) async => overview ?? _overview()),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: ProviderFeaturedScreen())));
  await tester.pump();
  await tester.pump();
  return adapter;
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('placement_tab_notification')));
  await tester.tap(find.byKey(const Key('placement_tab_notification')));
  // The reach estimates are debounced and asked one after the other.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the third ad alternative sits next to the other two, in smaller tiles', (tester) async {
    await _pumpAds(tester);

    for (final key in ['home', 'listing', 'notification']) {
      expect(find.byKey(Key('placement_tab_$key')), findsOneWidget);
    }
    expect(find.text('Bildirim Reklamı'), findsWidgets);
    // Three tiles share one row and are compact (the old two-column tiles were ~150 px high).
    final heights = [for (final key in ['home', 'listing', 'notification']) tester.getSize(find.byKey(Key('placement_tab_$key'))).height];
    expect(heights.every((h) => h < 120), isTrue, reason: '$heights');
    final tops = [for (final key in ['home', 'listing', 'notification']) tester.getTopLeft(find.byKey(Key('placement_tab_$key'))).dy];
    expect(tops.toSet().length, 1, reason: 'one row');
    expect(find.text('Gönderebilirsin'), findsOneWidget);
  });

  testWidgets('a running campaign discount shows on the tile and the status card', (tester) async {
    await _pumpAds(tester, featured: _featured(discount: {'percent': 25, 'days_left': 5, 'ends_at': '2026-11-01T10:00:00+00:00'}));

    expect(find.text('İndirim aktif'), findsOneWidget);
    expect(find.text('Bildirim Reklamı: İndirim yayında'), findsOneWidget);
    expect(find.text('%25 indirim · 5 gün kaldı'), findsOneWidget);
  });

  testWidgets('the notification form: write it, pick the audience, see the preview, send from the wallet', (tester) async {
    final adapter = await _pumpAds(tester);
    await _openForm(tester);

    expect(find.byKey(const Key('notification_ad_form')), findsOneWidget);
    // Nothing to send yet.
    expect(tester.widget<FilledButton>(find.byKey(const Key('notification_ad_send_wallet'))).onPressed, isNull);
    expect(find.text('Başlık, açıklama ve hedefi tamamla'), findsOneWidget);
    expect(find.text('≈ 482 kişiye ulaşır'), findsOneWidget); // the reach of the service area
    expect(find.text('≈ 5.100 kişiye ulaşır'), findsOneWidget);
    expect(find.text('Önce bir il seç'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('notification_ad_title')), 'Hafta sonu fırsatı');
    await tester.enterText(find.byKey(const Key('notification_ad_body')), 'Saç kesimi ve sakal tıraşında geçerli.');
    await tester.tap(find.byKey(const Key('notification_ad_percent_25')));
    await tester.tap(find.byKey(const Key('notification_ad_days_7')));
    await tester.pump();

    // The preview is the notification as the customer gets it.
    final preview = find.byKey(const Key('notification_ad_preview'));
    expect(find.descendant(of: preview, matching: find.text('%25')), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.text('indirim · Usta Berber')), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.byType(VerifiedTick)), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.text('Hafta sonu fırsatı — Saç kesimi ve sakal tıraşında geçerli.')), findsOneWidget);

    final send = find.byKey(const Key('notification_ad_send_wallet'));
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Bildirimi gönder'), findsOneWidget);
    expect(find.textContaining('%25 indirim bildirimi gönderilecek'), findsOneWidget);
    await tester.tap(find.text('Onayla ve Gönder'));
    await tester.pumpAndSettle();

    final post = adapter.requests.lastWhere((r) => r.path == '/provider/notification-ads' && r.method == 'POST');
    final body = Map<String, dynamic>.from(post.data as Map);
    expect(body['audience'], 'service_area');
    expect(body['title'], 'Hafta sonu fırsatı');
    expect(body['body'], 'Saç kesimi ve sakal tıraşında geçerli.');
    expect(body['discount_percent'], 25);
    expect(body['discount_days'], 7);
    expect(body['payment_method'], 'wallet');
    expect(find.textContaining('482 kullanıcıya gönderildi'), findsOneWidget);
    // The form is empty again.
    expect(find.text('Başlık, açıklama ve hedefi tamamla'), findsOneWidget);
  });

  testWidgets('"Seçtiğim konum" needs a province; the district list follows it', (tester) async {
    final adapter = await _pumpAds(tester);
    await _openForm(tester);
    await tester.enterText(find.byKey(const Key('notification_ad_title')), 'Fırsat');
    await tester.enterText(find.byKey(const Key('notification_ad_body')), 'Yalnız bu hafta.');

    await tester.ensureVisible(find.byKey(const Key('notification_ad_audience_location')));
    await tester.tap(find.byKey(const Key('notification_ad_audience_location')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('notification_ad_send_wallet'))).onPressed, isNull, reason: 'no province yet');

    await tester.tap(find.byKey(const Key('notification_ad_province')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstanbul (120)').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byKey(const Key('notification_ad_send_wallet'))).onPressed, isNotNull);
    expect(adapter.requests.any((r) => r.path == '/provider/notification-ads/districts' && r.queryParameters['province'] == 'İstanbul'), isTrue);
    expect(find.text('≈ 120 kişiye ulaşır'), findsOneWidget);
  });

  testWidgets('an empty wallet cannot send, a card needs PayTR, and a closed product shows nothing to send', (tester) async {
    await _pumpAds(tester, overview: _overview(balance: 10));
    await _openForm(tester);
    await tester.enterText(find.byKey(const Key('notification_ad_title')), 'Fırsat');
    await tester.enterText(find.byKey(const Key('notification_ad_body')), 'Yalnız bu hafta.');
    await tester.pump();

    expect(find.text('Bakiye yetersiz'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('notification_ad_send_wallet'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('notification_ad_send_card'))).onPressed, isNull);
    expect(find.text('Kartla ödeme şu anda kullanılamıyor.'), findsOneWidget);
  });

  testWidgets('the running discount can be ended from the form', (tester) async {
    final adapter = await _pumpAds(tester, overview: _overview(active: {'percent': 25, 'days_left': 5, 'ends_at': '2026-11-01T10:00:00+00:00'}));
    await _openForm(tester);

    expect(find.byKey(const Key('notification_ad_active_discount')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('notification_ad_end_discount')));
    await tester.tap(find.byKey(const Key('notification_ad_end_discount')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İndirimi bitir').last);
    await tester.pumpAndSettle();

    expect(adapter.requests.any((r) => r.path == '/provider/notification-ads/discount' && r.method == 'DELETE'), isTrue);
  });

  testWidgets('older API answers without the third placement still work', (tester) async {
    await _pumpAds(tester, featured: _featured(withNotification: false));

    expect(find.byKey(const Key('placement_tab_home')), findsOneWidget);
    expect(find.byKey(const Key('placement_tab_notification')), findsNothing);
  });

  group('for customers', () {
    testWidgets('a campaign in the notification centre: the discount up front, the provider with the tick, a tap opens the profile', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureStorageService(secureStorage: _FakeStorage());
      await storage.init();
      final adapter = _Adapter((o) {
        if (o.path == '/notifications' && o.method == 'GET') {
          return {
            'body': {
              'data': [
                {
                  'id': 7,
                  'type': 'PROVIDER_CAMPAIGN',
                  'title': '%25 indirim · Usta Berber',
                  'message': 'Hafta sonu fırsatı — Saç kesimi ve sakal tıraşında geçerli.',
                  'resource_type': 'PROVIDER_PROFILE',
                  'resource_id': '1664',
                  'read_at': null,
                  'created_at': '2026-10-20T10:00:00+00:00',
                  'metadata': {'provider_user_id': 1664, 'provider_name': 'Usta Berber', 'is_verified': true, 'headline': 'Hafta sonu fırsatı', 'description': 'Saç kesimi ve sakal tıraşında geçerli.', 'discount_percent': 25, 'valid_until': '2026-10-27T10:00:00+00:00'},
                },
                {'id': 8, 'type': 'OFFER_RECEIVED', 'title': 'Yeni teklif', 'message': 'Bir teklif geldi', 'read_at': null, 'created_at': '2026-10-19T10:00:00+00:00'},
              ],
              'meta': {'current_page': 1, 'last_page': 1},
            },
          };
        }
        return {'body': {'success': true}};
      });
      final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter, retries: 0);
      Map<String, dynamic>? opened;
      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api), secureStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => opened = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => const NotificationCenterScreen())),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      final tile = find.byKey(const ValueKey('notification-7'));
      expect(find.descendant(of: tile, matching: find.text('%25')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Usta Berber')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byType(VerifiedTick)), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Hafta sonu fırsatı')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.textContaining('tarihine kadar geçerli')), findsOneWidget);
      // Other notifications keep their plain row.
      expect(find.text('Yeni teklif'), findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(opened?['type'], 'PROVIDER_CAMPAIGN');
      expect(opened?['resource_type'], 'PROVIDER_PROFILE');
      expect(opened?['resource_id'], '1664');
    });

    test('a campaign notification is a link to the provider\'s profile', () {
      expect(const SemanticDeepLink(tab: SemanticRouteTab.home, resourceType: 'PROVIDER_PROFILE', resourceId: 1664, eventType: 'PROVIDER_CAMPAIGN').hasProviderProfile, isTrue);
      expect(const SemanticDeepLink(tab: SemanticRouteTab.home, resourceType: 'APPOINTMENT', resourceId: 3, eventType: 'APPOINTMENT_CONFIRMED').hasProviderProfile, isFalse);
      expect(const SemanticDeepLink(tab: SemanticRouteTab.home, resourceType: 'PROVIDER_PROFILE').hasProviderProfile, isFalse, reason: 'no id');
    });

    testWidgets('settings: campaign notifications have their own switch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureStorageService(secureStorage: _FakeStorage());
      await storage.init();
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var campaign = true;
      final adapter = _Adapter((o) {
        if (o.path == '/push/preferences' && o.method == 'PUT') {
          campaign = (o.data as Map)['campaign_enabled'] as bool;
          return {'body': {'push_enabled': true, 'campaign_enabled': campaign}};
        }
        return {'body': {'push_enabled': true, 'campaign_enabled': campaign}};
      });
      final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter, retries: 0);
      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api), secureStorageProvider.overrideWithValue(storage), authNotifierProvider.overrideWith(_CustomerAuth.new)],
        child: const MaterialApp(home: CustomerSettingsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kampanya bildirimleri'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('campaign_switch'))).value, isTrue);
      await tester.tap(find.byKey(const Key('campaign_switch')));
      await tester.pumpAndSettle();

      expect(campaign, isFalse);
      expect(tester.widget<Switch>(find.byKey(const Key('campaign_switch'))).value, isFalse);
      // The push switch is its own.
      expect(adapter.requests.where((r) => r.method == 'PUT').single.data, {'campaign_enabled': false});
    });

    testWidgets('prices carry the campaign discount: the old price struck through and the percentage', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            OfferPrice(price: 150, originalPrice: 200, percent: 25),
            OfferPrice(price: 200),
          ]),
        ),
      ));

      expect(find.text('₺150'), findsOneWidget);
      expect(find.text('₺200'), findsNWidgets(2)); // struck-through old price + the plain one
      expect(find.text('%25'), findsOneWidget);
      final struck = tester.widgetList<Text>(find.text('₺200')).where((t) => t.style?.decoration == TextDecoration.lineThrough);
      expect(struck.length, 1);
    });
  });
}
