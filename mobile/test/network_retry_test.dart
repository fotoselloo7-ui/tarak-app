import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/network/network_retry.dart';

void main() {
  test('offline provider exposes error without automatic retry; invalidation recovers', () async {
    var online = false;
    var attempts = 0;
    final provider = FutureProvider<String>((ref) async {
      attempts++;
      if (!online) throw const AppException(message: 'Çevrimdışı');
      return 'canonical response';
    });
    final container = ProviderContainer(retry: networkRetry);
    addTearDown(container.dispose);
    await expectLater(container.read(provider.future), throwsA(isA<AppException>()));
    expect(container.read(provider).hasError, isTrue);
    expect(attempts, 1);
    online = true;
    container.invalidate(provider);
    expect(await container.read(provider.future), 'canonical response');
    expect(attempts, 2);
  });
}
