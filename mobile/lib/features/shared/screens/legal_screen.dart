import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

const _legalOrder = <MapEntry<String, String>>[
  MapEntry('privacy', 'Gizlilik Politikası'),
  MapEntry('kvkk', 'KVKK Aydınlatma Metni'),
  MapEntry('terms', 'Kullanım Koşulları'),
  MapEntry('cookies', 'Çerez Politikası'),
];

/// Fetches the public site-config once and exposes the legal blob.
final legalContentProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/site-config');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is Map && data['legal'] is Map) {
    return Map<String, dynamic>.from(data['legal'] as Map);
  }
  throw const FormatException('Yasal içerik yanıtı geçersiz.');
}, retry: (retryCount, error) => null);

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Yasal & Sözleşmeler')),
      body: ref
          .watch(legalContentProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(legalContentProvider),
                child: const Text('İçerik yüklenemedi. Tekrar Dene'),
              ),
            ),
            data: (legal) =>
                _legalOrder.every(
                  (e) =>
                      legal[e.key] is! Map ||
                      (legal[e.key]['body']?.toString().trim().isEmpty ?? true),
                )
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Henüz yayımlanmış yasal metin bulunmuyor.'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _legalOrder
                        .where(
                          (e) =>
                              legal[e.key] is Map &&
                              (legal[e.key]['body']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ??
                                  false),
                        )
                        .map(
                          (e) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(
                                Icons.shield_outlined,
                                color: AppTheme.primary,
                              ),
                              title: Text(
                                e.value,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LegalDetailScreen(
                                    docKey: e.key,
                                    fallbackTitle: e.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
    );
  }
}

class LegalDetailScreen extends ConsumerWidget {
  final String docKey;
  final String fallbackTitle;
  const LegalDetailScreen({
    super.key,
    required this.docKey,
    required this.fallbackTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(legalContentProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(fallbackTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(legalContentProvider),
            child: const Text('İçerik yüklenemedi. Tekrar Dene'),
          ),
        ),
        data: (legal) {
          final doc = legal[docKey];
          final body = (doc is Map ? doc['body'] : null)?.toString() ?? '';
          final updatedAt = (doc is Map ? doc['updated_at'] : null)?.toString();
          if (body.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Yayımlanmış metin bulunamadı.'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (updatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Son güncelleme: $updatedAt',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ..._renderMarkdown(body),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _renderMarkdown(String body) {
    final widgets = <Widget>[];
    for (final raw in body.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('### ')) {
        widgets.add(_h(line.substring(4), 15));
      } else if (line.startsWith('## ')) {
        widgets.add(_h(line.substring(3), 17));
      } else if (line.startsWith('# ')) {
        widgets.add(_h(line.substring(2), 19));
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•  ',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    _stripBold(line.substring(2)),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _stripBold(line),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                height: 1.55,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _h(String t, double size) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      _stripBold(t),
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    ),
  );

  String _stripBold(String s) => s.replaceAll('**', '');
}
