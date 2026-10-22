import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/verified_tick.dart';

final favoritesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/customer/favorites');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return <Map<String, dynamic>>[];
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Favori Ustalar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Favoriler yüklenemedi.')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_border_rounded, size: 48, color: AppTheme.slate400),
                  SizedBox(height: 12),
                  Text('Henüz favori hizmet vereniniz yok.',
                      style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary)),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final count = (r['rating_count'] as num?)?.toInt() ?? 0;
              final avg = (r['rating_average'] as num?)?.toDouble() ?? 0.0;
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryLight,
                    child: Icon(Icons.person_rounded, color: AppTheme.primary),
                  ),
                  title: ProviderNameRow(
                      name: '${r['business_name'] ?? r['name'] ?? 'Hizmet Veren'}',
                      verified: isVerifiedMap(r),
                      tickSize: 16,
                      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600)),
                  subtitle: Text.rich(
                    TextSpan(
                      children: joinSpans([
                        () {
                          final place = [r['district'], r['city']].where((e) => e != null && '$e'.isNotEmpty).join(', ');
                          return place.isEmpty ? null : TextSpan(text: place);
                        }(),
                        if (count > 0) tarakRatingSpan(avg, size: 13, count: count),
                      ], separator: '  •  '),
                    ),
                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite_rounded, color: AppTheme.error),
                    onPressed: () async {
                      try {
                        await ref.read(apiClientProvider).delete('/customer/favorites/${r['provider_user_id']}');
                        ref.invalidate(favoritesProvider);
                      } catch (_) {/* ignore */}
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
