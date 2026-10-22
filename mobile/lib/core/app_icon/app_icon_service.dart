import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_icon_options.dart';

/// Switching the launcher icon is not possible (web, desktop, a device that refuses) or it failed.
class AppIconException implements Exception {
  final String message;
  const AppIconException(this.message);

  @override
  String toString() => message;
}

/// "Uygulama ikonu": the same Tarak mark on one of [kAppIconOptions]' background colours.
/// Android swaps the enabled `<activity-alias>`, iOS calls `setAlternateIconName` (see `MainActivity.kt` / `AppDelegate.swift`).
abstract class AppIconService {
  Future<bool> isSupported();

  /// The id of the icon on the launcher right now.
  Future<String> current();

  Future<void> change(String id);

  /// True once, right after the splash of a fresh install: ask which icon the user wants.
  Future<bool> shouldPrompt();

  Future<void> markPrompted();
}

class MethodChannelAppIconService implements AppIconService {
  static const MethodChannel _channel = MethodChannel('app.tarak.mobile/app_icon');
  static const String _promptedKey = 'app_icon_prompted';

  static final Map<String, Object> _common = {
    'ids': [for (final o in kAppIconOptions) o.id],
    'default': kDefaultAppIconId,
  };

  @override
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      return (await _channel.invokeMethod<bool>('isSupported', _common)) ?? false;
    } on MissingPluginException {
      return false; // tests, desktop
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String> current() async {
    try {
      final id = await _channel.invokeMethod<String>('current', _common);
      if (id != null && kAppIconOptions.any((o) => o.id == id)) return id;
    } on MissingPluginException {
      // fall through
    } on PlatformException {
      // fall through
    }
    return kDefaultAppIconId;
  }

  @override
  Future<void> change(String id) async {
    if (!kAppIconOptions.any((o) => o.id == id)) throw const AppIconException('Bilinmeyen ikon.');
    try {
      await _channel.invokeMethod<bool>('change', {..._common, 'id': id});
    } on MissingPluginException {
      throw const AppIconException('Bu cihazda uygulama ikonu değiştirilemiyor.');
    } on PlatformException catch (e) {
      throw AppIconException(e.message ?? 'İkon değiştirilemedi.');
    }
  }

  @override
  Future<bool> shouldPrompt() async {
    if (!await isSupported()) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_promptedKey) ?? false);
  }

  @override
  Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptedKey, true);
  }
}

final appIconServiceProvider = Provider<AppIconService>((ref) => MethodChannelAppIconService());

/// False on web/desktop/tests: the settings entry stays hidden there.
final appIconSupportedProvider = FutureProvider<bool>((ref) => ref.watch(appIconServiceProvider).isSupported(), retry: (_, _) => null);

/// The id of the icon on the launcher now (refresh with `ref.invalidate` after a change).
final appIconCurrentProvider = FutureProvider.autoDispose<String>((ref) => ref.watch(appIconServiceProvider).current(), retry: (_, _) => null);
