import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Reasons accepted by `POST /api/reports` (same ids as the backend).
const reportReasons = <MapEntry<String, String>>[
  MapEntry('HARASSMENT', 'Taciz veya hakaret'),
  MapEntry('INAPPROPRIATE', 'Uygunsuz içerik'),
  MapEntry('SPAM', 'Spam veya reklam'),
  MapEntry('FRAUD', 'Dolandırıcılık şüphesi'),
  MapEntry('OTHER', 'Diğer'),
];

/// Report user-generated content and block/unblock users.
class ModerationRepository {
  final ApiClient _api;

  const ModerationRepository(this._api);

  /// POST /api/reports — returns the server's confirmation message.
  Future<String> report({
    required String contentType,
    required int contentId,
    required String reason,
    String? details,
  }) async {
    final resp = await _api.post(
      '/reports',
      data: {
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
    final data = resp.data;
    final message = data is Map ? data['message']?.toString() : null;
    return message ?? 'Bildiriminiz alındı. Ekibimiz inceleyecek.';
  }

  /// POST /api/blocks
  Future<void> blockUser(int userId) async {
    await _api.post('/blocks', data: {'user_id': userId});
  }

  /// DELETE /api/blocks/{user}
  Future<void> unblockUser(int userId) async {
    await _api.delete('/blocks/$userId');
  }
}

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(apiClientProvider));
});
