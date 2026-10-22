import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_exception.dart';

// Network failures must reach the screen's error/retry UI immediately.
// Riverpod's automatic backoff otherwise hides them behind loading for minutes.
Duration? networkRetry(int retryCount, Object error) {
  if (error is AppException) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}
