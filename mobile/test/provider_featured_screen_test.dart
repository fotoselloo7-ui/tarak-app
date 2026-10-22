import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/customer/screens/all_providers_screen.dart';
import 'package:app/features/provider/screens/provider_featured_screen.dart';
import 'package:app/features/shared/widgets/provider_preview_banner.dart';

Map<String, dynamic> _data({double balance = 1000, bool featured = false, bool frozen = false, bool card = false}) => {
      'packages': [
        {'id': 1, 'name': '1 Gün', 'description': 'Bir gün', 'badge': null, 'duration_days': 1, 'price': 99},
        {'id': 3, 'name': '30 Gün', 'description': 'Bir ay', 'badge': 'En popüler', 'duration_days': 30, 'price': 1499},
      ],
      'wallet': {'usable_cash_balance': balance, 'is_frozen': frozen},
      'payment': {'wallet_enabled': true, 'card_enabled': card, 'card_unavailable_reason': card ? null : 'Kartla ödeme şu anda kullanılamıyor.'},
      'status': {
        'is_featured': featured,
        'featured_until': featured ? '2027-01-10T10:00:00+00:00' : null,
        'active': featured
            ? [
                {'id': 7, 'package_name': '7 Gün', 'days_left': 5, 'ends_at': '2027-01-10T10:00:00+00:00', 'status': 'active'},
              ]
            : [],
        'upcoming': [],
      },
      'history': featured
          ? [
              {'id': 7, 'package_name': '7 Gün', 'starts_at': '2027-01-03T10:00:00+00:00', 'ends_at': '2027-01-10T10:00:00+00:00', 'price_paid': 499, 'source': 'wallet', 'status': 'active'},
            ]
          : [],
    };

