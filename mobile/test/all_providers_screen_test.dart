import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/customer/screens/all_providers_screen.dart';
import 'package:app/features/shared/widgets/provider_preview_banner.dart';

Map<String, dynamic> _p(int i, {String type = 'barber', double? rating = 4.5, int reviews = 10}) => {
      'user_id': i,
      'business_name': 'Uzman $i',
      'provider_type': type,
      'city': 'İzmir',
      'rating': rating,
      'review_count': reviews,
      'service_count': 4,
    };

class _Calls {
  final List<(ProviderListQuery, int)> calls = [];
}

Future<_Calls> _pump(WidgetTester tester, ProviderListLoader loader, {void Function(int, String)? onTap, ListOrigin? origin, bool preview = false}) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final calls = _Calls();
  final List<Override> overrides = [
    providerListLoaderProvider.overrideWithValue((q, page) {
      calls.calls.add((q, page));
      return loader(q, page);
    }),
    // No auth / saved address in these tests: the position is whatever the test gives.
    listOriginProvider.overrideWithValue(origin),
    providerAdVisibilityProvider.overrideWith((ref) async => {
      'home': {'is_featured': false},
      'listing': {'running': true, 'slots': 3, 'rotation_seconds': 20, 'competitors': 4},
    }),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: AllProvidersScreen(onProviderTap: onTap, preview: preview))));
  await tester.pump();
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('lists every provider with stars, review count and a total, and opens a tapped one', (tester) async {
    int? opened;
    await _pump(
      tester,
      (q, page) async => ProviderListPage(items: [_p(1), _p(2, type: 'coiffeur', rating: null, reviews: 0)], total: 2),
      onTap: (id, name) => opened = id,
    );

    expect(find.text('Hizmet Verenler'), findsOneWidget);
    expect(find.text('2 uzman'), findsOneWidget);
    expect(find.text('Uzman 1'), findsOneWidget);
    expect(find.text('Henüz değerlendirme yok'), findsOneWidget);
    expect(find.text('Kadın Kuaförü'), findsOneWidget);

    await tester.tap(find.text('Uzman 2'));
    expect(opened, 2);
  });

  testWidgets('gender, sort, stars and review chips re-query the server from page 1 and the count follows', (tester) async {
    final calls = await _pump(tester, (q, page) async => ProviderListPage(items: [_p(page)], total: q.isDefault ? 40 : 3));

    expect(calls.calls.last.$1.isDefault, isTrue);
    expect(find.text('40 uzman'), findsOneWidget);

    await tester.tap(find.byKey(const Key('type_chip_Kadın Kuaför')));
    await tester.pump();
    await tester.pump();
    expect(calls.calls.last.$1.type, 'coiffeur');
    expect(calls.calls.last.$2, 1);

    await tester.ensureVisible(find.byKey(const Key('filter_sort_reviews')));

    await tester.tap(find.byKey(const Key('filter_sort_reviews')));
    await tester.pump();
    await tester.pump();
    expect(calls.calls.last.$1.sort, 'reviews');
    expect(calls.calls.last.$1.type, 'coiffeur', reason: 'filters combine');

    await tester.ensureVisible(find.byKey(const Key('filter_rating_4+')));

    await tester.tap(find.byKey(const Key('filter_rating_4+')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('reviews_chip_10+')));
    await tester.pump();
    await tester.pump();
    final last = calls.calls.last.$1;
    expect(last.minRating, 4.0);
    expect(last.minReviews, 10);
    expect(find.text('3 uzman bulundu'), findsOneWidget);

    expect(last.toParams(1, 12), {'type': 'coiffeur', 'sort': 'reviews', 'min_rating': 4.0, 'min_reviews': 10, 'page': 1, 'per_page': 12});

    await tester.tap(find.text('Filtreleri temizle').first);
    await tester.pump();
    await tester.pump();
    expect(calls.calls.last.$1.isDefault, isTrue);
  });

  testWidgets('the search box re-queries after a short pause', (tester) async {
    final calls = await _pump(tester, (q, page) async => ProviderListPage(items: [_p(1)], total: 1));

    await tester.enterText(find.byKey(const Key('all_providers_search')), 'Bursa');
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls.calls.last.$1.q, '', reason: 'debounced');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(calls.calls.last.$1.q, 'Bursa');
  });

  testWidgets('scrolling to the end loads the next page and appends it', (tester) async {
    final calls = await _pump(tester, (q, page) async => ProviderListPage(
          items: [for (var i = 0; i < 12; i++) _p(page * 100 + i)],
          currentPage: page,
          lastPage: 2,
          total: 24,
        ));

    expect(find.text('Uzman 100'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(calls.calls.last.$2, 2);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pump();
    expect(find.text('Uzman 211'), findsOneWidget);
    // Past the last page nothing more is requested.
    final count = calls.calls.length;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pump();
    expect(calls.calls.length, count);
  });

  testWidgets('shows an empty state and an error state with retry', (tester) async {
    await _pump(tester, (q, page) async => const ProviderListPage());
    expect(find.text('Bu filtrelere uygun hizmet veren bulunamadı.'), findsOneWidget);
  });

  testWidgets('without a position the distance filter asks for the location instead of offering radii', (tester) async {
    await _pump(tester, (q, page) async => ProviderListPage(items: [_p(1)], total: 1));

    expect(find.byKey(const Key('filter_use_location')), findsOneWidget);
    expect(find.byKey(const Key('filter_distance_10 km')), findsNothing);
    expect(find.text('Mesafeye göre süzmek ve sıralamak için konum gerekir.'), findsOneWidget);
  });

  testWidgets('with a position the radius chips and nearest-first sort query the server with lat / lng and distances show on cards', (tester) async {
    final calls = await _pump(
      tester,
      (q, page) async => ProviderListPage(items: [{..._p(1), 'distance_km': 2.4}], total: 1),
      origin: const ListOrigin(lat: 41.0082, lng: 28.9784),
    );

    expect(calls.calls.last.$1.toParams(1, 12)['lat'], 41.0082);
    expect(find.text('2,4 km'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('filter_distance_10 km')));

    await tester.tap(find.byKey(const Key('filter_distance_10 km')));
    await tester.pump();
    await tester.pump();
    expect(calls.calls.last.$1.maxDistanceKm, 10);
    expect(calls.calls.last.$1.toParams(1, 12)['max_distance_km'], 10);

    await tester.ensureVisible(find.byKey(const Key('filter_sort_distance')));

    await tester.tap(find.byKey(const Key('filter_sort_distance')));
    await tester.pump();
    await tester.pump();
    expect(calls.calls.last.$1.sort, 'distance');
    expect(calls.calls.last.$1.toParams(1, 12)['sort'], 'distance');
  });

  testWidgets('the nearest-first sort falls back to stars while the position is unknown', (tester) async {
    const query = ProviderListQuery(sort: 'distance');
    expect(query.toParams(1, 12)['sort'], 'rating');
    expect(query.toParams(1, 12).containsKey('lat'), isFalse);
  });

  testWidgets('list ads come first in a "Önerilen" slot and are tagged', (tester) async {
    int? opened;
    await _pump(
      tester,
      (q, page) async => ProviderListPage(items: [_p(1)], sponsored: [{..._p(9), 'is_sponsored': true}], total: 1),
      onTap: (id, name) => opened = id,
    );

    expect(find.byKey(const Key('recommended_slot')), findsOneWidget);
    expect(find.text('Önerilen'), findsOneWidget);
    expect(find.text('Uzman 9'), findsOneWidget);
    await tester.tap(find.text('Uzman 9'));
    expect(opened, 9);
    // Only ads show when the organic list is empty after filtering.
  });

  testWidgets('preview ("Müşteri görünümü") asks the server for the provider\x27s own ad and shows the way back', (tester) async {
    final calls = await _pump(
      tester,
      (q, page) async => ProviderListPage(sponsored: [{..._p(7), 'is_sponsored': true}], total: 0),
      preview: true,
    );

    expect(calls.calls.last.$1.preview, isTrue);
    expect(calls.calls.last.$1.toParams(1, 12)['preview'], 1);
    expect(find.text('Müşteri görünümündesin'), findsOneWidget);
    expect(find.textContaining('Liste reklamın yayında'), findsOneWidget);
    expect(find.byKey(const Key('provider_preview_back')), findsOneWidget);
    expect(find.text('Uzman 7'), findsOneWidget);
  });

  testWidgets('the recommended cards change every rotation period and the organic list hides the ones in the slot', (tester) async {
    var refreshes = 0;
    final calls = await _pump(tester, (q, page) async {
      if (q.sponsoredOnly) {
        refreshes++;
        return ProviderListPage(sponsored: [{..._p(refreshes == 1 ? 8 : 9), 'is_sponsored': true}], rotationSeconds: 20);
      }
      return ProviderListPage(items: [_p(8), _p(9), _p(1)], sponsored: [{..._p(7), 'is_sponsored': true}], total: 3, rotationSeconds: 20);
    });

    // First set: Uzman 7 in the slot, the three organic rows below.
    expect(find.byKey(const ValueKey('recommended_7')), findsOneWidget);
    expect(find.text('Uzman 8'), findsOneWidget);
    expect(find.text('Uzman 9'), findsOneWidget);

    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls.calls.last.$1.sponsoredOnly, isTrue, reason: 'only the cards are asked for');
    expect(calls.calls.last.$1.toParams(1, 12)['sponsored_only'], 1);
    expect(find.byKey(const ValueKey('recommended_8')), findsOneWidget);
    expect(find.byKey(const ValueKey('recommended_7')), findsNothing);
    expect(find.text('Uzman 8'), findsOneWidget, reason: 'hidden from the organic list while it is in the slot');
    expect(find.text('Uzman 7'), findsNothing, reason: '7 is not in the organic rows at all');

    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('recommended_9')), findsOneWidget);
    expect(find.text('Uzman 8'), findsOneWidget, reason: '8 rotated out of the slot and is listed organically again');
  });


  testWidgets('a failed load can be retried', (tester) async {
    var fail = true;
    await _pump(tester, (q, page) async {
      if (fail) throw Exception('offline');
      return ProviderListPage(items: [_p(1)], total: 1);
    });
    expect(find.text('Hizmet verenler yüklenemedi.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Uzman 1'), findsOneWidget);
  });
}
