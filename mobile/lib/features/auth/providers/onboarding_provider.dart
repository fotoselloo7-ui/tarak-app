import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/secure_storage_service.dart';
import 'auth_provider.dart';

final onboardingNotifierProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<bool> {
  SecureStorageService get _storage => ref.read(secureStorageProvider);

  @override
  Future<bool> build() async {
    return await _storage.hasCompletedOnboarding();
  }

  Future<void> completeOnboarding() async {
    await _storage.setOnboardingCompleted();
    state = const AsyncData(true);
  }

  Future<void> resetOnboarding() async {
    await _storage.resetOnboarding();
    state = const AsyncData(false);
  }
}
