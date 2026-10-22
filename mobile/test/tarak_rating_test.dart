import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/widgets/tarak_rating.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('TarakMark', () {
    test('the supplied artwork is bundled at 1x / 2x / 3x', () {
      for (final path in [
        'assets/brand/tarak-rating-mark.png',
        'assets/brand/2.0x/tarak-rating-mark.png',
        'assets/brand/3.0x/tarak-rating-mark.png',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    testWidgets('renders the brand image at the requested size', (tester) async {
      await tester.pumpWidget(_host(const TarakMark(size: 24)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TarakMark)), const Size(24, 24));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, 'assets/brand/tarak-rating-mark.png');
    });

    testWidgets('muted marks are the same artwork, desaturated and faded', (tester) async {
      await tester.pumpWidget(_host(const TarakMark(size: 24, muted: true)));

      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byType(Opacity), findsWidgets);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('active marks are not filtered', (tester) async {
      await tester.pumpWidget(_host(const TarakMark(size: 24)));

      expect(find.byType(ColorFiltered), findsNothing);
    });
  });

  group('TarakRatingScale', () {
    testWidgets('shows five marks, active up to the rounded score', (tester) async {
      await tester.pumpWidget(_host(const TarakRatingScale(value: 3.6)));

      final marks = tester.widgetList<TarakMark>(find.byType(TarakMark)).toList();
      expect(marks.length, 5);
      expect(marks.map((m) => m.muted).toList(), [false, false, false, false, true]);
    });

    testWidgets('score 0 mutes every mark and exposes the score to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const TarakRatingScale(value: 0)));

      expect(tester.widgetList<TarakMark>(find.byType(TarakMark)).every((m) => m.muted), isTrue);
      expect(find.bySemanticsLabel('Tarak Puanı 0.0 / 5'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('marks are drawn larger than the nominal size so the artwork stays readable', (tester) async {
      await tester.pumpWidget(_host(const TarakRatingScale(value: 5, size: 14)));

      expect(tester.getSize(find.byType(TarakMark).first).height, greaterThan(14));
    });
  });

  group('TarakRatingLabel', () {
    testWidgets('renders mark, score and count', (tester) async {
      await tester.pumpWidget(_host(const TarakRatingLabel(value: 4.9, count: 12)));

      expect(find.byType(TarakMark), findsOneWidget);
      expect(find.textContaining('4.9'), findsOneWidget);
      expect(find.textContaining('(12)'), findsOneWidget);
    });

    testWidgets('count suffix is appended inside the brackets', (tester) async {
      await tester.pumpWidget(_host(const TarakRatingLabel(value: 5, count: 2, countSuffix: ' değerlendirme')));

      expect(find.textContaining('5.0'), findsOneWidget);
      expect(find.textContaining('(2 değerlendirme)'), findsOneWidget);
    });

    testWidgets('announces the Tarak score for accessibility', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const TarakRatingLabel(value: 4.5, count: 8)));

      expect(find.bySemanticsLabel('Tarak Puanı 4.5, 8 değerlendirme'), findsOneWidget);
      handle.dispose();
    });
  });

  group('inline spans', () {
    test('joinSpans skips null entries and interleaves the separator', () {
      final spans = joinSpans([const TextSpan(text: 'Şişli'), null, const TextSpan(text: '20 dk')]);
      expect(spans.length, 3);
      expect((spans[1] as TextSpan).text, ' • ');
    });

    testWidgets('tarakRatingSpan embeds the mark next to the score', (tester) async {
      await tester.pumpWidget(_host(
        Text.rich(TextSpan(children: joinSpans([const TextSpan(text: 'Kadıköy'), tarakRatingSpan(4.5, count: 3)]))),
      ));

      expect(find.byType(TarakMark), findsOneWidget);
      expect(find.textContaining('4.5 (3)', findRichText: true), findsOneWidget);
    });
  });
}
