import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/shared/widgets/provider_gallery.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

const _urls = [
  'https://example.test/a.jpg',
  'https://example.test/b.jpg',
  'https://example.test/c.jpg',
];

void main() {
  group('providerGalleryUrls', () {
    test('keeps only http(s) strings and ignores non-lists', () {
      expect(providerGalleryUrls(['https://x.test/1.jpg', '', 'file.jpg', null, 'http://x.test/2.jpg']),
          ['https://x.test/1.jpg', 'http://x.test/2.jpg']);
      expect(providerGalleryUrls(null), isEmpty);
      expect(providerGalleryUrls('https://x.test/1.jpg'), isEmpty);
      expect(providerGalleryUrls(<dynamic>[]), isEmpty);
    });
  });

  group('ProviderGallerySection', () {
    testWidgets('renders nothing when the provider has no work photos', (tester) async {
      await tester.pumpWidget(_host(const ProviderGallerySection(urls: [])));

      expect(find.text('Çalışmalarım'), findsNothing);
      expect(find.byKey(const Key('provider_gallery_list')), findsNothing);
    });

    testWidgets('shows the title, photo count and one thumbnail per photo', (tester) async {
      await tester.pumpWidget(_host(const ProviderGallerySection(urls: _urls)));
      await tester.pump();

      expect(find.text('Çalışmalarım'), findsOneWidget);
      expect(find.text('3 fotoğraf'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < _urls.length; i++) {
        expect(find.byKey(Key('gallery_thumb_$i')), findsOneWidget);
      }
    });

    testWidgets('tapping a thumbnail opens the viewer at that photo and swiping moves on', (tester) async {
      await tester.pumpWidget(_host(const ProviderGallerySection(urls: _urls)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('gallery_thumb_1')));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderGalleryViewer), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.fling(find.byKey(const Key('gallery_viewer_pages')), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProviderGalleryViewer), findsNothing);
    });
  });

  group('ProviderCover', () {
    testWidgets('falls back to a neutral placeholder when the image cannot load', (tester) async {
      await tester.pumpWidget(_host(const ProviderCover(url: 'https://example.test/cover.jpg')));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });
}
