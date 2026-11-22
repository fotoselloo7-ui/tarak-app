import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Reuses the official Tarak comb mark (`assets/brand/tarak-rating-mark.png`)
/// without redrawing or modifying the asset file, rendering clean white-filled
/// circular pins and cluster pins without numbers.
class TarakMarkerRenderer {
  static const String assetPath = 'assets/brand/tarak-rating-mark.png';

  // Tarak single business pins
  static const String spriteBarber = 'tarak-pin-barber';
  static const String spriteCoiffeur = 'tarak-pin-coiffeur';
  static const String spriteNeutral = 'tarak-pin-neutral';
  static const String spriteBarberVerified = 'tarak-pin-barber-verified';
  static const String spriteCoiffeurVerified = 'tarak-pin-coiffeur-verified';
  static const String spriteNeutralVerified = 'tarak-pin-neutral-verified';
  static const String spriteBarberSelected = 'tarak-pin-barber-selected';
  static const String spriteCoiffeurSelected = 'tarak-pin-coiffeur-selected';

  // Cluster pins (white circle + Tarak mark, zero number bubbles)
  static const String spriteClusterBarber = 'tarak-cluster-barber';
  static const String spriteClusterCoiffeur = 'tarak-cluster-coiffeur';
  static const String spriteClusterMixed = 'tarak-cluster-mixed';

  static const Color barberColor = Color(0xFF2563EB);
  static const Color coiffeurColor = Color(0xFFDC2626);
  static const Color neutralColor = Color(0xFF0F172A);

  final AssetBundle _bundle;
  final Map<String, Uint8List> _cachedSprites = <String, Uint8List>{};

  TarakMarkerRenderer({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static String spriteIdFor({
    required String category, // 'barber' | 'coiffeur' | 'neutral'
    bool isVerified = false,
    bool isSelected = false,
  }) {
    switch (category) {
      case 'barber':
        if (isSelected) return spriteBarberSelected;
        return isVerified ? spriteBarberVerified : spriteBarber;
      case 'coiffeur':
        if (isSelected) return spriteCoiffeurSelected;
        return isVerified ? spriteCoiffeurVerified : spriteCoiffeur;
      default:
        return isVerified ? spriteNeutralVerified : spriteNeutral;
    }
  }

  /// Generates all Tarak and cluster sprites once and returns them keyed by ID.
  Future<Map<String, Uint8List>> buildAllSprites() async {
    if (_cachedSprites.length >= 11) {
      return Map<String, Uint8List>.unmodifiable(_cachedSprites);
    }

    final ByteData raw = await _bundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      raw.buffer.asUint8List(),
      targetWidth: 112,
      targetHeight: 112,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image combImage = frame.image;

    try {
      final variants = <String, Future<Uint8List> Function()>{
        spriteBarber: () => _renderTarakCirclePin(
              combImage,
              category: 'barber',
            ),
        spriteBarberVerified: () => _renderTarakCirclePin(
              combImage,
              category: 'barber',
            ),
        spriteBarberSelected: () => _renderTarakCirclePin(
              combImage,
              category: 'barber',
              isSelected: true,
            ),
        spriteCoiffeur: () => _renderTarakCirclePin(
              combImage,
              category: 'coiffeur',
            ),
        spriteCoiffeurVerified: () => _renderTarakCirclePin(
              combImage,
              category: 'coiffeur',
            ),
        spriteCoiffeurSelected: () => _renderTarakCirclePin(
              combImage,
              category: 'coiffeur',
              isSelected: true,
            ),
        spriteNeutral: () => _renderTarakCirclePin(
              combImage,
              category: 'neutral',
            ),
        spriteNeutralVerified: () => _renderTarakCirclePin(
              combImage,
              category: 'neutral',
            ),
        spriteClusterBarber: () => _renderTarakCirclePin(
              combImage,
              category: 'barber',
              isCluster: true,
            ),
        spriteClusterCoiffeur: () => _renderTarakCirclePin(
              combImage,
              category: 'coiffeur',
              isCluster: true,
            ),
        spriteClusterMixed: () => _renderTarakCirclePin(
              combImage,
              category: 'mixed',
              isCluster: true,
            ),
      };

      for (final entry in variants.entries) {
        if (!_cachedSprites.containsKey(entry.key)) {
          _cachedSprites[entry.key] = await entry.value();
        }
      }
    } finally {
      combImage.dispose();
    }

    return Map<String, Uint8List>.unmodifiable(_cachedSprites);
  }

  static ColorFilter _tintCombFilter(Color color) {
    final r = (color.r * 255.0).roundToDouble();
    final g = (color.g * 255.0).roundToDouble();
    final b = (color.b * 255.0).roundToDouble();
    return ColorFilter.matrix(<double>[
      0, 0, 0, 0, r, // preserve RGB of official asset silhouette uniformly
      0, 0, 0, 0, g,
      0, 0, 0, 0, b,
      0, 0, 0, 1, 0,
    ]);
  }

  Future<Uint8List> _renderTarakCirclePin(
    ui.Image combImage, {
    required String category, // 'barber' | 'coiffeur' | 'mixed' | 'neutral'
    bool isSelected = false,
    bool isCluster = false,
  }) async {
    const double size = 144;
    const Offset center = Offset(size / 2, size / 2 - 2);
    final double radius = isSelected ? 57 : (isCluster ? 57 : 52);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    final Color accentColor = switch (category) {
      'barber' => barberColor,
      'coiffeur' => coiffeurColor,
      _ => neutralColor,
    };

    // 1. Selection / cluster soft outer halo.
    if (isSelected) {
      canvas.drawCircle(
        center,
        radius + 12,
        Paint()..color = accentColor.withValues(alpha: 0.28),
      );
    } else if (isCluster) {
      canvas.drawCircle(
        center,
        radius + 10,
        Paint()
          ..color = (category == 'mixed' ? barberColor : accentColor)
              .withValues(alpha: 0.18),
      );
    }

    // 2. Soft elevation shadow underneath the white circle.
    canvas.drawCircle(
      center.translate(0, 5.0),
      radius,
      Paint()
        ..color = const Color(0x400F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
    );

    // 3. White-filled circular base.
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // 4. Bold category-colored frame contour (dual-color arc ring for mixed clusters).
    final double strokeW = isSelected ? 10.0 : (isCluster ? 9.5 : 8.5);
    if (category == 'mixed') {
      final ringRect = Rect.fromCircle(
        center: center,
        radius: radius - strokeW / 2,
      );
      canvas.drawArc(
        ringRect,
        math.pi * 0.5,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = barberColor,
      );
      canvas.drawArc(
        ringRect,
        -math.pi * 0.5,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = coiffeurColor,
      );
    } else {
      canvas.drawCircle(
        center,
        radius - strokeW / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = accentColor,
      );
    }

    // 5. Subtle cluster inner ring cue (still NO numbers).
    if (isCluster) {
      canvas.drawCircle(
        center,
        radius - 13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFE2E8F0),
      );
    }

    // 6. Centered official Tarak comb artwork colored cleanly.
    final double iconBox = isSelected ? 64 : (isCluster ? 60 : 58);
    final Rect src = Rect.fromLTWH(
      0,
      0,
      combImage.width.toDouble(),
      combImage.height.toDouble(),
    );
    final Rect dst = Rect.fromCenter(
      center: center,
      width: iconBox,
      height: iconBox,
    );
    final iconPaint = Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = _tintCombFilter(accentColor);
    canvas.drawImageRect(combImage, src, dst, iconPaint);

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(size.toInt(), size.toInt());
    try {
      final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  }
}
