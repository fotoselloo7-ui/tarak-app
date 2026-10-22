import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  static const String _authTokenKey = 'sanctum_auth_token';
  static const String _installationIdKey = 'app_installation_id';

  SecureStorageService({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _prefs = prefs;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Retrieve stored Sanctum Bearer token.
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _authTokenKey);
    } catch (_) {
      return null;
    }
  }

  /// Store Sanctum Bearer token securely.
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _authTokenKey, value: token);
  }

  /// Clear stored Sanctum token upon logout or session invalidation.
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
    } catch (_) {}
  }

  static const String _onboardingCompletedKey = 'has_completed_onboarding';

  /// Check whether user has already completed or dismissed the onboarding flow.
  Future<bool> hasCompletedOnboarding() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getBool(_onboardingCompletedKey) ?? false;
  }

  /// Mark onboarding flow as completed.
  Future<void> setOnboardingCompleted() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_onboardingCompletedKey, true);
  }

  /// Reset onboarding state (useful for testing or profile settings).
  Future<void> resetOnboarding() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(_onboardingCompletedKey);
  }

  /// Retrieve or generate a stable installation ID for mobile device registration.
  Future<String> getInstallationId() async {
    _prefs ??= await SharedPreferences.getInstance();
    var id = _prefs?.getString(_installationIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _prefs?.setString(_installationIdKey, id);
    }
    return id;
  }
}
