import 'package:flutter/material.dart';

/// Official Tarak brand assets bundled with the app
/// (see branding/tarak/README-ASSETS.txt).
class TarakBrand {
  const TarakBrand._();

  static const String logo = 'assets/brand/tarak-logo.png';
  static const String logoHeader = 'assets/brand/tarak-logo-header.png';
  static const String logoOnDark = 'assets/brand/tarak-logo-dark-bg.png';
  static const String brandmark = 'assets/brand/tarak-brandmark.png';

  static const String name = 'Tarak';
  static const String domain = 'tarak.app';
}

/// The app's wordmark. Rendered as a single image so the ".app" in the
/// wordmark is never cropped and the aspect ratio is never distorted.
class TarakLogo extends StatelessWidget {
  /// Visual height of the wordmark. App bars stay in the 22–30 band.
  final double height;

  /// Use the light-on-dark variant on dark surfaces.
  final bool onDarkSurface;

  /// Compact brand mark instead of the full wordmark, for tight spaces.
  final bool compact;

  const TarakLogo({
    super.key,
    this.height = 26,
    this.onDarkSurface = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final asset = compact
        ? TarakBrand.brandmark
        : (onDarkSurface ? TarakBrand.logoOnDark : TarakBrand.logoHeader);

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: TarakBrand.name,
      errorBuilder: (_, _, _) => Text(
        TarakBrand.name,
        style: TextStyle(
          fontSize: height * 0.7,
          fontWeight: FontWeight.w800,
          color: onDarkSurface ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
