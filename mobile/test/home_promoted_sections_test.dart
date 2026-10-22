import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/providers/home_content_providers.dart';
import 'package:app/features/customer/screens/home_promoted_sections.dart';
import 'package:app/features/customer/screens/home_sections.dart';

Map<String, dynamic> _provider(int i, {String type = 'barber'}) => {
      'user_id': 100 + i,
      'business_name': 'Uzman $i',
      'provider_type': type,
      'city': 'İzmir',
      'rating': 4.5,
      'review_count': 10 + i,
    };

Future<void> _pump(WidgetTester tester, Widget child, List<Override> overrides) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [siteConfigDataProvider.overrideWith((ref) async => <String, dynamic>{}), ...overrides],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)))),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('HomeSpotlightSection', () {
    testWidgets('shows one full page of 6 (2 columns x 3 rows), pages with dots and turns on its own', (tester) async {
      final pool = [for (var i = 1; i <= 14; i++) _provider(i)];
      await _pump(tester, const HomeSpotlightSection(), [
        spotlightProvidersProvider.overrideWith((ref) async => SpotlightData(providers: pool, rotateSeconds: 3)),
      ]);

      expect(find.text('Öne Çıkan Profesyoneller'), findsOneWidget);
      for (var i = 1; i <= 6; i++) {
        expect(find.text('Uzman $i'), findsOneWidget);
      }
      expect(find.text('Uzman 7'), findsNothing);
      // Two cards per row: the first two share a top edge, the third starts a new row.
      double top(int i) => tester.getTopLeft(find.text('Uzman $i')).dy;
      expect(top(1), top(2));
      expect(top(3), greaterThan(top(1)));
      expect(find.byKey(const Key('spotlight_dot_2')), findsOneWidget); // 14 providers -> 3 pages
      expect(find.byKey(const Key('spotlight_dot_3')), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Uzman 7'), findsOneWidget);
      expect(find.text('Uzman 1'), findsNothing);

      // The last page borrows from the start so the grid stays full (13, 14, 1, 2, 3, 4).
      await tester.tap(find.byKey(const Key('spotlight_dot_2')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Uzman 13'), findsOneWidget);
      expect(find.text('Uzman 14'), findsOneWidget);
      expect(find.text('Uzman 1'), findsOneWidget);
      expect(find.text('Uzman 4'), findsOneWidget);
      expect(find.text('Uzman 5'), findsNothing);

      // Unmount so the rotation timer is gone.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a touch pauses the rotation', (tester) async {
      final pool = [for (var i = 1; i <= 8; i++) _provider(i)];
      await _pump(tester, HomeSpotlightSection(onProviderTap: (id, name) {}), [
        spotlightProvidersProvider.overrideWith((ref) async => SpotlightData(providers: pool, rotateSeconds: 3)),
      ]);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Uzman 1')));
      await gesture.up();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Uzman 1'), findsOneWidget, reason: 'paused for a while after a touch');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is hidden when nobody is featured', (tester) async {
      await _pump(tester, const HomeSpotlightSection(), [
        spotlightProvidersProvider.overrideWith((ref) async => const SpotlightData()),
      ]);
      expect(find.text('Öne Çıkan Profesyoneller'), findsNothing);
    });

    testWidgets('a single page has no pager and never rotates', (tester) async {
      await _pump(tester, const HomeSpotlightSection(), [
        spotlightProvidersProvider.overrideWith((ref) async => SpotlightData(providers: [for (var i = 1; i <= 4; i++) _provider(i)], rotateSeconds: 3)),
      ]);
      expect(find.text('Uzman 4'), findsOneWidget);
      expect(find.byKey(const Key('spotlight_dot_0')), findsNothing, reason: 'one page = no pager');
      await tester.pump(const Duration(seconds: 10)); // no timer was created, nothing pending
    });

    testWidgets('tapping a card reports the provider', (tester) async {
      int? opened;
      await _pump(tester, HomeSpotlightSection(onProviderTap: (id, name) => opened = id), [
        spotlightProvidersProvider.overrideWith((ref) async => SpotlightData(providers: [_provider(1), _provider(2)])),
      ]);
      await tester.tap(find.text('Uzman 2'));
      expect(opened, 102);
    });
  });

  group('HomeNewestSection', () {
    testWidgets('lists the newest providers with how long ago they joined', (tester) async {
      final joined = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      await _pump(tester, const HomeNewestSection(), [
        newestProvidersProvider.overrideWith((ref) async => [
              {..._provider(1), 'joined_at': joined},
              {..._provider(2, type: 'coiffeur'), 'joined_at': null},
            ]),
      ]);

      expect(find.text('Yeni Katılan Profesyoneller'), findsOneWidget);
      expect(find.text('Uzman 1'), findsOneWidget);
      expect(find.text('3 gün önce katıldı'), findsOneWidget);
      expect(find.text('Kadın Kuaförü'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is hidden without providers', (tester) async {
      await _pump(tester, const HomeNewestSection(), [newestProvidersProvider.overrideWith((ref) async => const <Map<String, dynamic>>[])]);
      expect(find.text('Yeni Katılan Profesyoneller'), findsNothing);
    });

    test('joinedLabel', () {
      final now = DateTime(2026, 10, 20, 12);
      expect(joinedLabel(null, now: now), 'Yeni katıldı');
      expect(joinedLabel(now.toIso8601String(), now: now), 'Bugün katıldı');
      expect(joinedLabel(now.subtract(const Duration(days: 1)).toIso8601String(), now: now), 'Dün katıldı');
      expect(joinedLabel(now.subtract(const Duration(days: 15)).toIso8601String(), now: now), '2 hafta önce katıldı');
      expect(joinedLabel(now.subtract(const Duration(days: 95)).toIso8601String(), now: now), '3 ay önce katıldı');
      expect(joinedLabel(now.subtract(const Duration(days: 800)).toIso8601String(), now: now), 'Aramızda');
    });
  });

  group('HomeStatsSection', () {
    testWidgets('renders what the server resolved, real or typed, without deciding itself', (tester) async {
      await _pump(tester, const HomeStatsSection(audience: 'customer'), [
        homeStatsProvider('customer').overrideWith((ref) async => [
              {'key': 'providers', 'metric': 'providers', 'label': 'Doğrulanmış Hizmet Veren', 'desc': 'Belge kontrolünden geçti', 'value': '2.500+', 'is_fake': true},
              {'key': 'avg_rating', 'metric': 'avg_rating', 'label': 'Ortalama Tarak Puanı', 'desc': null, 'value': '4,8', 'is_fake': false},
            ]),
      ]);

      expect(find.text('2.500+'), findsOneWidget);
      expect(find.text('Doğrulanmış Hizmet Veren'), findsOneWidget);
      expect(find.text('4,8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    Map<String, dynamic> stat(String metric, String value) => {'key': metric, 'metric': metric, 'label': 'Etiket $metric', 'desc': 'Açıklama', 'value': value, 'is_fake': false};

    testWidgets('three numbers share one row instead of leaving an orphan tile', (tester) async {
      await _pump(tester, const HomeStatsSection(), [
        homeStatsProvider('all').overrideWith((ref) async => [stat('providers', '101'), stat('customers', '102'), stat('avg_rating', '4,0')]),
      ]);

      expect(tester.getTopLeft(find.text('101')).dy, tester.getTopLeft(find.text('102')).dy);
      expect(tester.getTopLeft(find.text('102')).dy, tester.getTopLeft(find.text('4,0')).dy);
      expect(tester.takeException(), isNull);
    });

    testWidgets('five numbers fill rows of two and the odd last tile spans its own row', (tester) async {
      await _pump(tester, const HomeStatsSection(), [
        homeStatsProvider('all').overrideWith((ref) async => [
              stat('providers', '1'), stat('customers', '2'), stat('weekly_services', '3'), stat('reviews', '4'), stat('cities', '5'),
            ]),
      ]);

      expect(tester.getTopLeft(find.text('1')).dy, tester.getTopLeft(find.text('2')).dy);
      expect(tester.getTopLeft(find.text('3')).dy, tester.getTopLeft(find.text('4')).dy);
      expect(tester.getTopLeft(find.text('5')).dy, greaterThan(tester.getTopLeft(find.text('3')).dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('is hidden when there is nothing to show', (tester) async {
      await _pump(tester, const HomeStatsSection(), [homeStatsProvider('all').overrideWith((ref) async => const <Map<String, dynamic>>[])]);
      expect(find.byKey(const Key('home_stats_grid')), findsNothing);
    });
  });

  group('VerifiedProvidersSection filter', () {
    testWidgets('Kadın / Erkek chips swap the list for the server-ranked one of that type', (tester) async {
      await _pump(tester, VerifiedProvidersSection(providers: [_provider(1), _provider(2, type: 'coiffeur')]), [
        verifiedProvidersByTypeProvider('coiffeur').overrideWith((ref) async => [_provider(5, type: 'coiffeur')]),
        verifiedProvidersByTypeProvider('barber').overrideWith((ref) async => [_provider(7)]),
      ]);

      expect(find.text('Uzman 1'), findsOneWidget);
      expect(find.text('Tümü'), findsOneWidget);

      await tester.tap(find.text('Kadın Kuaför'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Uzman 5'), findsOneWidget);
      expect(find.text('Uzman 1'), findsNothing);

      await tester.tap(find.text('Erkek Berber'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Uzman 7'), findsOneWidget);

      await tester.tap(find.text('Tümü'));
      await tester.pump();
      expect(find.text('Uzman 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
