import 'package:flutter/material.dart';

import '../../../core/app_icon/app_icon_options.dart';

/// What the launcher shows for [option]: the Tarak mark on its gradient background, same proportions as the real icon.
class AppIconPreview extends StatelessWidget {
  final AppIconOption option;
  final double size;

  const AppIconPreview({super.key, required this.option, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final mark = size * 0.65; // the bundled mark has a little padding: ~62% of the icon, as in the launcher icon
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [option.top, option.bottom]),
        boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Image.asset(
        'assets/brand/tarak-rating-mark.png',
        width: mark,
        height: mark,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
