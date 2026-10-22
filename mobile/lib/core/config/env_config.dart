import 'dart:io';
import 'package:flutter/foundation.dart';

class EnvConfig {
  EnvConfig._();

  /// Default API base URL for local development:
  /// - Android Emulator: 10.0.2.2:8010/api
  /// - iOS Simulator / Desktop: 127.0.0.1:8010/api
  static String get defaultApiBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8010/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8010/api';
    }
    return 'http://127.0.0.1:8010/api';
  }

  /// Override with --dart-define=API_BASE_URL=https://...
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (kReleaseMode) {
      if (_definedBaseUrl.isEmpty) {
        throw StateError(
          'Release builds require production API URL. Provide --dart-define=API_BASE_URL=https://... at build time.',
        );
      }
      final lower = _definedBaseUrl.toLowerCase();
      if (lower.contains('10.0.2.2') || lower.contains('localhost') || lower.contains('127.0.0.1')) {
        throw StateError(
          'Release builds cannot target local loopback addresses (10.0.2.2, localhost, 127.0.0.1). Provide a production HTTPS URL.',
        );
      }
      return _definedBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }

    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }
    return defaultApiBaseUrl;
  }

  static const String appName = 'Tarak';
  static const String applicationId = 'app.tarak.mobile';

  // ── Reverb Realtime WebSocket Configuration ────────────────────────────────
  static const String _definedReverbKey = String.fromEnvironment('REVERB_APP_KEY');
  static const String _definedReverbHost = String.fromEnvironment('REVERB_HOST');
  static const int _definedReverbPort = int.fromEnvironment('REVERB_PORT', defaultValue: 0);
  static const String _definedReverbScheme = String.fromEnvironment('REVERB_SCHEME');

  static String get reverbAppKey =>
      _definedReverbKey.isNotEmpty ? _definedReverbKey : 'hhyfpgfv2dgv95yd78kz';

  static String get reverbHost {
    if (kReleaseMode) {
      if (_definedReverbHost.isEmpty) {
        throw StateError(
          'Release builds require Reverb host. Provide --dart-define=REVERB_HOST=... at build time.',
        );
      }
      return _definedReverbHost;
    }

    if (_definedReverbHost.isNotEmpty) return _definedReverbHost;
    if (kIsWeb) return '127.0.0.1';
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static int get reverbPort {
    if (_definedReverbPort > 0) return _definedReverbPort;
    return kReleaseMode ? 443 : 8081;
  }

  static String get reverbScheme {
    if (_definedReverbScheme.isNotEmpty) return _definedReverbScheme;
    return kReleaseMode ? 'wss' : 'ws';
  }

  static String get broadcastingAuthUrl => '$apiBaseUrl/broadcasting/auth';
}
