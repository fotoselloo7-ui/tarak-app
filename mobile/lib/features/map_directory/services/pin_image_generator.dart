import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Renders teardrop PNG map pin sprites with business logo/photo (or initials
/// fallback) plus an optional verified dot badge for MapLibre symbol layers.
class PinImageGenerator {
  static const int maxCachedImages = 120;

  final Dio _dio;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  PinImageGenerator({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(milliseconds: 2500),
                receiveTimeout: const Duration(milliseconds: 2500),
                responseType: ResponseType.bytes,
              ),
            );

  static String spriteIdForBusiness({
    required String id,
    required bool isVerified,
    required bool acceptsBooking,
    String? imageUrl,
  }) {
    final imgHash = imageUrl == null ? 'none' : imageUrl.hashCode.toRadixString(36);
    return 'tarak-pin-$id-${isVerified ? 'v' : 'u'}-${acceptsBooking ? 'b' : 'd'}-$imgHash';
  }

  Future<Uint8List> buildPinBytes({
    required String businessName,
    String? imageUrl,
    bool isVerified = false,
    bool acceptsBooking = false,
    bool isCoiffeur = false,
  }) async {
    final cacheKey =
        '$businessName|${imageUrl ?? ''}|$isVerified|$acceptsBooking|$isCoiffeur';
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return cached;
    }

    ui.Image? avatarImage;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      avatarImage = await _fetchImage(imageUrl.trim());
    }

    final bytes = await _renderTeardropPin(
      businessName: businessName,
      avatar: avatarImage,
      isVerified: isVerified,
      acceptsBooking: acceptsBooking,
      isCoiffeur: isCoiffeur,
    );

    if (_cache.length >= maxCachedImages) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = bytes;
    return bytes;
  }

  Future<Uint8List> buildFallbackPinBytes({
    bool isVerified = false,
    bool acceptsBooking = false,
  }) {
    return _renderTeardropPin(
      businessName: 'T',
      avatar: null,
      isVerified: isVerified,
      acceptsBooking: acceptsBooking,
      isCoiffeur: false,
    );
  }

  Future<ui.Image?> _fetchImage(String url) async {
    try {
      final response = await _dio.get<List<int>>(url);
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(data),
        targetWidth: 80,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _renderTeardropPin({
    required String businessName,
    required ui.Image? avatar,
    required bool isVerified,
    required bool acceptsBooking,
    required bool isCoiffeur,
  }) async {
    const double width = 84;
    const double height = 98;
    const Offset center = Offset(42, 36);
    const double outerRadius = 31;
    const double innerRadius = 24;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // Teardrop silhouette path
    final Path pinPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
      ..moveTo(center.dx - 17, center.dy + 22)
      ..quadraticBezierTo(center.dx - 4, height - 12, center.dx, height - 3)
      ..quadraticBezierTo(center.dx + 4, height - 12, center.dx + 17, center.dy + 22)
      ..close();

    // Subtle ground shadow
    canvas.drawPath(
      pinPath.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x380F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Outer teardrop fill (dark navy or deep slate)
    final Color bodyColor = acceptsBooking
        ? const Color(0xFF0F172A)
        : const Color(0xFF334155);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = bodyColor
        ..style = PaintingStyle.fill,
    );

    // Crisp outer rim
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = acceptsBooking ? const Color(0xFFFF5722) : Colors.white
        ..strokeWidth = acceptsBooking ? 2.5 : 2.0
        ..style = PaintingStyle.stroke,
    );

    // Inner circular avatar slot
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    canvas.drawCircle(
      center,
      innerRadius + 1.5,
      Paint()..color = Colors.white,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(innerRect));

    if (avatar != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        avatar.width.toDouble(),
        avatar.height.toDouble(),
      );
      canvas.drawImageRect(
        avatar,
        src,
        innerRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..color = isCoiffeur
              ? const Color(0xFFFFF1F2)
              : const Color(0xFFFFF7ED),
      );
      final letter = businessName.trim().isEmpty
          ? 'T'
          : businessName.trim().characters.first.toUpperCase();
      final tp = TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isCoiffeur
                ? const Color(0xFFBE123C)
                : const Color(0xFFE64A19),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
    canvas.restore();

    // Small verified dot strictly when KYC-verified
    if (isVerified) {
      const badgeCenter = Offset(66, 14);
      canvas.drawCircle(badgeCenter, 9, Paint()..color = Colors.white);
      canvas.drawCircle(
        badgeCenter,
        7,
        Paint()..color = const Color(0xFF2563EB),
      );
      final checkPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final checkPath = Path()
        ..moveTo(badgeCenter.dx - 3.2, badgeCenter.dy + 0.2)
        ..lineTo(badgeCenter.dx - 0.8, badgeCenter.dy + 2.8)
        ..lineTo(badgeCenter.dx + 3.6, badgeCenter.dy - 2.6);
      canvas.drawPath(checkPath, checkPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
