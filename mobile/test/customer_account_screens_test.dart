import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/widgets/service_icon.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/screens/customer_profile_edit_screen.dart';
import 'package:app/features/auth/widgets/web_landing_widgets.dart' show trUpper;
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/screens/customer_settings_screen.dart';
import 'package:app/features/customer/services/geo_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/disk_asset_bundle.dart';

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
        user: UserModel(id: 5, name: 'Test Musteri', role: 'CUSTOMER', email: 'customer@berberimgelsin.com'),
      );

  @override
  Future<void> restoreSession() async {}
}

Map<String, dynamic> _profileBody({String province = 'İstanbul'}) => {
      'success': true,
      'data': {
        'user': {'id': 5, 'first_name': 'Test', 'last_name': 'Musteri', 'email': 'customer@berberimgelsin.com', 'phone': '+905550000003', 'gender': null},
        'profile': {
          'birth_date': null,
          'default_address': {
            'title': 'Ev',
            'province': province,
            'district': 'Şişli',
            'neighborhood': 'Merkez Mah.',
            'street': 'Halaskargazi Cad.',
            'building_no': '5',
            'apartment_no': null,
            'directions': 'Mavi kapı',
            'latitude': 41.05,
            'longitude': 28.98,
          },
        },
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

  group('service icons', () {
    test('catalog icon classes and names resolve to different icons', () {
      IconData icon(String? cls, String name) => resolveServiceVisual(cls, name).icon;

      expect(icon('fa-solid fa-scissors', 'Saç Kesimi'), Icons.content_cut_rounded);
      expect(icon('fa-solid fa-crown', 'Damat Tıraşı'), Icons.workspace_premium_rounded);
      expect(icon('fa-solid fa-child', 'Çocuk Tıraşı'), Icons.child_care_rounded);
      expect(icon('fa-solid fa-paintbrush', 'Saç Boyama (Erkek)'), Icons.format_paint_rounded);
      expect(icon('fa-solid fa-wind', 'Fön'), Icons.air_rounded);
      // The generic "fa-user" of "Sakal Tıraşı" must not fall back to scissors.
      expect(icon('fa-solid fa-user', 'Sakal Tıraşı'), Icons.face_retouching_natural_rounded);
      // No icon class at all: the name decides; unknown names keep the default scissors.
      expect(icon(null, 'Makyaj (Günlük)'), Icons.auto_fix_high_rounded);
      expect(icon(null, 'Bilinmeyen'), Icons.content_cut_rounded);
    });
  });

  testWidgets('profile editor loads the account and saves name, gender, birth date and address together', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _Adapter((o) {
      if (o.path == '/customer/profile' && o.method == 'GET') return {'body': _profileBody()};
      if (o.path == '/customer/profile' && o.method == 'PUT') return {'body': {'success': true}};
      return {'status': 404, 'body': {}};
    });
    final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
        geoServiceProvider.overrideWithValue(GeoService(bundle: DiskAssetBundle())),
      ],
      child: const MaterialApp(home: CustomerProfileEditScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Profili Düzenle'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Test'), findsOneWidget);
    // il / ilçe / mahalle are pickers fed by the bundled Turkey data; the stored values are preselected
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(find.text('İstanbul'), findsOneWidget);
    expect(find.text('Şişli'), findsOneWidget);
    expect(find.text('customer@berberimgelsin.com'), findsOneWidget);

    await tester.tap(find.text('Kadın'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Musteri'), 'Yılmaz');
    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    final body = put.data as Map<String, dynamic>;
    expect(body['first_name'], 'Test');
    expect(body['last_name'], 'Yılmaz');
    expect(body['gender'], 'female');
    expect(body['birth_date'], isNull);
    final address = body['address'] as Map<String, dynamic>;
    expect(address['province'], 'İstanbul');
    expect(address['district'], 'Şişli');
    expect(address['neighborhood'], 'Merkez Mah.'); // a stored value outside the list is kept, not dropped
    // The API rewrites the whole address: what the form does not edit travels back unchanged.
    expect(address['directions'], 'Mavi kapı');
    expect(address['latitude'], 41.05);
    expect(address['longitude'], 28.98);
  });

  testWidgets('profile editor refuses a half-filled address and an empty name', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // An older half-filled address: an ilçe without an il.
    final adapter = _Adapter((o) {
      if (o.path == '/customer/profile' && o.method == 'GET') return {'body': _profileBody(province: '')};
      return {'status': 404, 'body': {}};
    });
    final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
        geoServiceProvider.overrideWithValue(GeoService(bundle: DiskAssetBundle())),
      ],
      child: const MaterialApp(home: CustomerProfileEditScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Test'), '');
    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Ad alanı zorunludur.'), findsOneWidget);
    expect(find.text('İl gerekli'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets('settings page groups account, notifications, security, privacy and deletion', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _Adapter((o) {
      if (o.path.contains('push-preference') || o.path.contains('preferences')) {
        return {'body': {'success': true, 'data': {'push_enabled': true}}};
      }
      return {'body': {'success': true, 'data': {'push_enabled': true}}};
    });
    final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = adapter);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        secureStorageProvider.overrideWithValue(storage),
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
      ],
      child: const MaterialApp(home: CustomerSettingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
    for (final label in ['Hesap', 'Bildirimler', 'Güvenlik', 'Gizlilik ve yardım', 'Hesap silme']) {
      expect(find.text(trUpper(label)), findsOneWidget, reason: label);
    }
    expect(find.text('Şifre değiştir'), findsOneWidget);
    expect(find.text('Cihaz oturumları'), findsOneWidget);
    expect(find.text('Hesabımı sil'), findsOneWidget);
    expect(find.text('Test Musteri'), findsOneWidget);
  });
}
