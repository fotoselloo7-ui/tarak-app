import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/verified_tick.dart';

/// Reviews written BY the signed-in customer (`GET /customer/reviews`).
final myGivenReviewsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/customer/reviews');
  final data = res.data is Map ? res.data['data'] : null;
  final reviews = data is Map ? data['reviews'] : null;
  if (reviews is List) {
    return reviews.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return <Map<String, dynamic>>[];
});

/// Read-only list — the backend exposes no edit/delete for a submitted review,
/// so no such action is offered here either.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  String? _resourceLabel(Map<String, dynamic> r) {
    final res = r['resource'];
    if (res is! Map) return null;
    return switch (res['type']) {
      'SCHEDULED_APPOINTMENT' => 'Randevu #${res['id']}',
      'INSTANT_REQUEST' => 'Talep #${res['id']}',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myGivenReviewsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Değerlendirmelerim',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (_, _) => const Center(
          child: Text('Değerlendirmeler yüklenemedi.',
              style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: AppTheme.slate400),
                  SizedBox(height: 12),
                  Text('Henüz bir değerlendirme yazmadınız.',
                      style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary)),
                  SizedBox(height: 4),
                  Text('Tamamlanan hizmetlerinizden sonra uzmanı değerlendirebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate400)),
                ]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = rows[i];
              final provider = r['provider'] is Map ? Map<String, dynamic>.from(r['provider'] as Map) : const {};
              final rating = (r['rating'] as num?)?.toInt() ?? 0;
              final label = _resourceLabel(r);
              final created = r['created_at']?.toString();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.radiusCard,
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProviderNameRow(name: '${provider['name'] ?? 'Hizmet Veren'}', verified: isVerifiedMap(provider), tickSize: 15,
                                  style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  provider['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi',
                                  ?label,
                                ].join(' • '),
                                style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily, fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TarakRatingScale(value: rating, size: 16),
                      ],
                    ),
                    if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(r['comment'].toString(),
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              color: AppTheme.textPrimary,
                              height: 1.4)),
                    ],
                    if (created != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        DateTime.tryParse(created) != null
                            ? '${DateTime.parse(created).day.toString().padLeft(2, '0')}.${DateTime.parse(created).month.toString().padLeft(2, '0')}.${DateTime.parse(created).year}'
                            : '',
                        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, color: AppTheme.slate400),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