Map<String, dynamic> _placementsData({bool listingEnabled = true, bool listingRunning = true}) {
  Map<String, dynamic> status(bool running) => {
        'is_featured': running,
        'featured_until': running ? '2027-01-10T10:00:00+00:00' : null,
        'active': running
            ? [
                {'id': 9, 'package_name': '7 Gün', 'days_left': 4, 'ends_at': '2027-01-10T10:00:00+00:00', 'status': 'active'},
              ]
            : [],
        'upcoming': [],
      };
  return {
    ..._data(balance: 800),
    'placements': [
      {
        'placement': 'home',
        'is_enabled': true,
        'slots': 8,
        'rotation_seconds': 0,
        'title': 'Ana Sayfa Vitrini',
        'description': null,
        'where': ['Ana sayfada Öne Çıkan Profesyoneller bölümü'],
        'how': ['Tüm ziyaretçiler görür.'],
        'screenshots': {'web': '/assets/ads/home-web.png', 'mobile': '/assets/ads/home-mobile.png'},
        'packages': [
          {'id': 1, 'placement': 'home', 'name': 'Vitrin 1 Gün', 'description': 'Bir gün vitrin', 'badge': null, 'duration_days': 1, 'price': 99},
        ],
        'status': status(false),
      },
      {
        'placement': 'listing',
        'is_enabled': listingEnabled,
        'slots': 3,
        'rotation_seconds': 20,
        'title': 'Liste Reklamı',
        'description': 'Listenin en üstünde Önerilen kart.',
        'where': ['Randevu alırken Hizmet Veren Seçimi listesinin en üstü'],
        'how': ['Aynı anda en fazla 3 reklam yer alır.'],
        'screenshots': {'web': '/assets/ads/listing-web.png', 'mobile': '/assets/ads/listing-mobile.png'},
        'packages': [
          {'id': 11, 'placement': 'listing', 'name': 'Liste 7 Gün', 'description': 'Bir hafta listede', 'badge': 'En popüler', 'duration_days': 7, 'price': 399},
        ],
        'status': status(listingRunning),
      },
    ],
  };
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> data, {Map<String, dynamic>? visibility}) async {
  tester.view.physicalSize = const Size(390, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final overrides = <Override>[
    providerFeaturedProvider.overrideWith((ref) async => data),
    providerAdVisibilityProvider.overrideWith((ref) async => visibility ?? const {}),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: ProviderFeaturedScreen())));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the admin-priced packages and lets a provider with enough balance buy', (tester) async {
    await _pump(tester, _data(balance: 2000));

    expect(find.text('Reklam & Öne Çıkarma'), findsWidgets);
    expect(find.text('Bu alanda şu an reklamın yok'), findsOneWidget);
    expect(find.text('₺2.000'), findsOneWidget); // wallet balance, Turkish thousands separator
    expect(find.text('1 Gün'), findsOneWidget);
    expect(find.text('₺99'), findsOneWidget);
    expect(find.text('₺1.499'), findsOneWidget);
    expect(find.text('En popüler'), findsOneWidget);
    expect(find.text('günlüğü ₺99'), findsOneWidget);
    expect(find.text('30 gün · günlüğü ₺49,97'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Bakiyeden Öde'), findsNWidgets(2));
    // The card option stays visible but disabled, with the reason, while PayTR is not configured.
    expect(find.byKey(const Key('buy_with_card')), findsNWidgets(2));
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('buy_with_card')).first).onPressed, isNull);
    expect(find.text('Kartla ödeme şu anda kullanılamıyor.'), findsNWidgets(2));
  });

  testWidgets('with PayTR configured every package also offers paying by card, even when the balance is too low', (tester) async {
    await _pump(tester, _data(balance: 0, card: true));

    expect(find.byKey(const Key('buy_with_card')), findsNWidgets(2));
    expect(find.text('Bakiye yetersiz'), findsNWidgets(2));
    expect(find.text('Kartla Öde'), findsNWidgets(2));
    expect(find.text('Bakiyenden ya da kartınla ödeyebilirsin.'), findsOneWidget);
  });

  testWidgets('packages the balance cannot cover are disabled, not hidden', (tester) async {
    await _pump(tester, _data(balance: 120));

    final buttons = tester.widgetList<FilledButton>(find.byWidgetPredicate((w) => w is FilledButton && w.key != const Key('open_customer_view'))).toList();
    expect(buttons.first.onPressed, isNotNull); // 99 TL package
    expect(buttons.last.onPressed, isNull); // 1.499 TL package
    expect(find.text('Bakiye yetersiz'), findsOneWidget);
  });

  testWidgets('a frozen wallet cannot buy anything', (tester) async {
    await _pump(tester, _data(balance: 5000, frozen: true));
    expect(find.text('Cüzdan donduruldu'), findsNWidgets(2));
  });

  testWidgets('shows the running period, days left and the history', (tester) async {
    await _pump(tester, _data(featured: true));

    expect(find.text('Bu alanda yayındasın'), findsOneWidget);
    expect(find.textContaining('5 gün kaldı'), findsWidgets);
    expect(find.text('Geçmiş'), findsOneWidget);
    expect(find.text('₺499 · Bakiye'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
  });

  testWidgets('each ad placement has its own packages, status and a fixed screenshot of where it shows', (tester) async {
    await _pump(
      tester,
      _placementsData(),
      visibility: {
        'home': {'is_featured': false},
        'listing': {'running': true, 'slots': 3, 'rotation_seconds': 20, 'competitors': 5},
      },
    );

    // The list ad opens first: its packages, its screenshot, where / how.
    expect(find.text('Liste 7 Gün'), findsOneWidget);
    expect(find.text('Vitrin 1 Gün'), findsNothing);
    expect(find.byKey(const Key('placement_shot_listing_mobile')), findsOneWidget);
    expect(find.text('Reklamın nerede görünür'), findsOneWidget);
    expect(find.text('Randevu alırken Hizmet Veren Seçimi listesinin en üstü'), findsOneWidget);
    expect(find.text('Liste Reklamı: Yayında'), findsOneWidget);
    expect(find.text('Ana Sayfa Vitrini: Yayında değil'), findsOneWidget);
    expect(find.textContaining('seninle yarışan 5 hizmet veren'), findsOneWidget);

    // The web screenshot of the same placement is one tap away.
    await tester.ensureVisible(find.byKey(const Key('shot_web')));
    await tester.tap(find.byKey(const Key('shot_web')));
    await tester.pump();
    expect(find.byKey(const Key('placement_shot_listing_web')), findsOneWidget);

    await tester.tap(find.byKey(const Key('placement_tab_home')));
    await tester.pump();
    expect(find.text('Vitrin 1 Gün'), findsOneWidget);
    expect(find.text('Liste 7 Gün'), findsNothing);
    expect(find.byKey(const Key('placement_shot_home_mobile')), findsOneWidget);
  });

  testWidgets('a closed placement shows no packages', (tester) async {
    await _pump(tester, _placementsData(listingEnabled: false, listingRunning: false));

    expect(find.text('Satışa kapalı'), findsOneWidget);
    expect(find.text('Bu reklam alanı şu an satışa kapalı.'), findsOneWidget);
    expect(find.text('Liste 7 Gün'), findsNothing);
  });

  testWidgets('"Müşteri Görünümüne Geç" opens the customer view on the provider list, in preview mode', (tester) async {
    tester.view.physicalSize = const Size(390, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ProviderListQuery? asked;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        providerFeaturedProvider.overrideWith((ref) async => _placementsData()),
        providerAdVisibilityProvider.overrideWith((ref) async => {
              'home': {'is_featured': false},
              'listing': {'running': true, 'slots': 3, 'rotation_seconds': 20, 'competitors': 2},
            }),
        listOriginProvider.overrideWithValue(null),
        providerListLoaderProvider.overrideWithValue((q, page) async {
          asked = q;
          return ProviderListPage(sponsored: [{'user_id': 1, 'business_name': 'Benim Salonum', 'is_sponsored': true}], total: 0);
        }),
      ],
      child: const MaterialApp(home: ProviderFeaturedScreen()),
    ));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('open_customer_view')));
    await tester.tap(find.byKey(const Key('open_customer_view')));
    await tester.pumpAndSettle();

    expect(asked?.preview, isTrue);
    expect(find.byKey(const Key('provider_customer_view')), findsOneWidget);
    expect(find.text('Benim Salonum'), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
  });
}
