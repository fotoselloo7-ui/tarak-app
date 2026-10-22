import 'package:app/core/widgets/verified_tick.dart';
import 'package:app/features/chat/models/conversation_model.dart';
import 'package:app/features/chat/widgets/conversation_card.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/customer/screens/all_providers_screen.dart';
import 'package:app/features/customer/screens/favorites_screen.dart';
import 'package:app/features/shared/widgets/provider_preview_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _p(int i, {required bool verified}) => {
      'user_id': i,
      'business_name': 'Uzman $i',
      'provider_type': 'barber',
      'city': 'İzmir',
      'rating': 4.5,
      'review_count': 10,
      'service_count': 4,
      'is_verified': verified,
    };

/// A tick next to the name: how many of the visible [names] have one, by looking at the row that holds the name.
int _ticksNextTo(WidgetTester tester, String name) {
  final row = find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
  return find.descendant(of: row, matching: find.byType(VerifiedTick)).evaluate().length;
}

void main() {
  testWidgets('ProviderNameRow: tick only for a verified provider; a long name shortens, the tick stays', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const ProviderNameRow(name: 'Onaylı Usta', verified: true),
            const ProviderNameRow(name: 'Belgesiz Usta', verified: false),
            SizedBox(width: 120, child: ProviderNameRow(name: 'Çok Uzun Bir Berber Salonu Adı Burada', verified: true, key: const Key('narrow'))),
          ],
        ),
      ),
    ));

    expect(_ticksNextTo(tester, 'Onaylı Usta'), 1);
    expect(_ticksNextTo(tester, 'Belgesiz Usta'), 0);
    expect(find.descendant(of: find.byKey(const Key('narrow')), matching: find.byType(VerifiedTick)), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Onaylı hizmet veren'), findsNWidgets(2));
  });

  test('isVerifiedMap: is_verified, or is_approved for older shapes', () {
    expect(isVerifiedMap({'is_verified': true}), isTrue);
    expect(isVerifiedMap({'is_verified': false, 'is_approved': true}), isFalse);
    expect(isVerifiedMap({'is_approved': true}), isTrue);
    expect(isVerifiedMap({'name': 'x'}), isFalse);
    expect(isVerifiedMap(null), isFalse);
  });

  testWidgets('the provider list marks every verified provider, recommended ones included, and only those', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        providerListLoaderProvider.overrideWithValue((q, page) async => ProviderListPage(
              items: [_p(1, verified: true), _p(2, verified: false), _p(3, verified: true)],
              sponsored: [{..._p(4, verified: true), 'is_sponsored': true}],
              total: 3,
            )),
        listOriginProvider.overrideWithValue(null),
        providerAdVisibilityProvider.overrideWith((ref) async => const {}),
      ],
      child: const MaterialApp(home: AllProvidersScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(_ticksNextTo(tester, 'Uzman 1'), 1);
    expect(_ticksNextTo(tester, 'Uzman 2'), 0);
    expect(_ticksNextTo(tester, 'Uzman 3'), 1);
    expect(_ticksNextTo(tester, 'Uzman 4'), 1); // the "Önerilen" card too
  });

  testWidgets('favourites carry the tick too', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        favoritesProvider.overrideWith((ref) async => [
              {'provider_user_id': 1, 'business_name': 'Onaylı Usta', 'is_verified': true, 'rating_count': 0},
              {'provider_user_id': 2, 'business_name': 'Belgesiz Usta', 'is_verified': false, 'rating_count': 0},
            ]),
      ],
      child: const MaterialApp(home: FavoritesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(_ticksNextTo(tester, 'Onaylı Usta'), 1);
    expect(_ticksNextTo(tester, 'Belgesiz Usta'), 0);
  });

  testWidgets('the conversation list shows the tick for a verified provider (same blue tick as everywhere)', (tester) async {
    Widget card(bool verified) => ConversationCard(
          onTap: () {},
          conversation: ConversationModel(
            id: 1,
            resourceType: 'INSTANT_REQUEST',
            resourceId: 1,
            customerUserId: 1,
            providerUserId: 2,
            status: 'ACTIVE',
            otherParty: OtherPartyModel(id: 2, name: verified ? 'Onaylı Usta' : 'Belgesiz Usta', isVerified: verified),
          ),
        );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [card(true), card(false)]))));

    expect(_ticksNextTo(tester, 'Onaylı Usta'), 1);
    expect(_ticksNextTo(tester, 'Belgesiz Usta'), 0);
    final tick = tester.widget<Icon>(find.descendant(of: find.byType(VerifiedTick), matching: find.byType(Icon)));
    expect(tick.color, VerifiedTick.color);
  });
}
