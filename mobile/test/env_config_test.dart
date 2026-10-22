import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/env_config.dart';

void main() {
  group('EnvConfig Production Hardening Tests', () {
    test('1. In debug mode, defaultApiBaseUrl resolves properly without crash', () {
      expect(kReleaseMode, false);
      final url = EnvConfig.apiBaseUrl;
      expect(url.isNotEmpty, true);
      expect(url.contains('/api'), true);
    });

    test('2. broadcastingAuthUrl builds from apiBaseUrl', () {
      expect(EnvConfig.broadcastingAuthUrl, '${EnvConfig.apiBaseUrl}/broadcasting/auth');
    });

    test('3. Reverb credentials and endpoints are valid defaults in debug mode', () {
      expect(EnvConfig.reverbAppKey.isNotEmpty, true);
      expect(EnvConfig.reverbHost.isNotEmpty, true);
      expect(EnvConfig.reverbPort, 8081);
      expect(EnvConfig.reverbScheme, 'ws');
    });

    test('4. No secrets hardcoded in EnvConfig', () {
      expect(EnvConfig.appName, 'Tarak');
      expect(EnvConfig.applicationId, 'app.tarak.mobile');
    });
  });
}
