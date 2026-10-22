import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/provider/screens/provider_wallet_screen.dart';
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
  final List<RequestOptions> requests = [];
  final Map<String, dynamic> Function(RequestOptions o) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
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

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 7, name: 'Can Berber', role: 'PROVIDER', email: 'can@example.test'),
      );

  @override
  Future<void> restoreSession() async {}
}

Map<String, dynamic> _wallet({bool depleted = false}) => {
      'success': true,
      'data': {
        'currency': 'TRY',
        'cash_balance': 250.0,
        'promo_balance': depleted ? 0.0 : 350.0,
        'reserved_cash_balance': 0.0,
        'reserved_promo_balance': depleted ? 0.0 : 150.0,
        'withdrawable_balance': 250.0,
        'usable_commission_balance': depleted ? 250.0 : 450.0,
        'deposited_balance': 250.0,
        'reserved_total': depleted ? 0.0 : 150.0,
        'gift': {
          'granted': 500.0,
          'used': depleted ? 500.0 : 150.0,
          'remaining': depleted ? 0.0 : 350.0,
          'reserved': depleted ? 0.0 : 150.0,
          'usable': depleted ? 0.0 : 200.0,
          'has_gift': true,
          'is_depleted': depleted,
          'depleted_at': null,
          'campaign_message': "İlk 500 TL komisyon Tarak.app'ten!",
        },
        'active_reservations': depleted
            ? []
            : [
                {
                  'id': 1,
                  'resource_type': 'INSTANT_REQUEST',
                  'resource_id': 12,
                  'label': 'Anlık talep #12',
                  'status': 'RESERVED',
                  'commission_amount': 150.0,
                  'reserved_promo_amount': 150.0,
                  'reserved_cash_amount': 0.0,
                  'reserved_at': null,
                },
              ],
      },
    };

void main() {
  late SecureStorageService storage;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    storage = SecureStorageService(secureStorage: _FakeStorage());
    await storage.init();
  });

  Future<_Adapter> pumpWallet(
    WidgetTester tester, {
    bool depleted = false,
    Map<String, dynamic>? emailResponse,
  }) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = _Adapter((o) {
      if (o.path == '/provider/wallet') return {'body': _wallet(depleted: depleted)};
      if (o.path == '/provider/payout-account') return {'body': {'success': true, 'data': null}};
      if (o.path == '/provider/wallet/transactions') return {'body': {'success': true, 'data': []}};
      if (o.path == '/provider/payouts') return {'body': {'success': true, 'data': []}};
      if (o.path == '/provider/finance/payment-info/email') {
        return emailResponse ??
            {
              'body': {
                'success': true,
                'message': 'Ödeme bilgileriniz c***@example.test adresine gönderiliyor.',
                'data': {'email': 'c***@example.test'},
              },
            };
      }
      return {'status': 404, 'body': {}};
    });
    final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
      ],
      child: const MaterialApp(home: ProviderWalletScreen()),
    ));
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('finance center shows the gift right, deposited / reserved / usable amounts and reservations', (tester) async {
    await pumpWallet(tester);

    expect(find.text('İşletme Finans Merkezi'), findsOneWidget);
    expect(find.byKey(const Key('gift-commission-card')), findsOneWidget);
    expect(find.text("İlk 500 TL komisyon Tarak.app'ten!"), findsOneWidget);
    expect(find.text('Hediye komisyon hakkınız aktif'), findsOneWidget);
    expect(find.text('500,00 TL'), findsOneWidget); // granted
    expect(find.text('150,00 TL'), findsWidgets); // used, reserved
    expect(find.text('350,00 TL'), findsWidgets); // remaining
    expect(find.text('Yüklenen komisyon bakiyesi'), findsOneWidget);
    expect(find.text('Rezerve komisyon'), findsOneWidget);
    expect(find.text('Yeni işler için kullanılabilir'), findsOneWidget);
    expect(find.text('450,00 TL'), findsOneWidget);
    expect(find.text('Anlık talep #12'), findsOneWidget);
    // the gift is never presented as cash
    expect(find.textContaining('çekilebilir nakit değildir'), findsOneWidget);
  });

  testWidgets('a used up gift says so', (tester) async {
    await pumpWallet(tester, depleted: true);

    expect(find.text('Hediye komisyon hakkınız tamamlandı'), findsOneWidget);
    expect(find.text('Anlık talep #12'), findsNothing);
  });

  testWidgets('the app never shows bank account details; payment info goes to the registered e-mail', (tester) async {
    final adapter = await pumpWallet(tester);

    // no payment-info request is made just by opening the screen, and no IBAN / TRK code is on screen
    expect(adapter.requests.where((r) => r.path.contains('/finance/')), isEmpty);
    expect(find.textContaining('TR'), findsNothing, reason: 'no IBAN');
    expect(find.textContaining('TRK'), findsNothing, reason: 'no reference code');
    expect(find.textContaining('güvenlik gereği uygulamada gösterilmez'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('email-payment-info')));
    await tester.tap(find.byKey(const Key('email-payment-info')));
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.path == '/provider/finance/payment-info/email');
    expect(post.method, 'POST');
    expect(find.text('Ödeme bilgileriniz c***@example.test adresine gönderiliyor.'), findsOneWidget);
  });

  testWidgets('the rate limit answer of the server is shown to the business', (tester) async {
    final adapter = await pumpWallet(tester, emailResponse: {
      'status': 429,
      'body': {'success': false, 'message': 'Çok sık istek gönderdiniz. 42 dakika sonra tekrar deneyin.', 'retry_after': 2520},
    });

    await tester.ensureVisible(find.byKey(const Key('email-payment-info')));
    await tester.tap(find.byKey(const Key('email-payment-info')));
    await tester.pumpAndSettle();

    expect(adapter.requests.where((r) => r.path == '/provider/finance/payment-info/email'), isNotEmpty);
    expect(find.text('Çok sık istek gönderdiniz. 42 dakika sonra tekrar deneyin.'), findsOneWidget);
  });
}
