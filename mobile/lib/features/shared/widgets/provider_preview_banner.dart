import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// "Is my ad running?": status of the provider's own ads (both placements) and how the list ad is shared.
final providerAdVisibilityProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/featured/visibility');
  final body = res.data is Map ? res.data as Map : const {};
  final data = body['data'];
  if (data is! Map) throw const FormatException('Reklam durumu geçersiz.');
  return Map<String, dynamic>.from(data);
}, retry: (retryCount, error) => null);

/// Whether the provider's own list ad is running right now (and the homepage showcase), in one line.
class ProviderAdStatusLine extends ConsumerWidget {
  /// Longer wording for the preview banner (it explains the own ad sits first in that list).
  final bool detailed;
  const ProviderAdStatusLine({super.key, this.detailed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(providerAdVisibilityProvider);
    final listing = visibility.value?['listing'] is Map ? Map<String, dynamic>.from(visibility.value!['listing'] as Map) : null;
    final running = listing?['running'] == true;
    final home = visibility.value?['home'] is Map ? Map<String, dynamic>.from(visibility.value!['home'] as Map) : null;
    final slots = (listing?['slots'] as num?)?.toInt() ?? 0;
    final rotation = (listing?['rotation_seconds'] as num?)?.toInt() ?? 0;
    final showcase = home?['is_featured'] == true;

    if (visibility.hasError) {
      return const Text('Reklam durumun şu an yüklenemedi.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate500));
    }
    if (listing == null) {
      return const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary));
    }
    final text = running
        ? 'Liste reklamın yayında. Aynı anda en fazla $slots hizmet veren "Önerilen" olarak yer alır (her $rotation saniyede bir değişir)'
            '${detailed ? '; bu önizlemede reklamın ilk sırada gösterilir' : ''}.${showcase ? ' Ana sayfa vitrininde de yer alıyorsun.' : ''}'
        : 'Liste reklamın şu an yayında değil.${showcase ? ' Ana sayfa vitrininde yer alıyorsun.' : ''}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(running ? Icons.check_circle_rounded : Icons.info_rounded, size: 16, color: running ? AppTheme.success : AppTheme.warning),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            key: const Key('provider_preview_status'),
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: running ? AppTheme.success : AppTheme.slate700),
          ),
        ),
      ],
    );
  }
}

/// Shown on top of a customer list a provider opens on its own: it says whose eyes these are, whether the
/// provider's own list ad is running, and brings them back to the panel.
class ProviderPreviewBanner extends StatelessWidget {
  const ProviderPreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('provider_preview_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_rounded, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Flexible(child: Text('Müşteri görünümündesin', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Bu listeyi bir müşterinin gördüğü gibi görüyorsun. Hiçbir işlem yapamazsın; reklamının burada nasıl göründüğünü kontrol edebilirsin.',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, height: 1.35, color: AppTheme.slate600),
          ),
          const SizedBox(height: 8),
          const ProviderAdStatusLine(detailed: true),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('provider_preview_back'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Hizmet Veren Paneline Dön'),
            ),
          ),
        ],
      ),
    );
  }
}
