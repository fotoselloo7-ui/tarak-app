import 'package:app/core/app_icon/app_icon_options.dart';
import 'package:app/core/app_icon/app_icon_service.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/auth_gate.dart';
import 'package:app/features/auth/widgets/brand_splash.dart';
import 'package:app/features/shared/screens/app_icon_screen.dart';
import 'package:app/features/shared/widgets/app_icon_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _FakeIcons implements AppIconService {
  final bool supported;
  final bool prompt;
  String currentId;
  final List<String> changed = [];
  bool prompted = false;
  _FakeIcons({this.supported = true, this.prompt = false, this.currentId = 'altin'});

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<String> current() async => currentId;
  @override
  Future<void> change(String id) async {
    changed.add(id);
    currentId = id;
  }

  @override
  Future<bool> shouldPrompt() async => supported && prompt && !prompted;
  @override
  Future<void> markPrompted() async => prompted = true;
}

Future<void> _pumpScreen(WidgetTester tester, _FakeIcons icons, {bool firstRun = false}) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [appIconServiceProvider.overrideWithValue(icons)],
    child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppIconScreen(firstRun: firstRun))), child: const Text('aç')))))),
  ));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  const channel = MethodChannel('app.tarak.mobile/app_icon');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MethodChannelAppIconService', () {
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    test('without a native side (tests, web, desktop) nothing is supported and nothing is asked', () async {
      final service = MethodChannelAppIconService();
      expect(await service.isSupported(), isFalse);
      expect(await service.shouldPrompt(), isFalse);
      expect(await service.current(), kDefaultAppIconId);
      expect(() => service.change('mavi'), throwsA(isA<AppIconException>()));
    });

    test('sends the ids and the default, reads the current icon and changes it', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'isSupported' => true,
          'current' => 'mor',
          _ => true,
        };
      });
      final service = MethodChannelAppIconService();

      expect(await service.isSupported(), isTrue);
      expect(await service.current(), 'mor');
      await service.change('zumrut');

      final change = calls.last;
      expect(change.method, 'change');
      expect(change.arguments['id'], 'zumrut');
      expect(change.arguments['default'], kDefaultAppIconId);
      expect(change.arguments['ids'], [for (final o in kAppIconOptions) o.id]);
    });

    test('a native error becomes an AppIconException; an unknown id never reaches the native side', () async {
      var asked = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        asked++;
        if (call.method == 'change') throw PlatformException(code: 'icon_failed', message: 'Reddedildi');
        return true;
      });
      final service = MethodChannelAppIconService();

      await expectLater(service.change('mavi'), throwsA(isA<AppIconException>().having((e) => e.message, 'message', 'Reddedildi')));
      asked = 0;
      await expectLater(service.change('yok'), throwsA(isA<AppIconException>()));
      expect(asked, 0);
    });

    test('the first-run question is asked once', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => true);
      final service = MethodChannelAppIconService();

      expect(await service.shouldPrompt(), isTrue);
      await service.markPrompted();
      expect(await service.shouldPrompt(), isFalse);
    });
  });

  test('ten options, the same mark on different backgrounds, the default among them', () {
    expect(kAppIconOptions.length, 10);
    expect({for (final o in kAppIconOptions) o.id}.length, 10);
    expect(kAppIconOptions.any((o) => o.id == kDefaultAppIconId), isTrue);
  });

  testWidgets('settings: pick a colour, apply it, and the choice goes to the service', (tester) async {
    final icons = _FakeIcons();
    await _pumpScreen(tester, icons);

    expect(find.text('Uygulama İkonu'), findsOneWidget);
    for (final option in kAppIconOptions) {
      expect(find.byKey(Key('app_icon_${option.id}')), findsOneWidget);
    }
    // Nothing changed yet: nothing to apply.
    expect(tester.widget<FilledButton>(find.byKey(const Key('app_icon_apply'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('app_icon_mavi')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('app_icon_apply'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('app_icon_apply')));
    await tester.pumpAndSettle();

    expect(icons.changed, ['mavi']);
    expect(find.textContaining('Mavi'), findsWidgets);
    expect(find.textContaining('ayarlandı'), findsOneWidget);
  });

  testWidgets('first run: "Şimdilik atla" remembers the answer and changes nothing', (tester) async {
    final icons = _FakeIcons(prompt: true);
    await _pumpScreen(tester, icons, firstRun: true);

    expect(find.text('İkonunu seç'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app_icon_skip')));
    await tester.pumpAndSettle();

    expect(icons.prompted, isTrue);
    expect(icons.changed, isEmpty);
    expect(find.text('İkonunu seç'), findsNothing);
  });

  testWidgets('first run: choosing a colour applies it and closes the screen', (tester) async {
    final icons = _FakeIcons(prompt: true);
    await _pumpScreen(tester, icons, firstRun: true);

    await tester.tap(find.byKey(const Key('app_icon_bordo')));
    await tester.pumpAndSettle();
    expect(find.text('Bu ikonu kullan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app_icon_apply')));
    await tester.pumpAndSettle();

    expect(icons.prompted, isTrue);
    expect(icons.changed, ['bordo']);
    expect(find.text('İkonunu seç'), findsNothing);
  });

  testWidgets('the profile card shows the current icon and opens the picker; it is hidden where icons cannot change', (tester) async {
    Future<void> pump(_FakeIcons icons) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appIconServiceProvider.overrideWithValue(icons)],
        child: const MaterialApp(home: Scaffold(body: Column(children: [AppIconCard()]))),
      ));
      await tester.pumpAndSettle();
    }

    await pump(_FakeIcons(supported: false));
    expect(find.byKey(const Key('app_icon_card')), findsNothing);

    await pump(_FakeIcons(currentId: 'turuncu'));
    expect(find.byKey(const Key('app_icon_card')), findsOneWidget);
    expect(find.textContaining('Şu an: Turuncu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_icon_card')));
    await tester.pumpAndSettle();
    expect(find.byType(AppIconScreen), findsOneWidget);
  });

  group('after the splash', () {
    late SecureStorageService storage;

    setUp(() async {
      storage = SecureStorageService(secureStorage: _FakeStorage());
      await storage.init();
    });

    Future<void> pumpGate(WidgetTester tester, _FakeIcons icons) async {
      final apiClient = ApiClient(storage: storage, customDio: Dio(), retries: 0);
      final push = PushNotificationService(apiClient: apiClient, storage: storage);
      final overrides = <Override>[
        secureStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(push),
        appIconServiceProvider.overrideWithValue(icons),
      ];
      await tester.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: AuthGate())));
      await tester.pumpAndSettle();
    }

    testWidgets('a fresh install is asked for its icon once, right after the splash', (tester) async {
      final icons = _FakeIcons(prompt: true);
      await pumpGate(tester, icons);

      expect(find.byType(AppIconScreen), findsOneWidget);
      expect(find.text('İkonunu seç'), findsOneWidget);
    });

    testWidgets('no question when it was answered already or the device cannot switch icons', (tester) async {
      await pumpGate(tester, _FakeIcons(prompt: false));
      expect(find.byType(AppIconScreen), findsNothing);

      await pumpGate(tester, _FakeIcons(supported: false, prompt: true));
      expect(find.byType(AppIconScreen), findsNothing);
    });
  });

  testWidgets('the loading screen shows the logo, the slogan and a progress bar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandSplash()));
    await tester.pump(const Duration(milliseconds: 800)); // the bar animates forever: no pumpAndSettle

    expect(find.byKey(const Key('brand_splash')), findsOneWidget);
    expect(find.text("Tarak'la bakım her zaman cebinde."), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
