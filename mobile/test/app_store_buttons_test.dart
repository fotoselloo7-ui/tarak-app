import 'package:app/core/widgets/app_store_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 360.0, 430.0]) {
    testWidgets('Store badges stay side by side within $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Padding(
        padding: EdgeInsets.all(20), child: AppDownloadSection(siteConfig: {}),
      ))));
      final apple = find.byKey(const ValueKey('app-store-badge'));
      final google = find.byKey(const ValueKey('play-store-badge'));
      final a = tester.getRect(apple), g = tester.getRect(google);
      expect(a.top, g.top);
      expect(a.right, lessThan(g.left));
      expect(g.right, lessThanOrEqualTo(width - 40));
      expect(a.height, greaterThanOrEqualTo(44));
      expect(tester.widget<ElevatedButton>(apple).onPressed, isNull);
      expect(tester.widget<ElevatedButton>(google).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Each badge opens its own configured URL; launch failure is recoverable', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final urls = <String>[];
    var succeeds = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'launch');
      urls.add(call.arguments['url'] as String);
      return succeeds;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    const apple = 'https://apps.apple.com/tr/app/test/id123';
    const google = 'https://play.google.com/store/apps/details?id=test';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppDownloadSection(siteConfig: {
      'home': {'app_download': {'title': 'Tarak'}},
      'config': {'app_store_url': apple, 'play_store_url': google},
    }))));
    await tester.tap(find.byKey(const ValueKey('app-store-badge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-store-badge')));
    await tester.pumpAndSettle();
    expect(urls, [apple, google]);
    succeeds = false;
    await tester.tap(find.byKey(const ValueKey('play-store-badge')));
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı açılamadı. Tekrar deneyin.'), findsOneWidget);
  });

  testWidgets('Invalid or non HTTPS store links stay disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppStoreButtons(
      appStoreUrl: 'http://example.com', playStoreUrl: 'invalid',
    ))));
    for (final key in ['app-store-badge', 'play-store-badge']) {
      expect(tester.widget<ElevatedButton>(find.byKey(ValueKey(key))).onPressed, isNull);
    }
  });
}
