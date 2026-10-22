import 'package:flutter/material.dart';

/// Tarak rating mark: the brand's navy/gold "k" comb icon, used 1:1 in place of
/// stars. The artwork is the supplied icon itself (transparent PNG in
/// `assets/brand`, with 1x/2x/3x variants) - it is never redrawn or recoloured.
/// Inactive marks are the same artwork, desaturated and faded.
const Color kTarakGold = Color(0xFFE5A32F);

const String _kMarkAsset = 'assets/brand/tarak-rating-mark.png';

const ColorFilter _kGrayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

class TarakMark extends StatelessWidget {
  final double size;

  /// Inactive / empty state of a rating scale.
  final bool muted;

  const TarakMark({super.key, this.size = 16, this.muted = false});

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      _kMarkAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    if (muted) {
      image = Opacity(opacity: 0.28, child: ColorFiltered(colorFilter: _kGrayscale, child: image));
    }
    return SizedBox(width: size, height: size, child: image);
  }
}

String _score(num value) => value.toStringAsFixed(1);

/// Marks sit a little larger than the text beside them so the artwork stays readable.
double _visualSize(double size) => (size * 1.3).roundToDouble();

/// Five marks: filled up to the rounded score, the rest muted. The numeric
/// score stays the source of truth.
class TarakRatingScale extends StatelessWidget {
  final num value;
  final double size;

  const TarakRatingScale({super.key, required this.value, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final rounded = value.round();
    return Semantics(
      label: 'Tarak Puanı ${_score(value)} / 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++) ...[
            if (i > 1) const SizedBox(width: 2),
            TarakMark(size: _visualSize(size), muted: i > rounded),
          ],
        ],
      ),
    );
  }
}

/// Mark + score, e.g. "4.9 (12)". [countSuffix] extends the count, e.g. ' değerlendirme'.
class TarakRatingLabel extends StatelessWidget {
  final num value;
  final int? count;
  final String countSuffix;
  final double size;
  final TextStyle? style;

  const TarakRatingLabel({
    super.key,
    required this.value,
    this.count,
    this.countSuffix = '',
    this.size = 14,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      label: 'Tarak Puanı ${_score(value)}${count != null ? ', $count değerlendirme' : ''}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TarakMark(size: _visualSize(size)),
          const SizedBox(width: 5),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: _score(value),
                style: base,
                children: [
                  if (count != null)
                    TextSpan(
                      text: ' ($count$countSuffix)',
                      style: base.copyWith(fontWeight: FontWeight.w400, color: base.color?.withValues(alpha: 0.6)),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline mark + score for text lines that join several facts, e.g.
/// `Text.rich(TextSpan(children: joinSpans([...])))`.
InlineSpan tarakRatingSpan(num value, {double size = 13, int? count}) {
  return TextSpan(
    children: [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TarakMark(size: _visualSize(size)),
        ),
      ),
      TextSpan(text: count != null ? '${_score(value)} ($count)' : _score(value)),
    ],
  );
}

/// Interleaves [separator] between spans (null entries are skipped).
List<InlineSpan> joinSpans(List<InlineSpan?> items, {String separator = ' • '}) {
  final spans = <InlineSpan>[];
  for (final item in items) {
    if (item == null) continue;
    if (spans.isNotEmpty) spans.add(TextSpan(text: separator));
    spans.add(item);
  }
  return spans;
}
