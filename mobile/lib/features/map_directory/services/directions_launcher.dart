import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

class DirectionsLauncher {
  const DirectionsLauncher._();

  static Future<bool> _defaultLaunch(Uri uri) async {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Launches turn-by-turn directions to a fixed public business venue.
  /// Never call this for `work_mode == 'mobile'` providers.
  static Future<bool> openDirections({
    required double latitude,
    required double longitude,
    required String label,
    ExternalUriLauncher? launcher,
  }) async {
    final run = launcher ?? _defaultLaunch;
    final candidates = buildCandidateUris(
      latitude: latitude,
      longitude: longitude,
      label: label,
      isAndroid: !kIsWeb && Platform.isAndroid,
      isIOS: !kIsWeb && Platform.isIOS,
    );

    for (final uri in candidates) {
      try {
        if (await run(uri)) {
          return true;
        }
      } catch (_) {
        // Fall through to next fallback map URL.
      }
    }
    return false;
  }

  static List<Uri> buildCandidateUris({
    required double latitude,
    required double longitude,
    required String label,
    required bool isAndroid,
    required bool isIOS,
  }) {
    final encodedLabel = Uri.encodeComponent(label);
    final coords = '$latitude,$longitude';
    final googleWeb = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$coords',
    );
    final osmWeb = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=17/$latitude/$longitude',
    );

    if (isAndroid) {
      return [
        Uri.parse('geo:$coords?q=$coords($encodedLabel)'),
        googleWeb,
        osmWeb,
      ];
    }
    if (isIOS) {
      return [
        Uri.parse('https://maps.apple.com/?daddr=$coords&q=$encodedLabel'),
        googleWeb,
        osmWeb,
      ];
    }
    return [googleWeb, osmWeb];
  }
}
