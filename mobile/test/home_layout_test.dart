import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/screens/welcome_screen.dart';
import 'package:app/features/customer/providers/home_content_providers.dart';
import 'package:app/features/customer/screens/home_sections.dart';

void main() {
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('Home hierarchy and real catalog layout at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(overrides: [
        siteConfigDataProvider.overrideWith((ref) async => <String, dynamic>{}),
        homeCategoriesProvider.overrideWith((ref) async => [
          {'id': 1, 'name': 'Erkek Bakım', 'provider_type': 'barber'},
          {'id': 2, 'name': 'Kadın Kuaför', 'provider_type': 'coiffeur'},
        ]),
        homeServicesProvider.overrideWith((ref) async => [{'id': 1, 'name': 'Saç Kesimi'}, {'id': 2, 'name': 'Saç & Sakal (VIP)'}]),
        featuredProvidersProvider.overrideWith((ref) async => [{'user_id': 42, 'business_name': 'Uzman', 'review_count': 2, 'rating': null}]),
      ], child: const MaterialApp(home: WelcomeScreen())));
      await tester.pumpAndSettle();
      final headings = ['Hizmet Kategorileri', 'Mevcut Hizmetler', 'Doğrulanmış Hizmet Verenler', 'Nasıl Çalışır?', 'Doğrulanmış ve Güvenilir Hizmet Verenler', 'Randevunuzu şimdi oluşturun.', 'Tarak Cebinde!'];
      for (var i = 1; i < headings.length; i++) {
        expect(tester.getTopLeft(find.text(headings[i])).dy, greaterThan(tester.getTopLeft(find.text(headings[i - 1])).dy));
      }
      expect(find.text('Saç Kesimi'), findsOneWidget);
      expect(find.text('Uzman'), findsOneWidget);

      // Step and trust cards: one size each, no overflow at this width.
      double heightOf(String text) => tester.getSize(find.ancestor(of: find.text(text), matching: find.byType(Container)).first).height;
      final steps = ['Hizmetini Seç', 'Zamanını Belirle', 'Doğrulanmış Uzman Gelsin', 'Güvenle Hizmet Al'].map(heightOf).toSet();
      expect(steps.length, 1);
      final trust = ['Diploma Kontrolü', 'Kalfalık / Ustalık Belgesi', 'Kimlik Doğrulama', 'Uzman Ekibimiz İnceler'].map(heightOf).toSet();
      expect(trust.length, 1);
      // Closing CTA buttons share one height.
      final ctaButtons = [find.widgetWithText(FilledButton, 'Randevu Oluştur'), find.widgetWithText(OutlinedButton, 'Hizmet Veren Olun')].map((f) => tester.getSize(f.last).height).toSet();
      expect(ctaButtons.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Service API error stays inside the services section at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(overrides: [
        siteConfigDataProvider.overrideWith((ref) async => <String, dynamic>{}),
        homeCategoriesProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
        homeServicesProvider.overrideWith((ref) async => throw Exception('offline')),
        featuredProvidersProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
      ], child: const MaterialApp(home: WelcomeScreen())));
      await tester.pumpAndSettle();
      final heading = tester.getTopLeft(find.text('Mevcut Hizmetler')).dy;
      final error = tester.getTopLeft(find.text('Hizmetler yüklenemedi.')).dy;
      final next = tester.getTopLeft(find.text('Nasıl Çalışır?')).dy;
      expect(error, greaterThan(heading));
      expect(next, greaterThan(error));
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Doğrulanmış ve Güvenilir Hizmet Verenler'), findsOneWidget);
      expect(find.text('Randevunuzu şimdi oluşturun.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Catalog service card invokes the existing selection action once', (tester) async {
    var selections = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeServicesSection(services: const [{'id': 1, 'name': 'Saç Kesimi'}], onSelect: () => selections++))));
    await tester.tap(find.text('Saç Kesimi'));
    expect(selections, 1);
    expect(tester.takeException(), isNull);
  });
}
