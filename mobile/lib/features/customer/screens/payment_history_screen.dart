import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

final paymentHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/customer/payments');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return <Map<String, dynamic>>[];
});

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  String _tl(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return '₺${d.toStringAsFixed(2)}';
  }

  String _resourceLabel(String? t) {
    switch (t) {
      case 'appointment':
        return 'Randevu';
      case 'service_request':
        return 'Hemen Çağır';
      default:
        return 'İşlem';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'SETTLED':
        return AppTheme.success;
      case 'REFUNDED':
      case 'PARTIALLY_REFUNDED':
        return const Color(0xFF7C3AED);
      case 'CANCELLED':
      case 'DISPUTED':
        return AppTheme.error;
      case 'TRANSFER_PENDING':
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentHistoryProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Ödeme Geçmişi')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Ödeme geçmişi yüklenemedi.')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.slate400),
                  SizedBox(height: 12),
                  Text('Henüz bir ödeme işleminiz bulunmuyor.',
                      style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary)),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == rows.length) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Ödemeler güvenli PayTR altyapısı üzerinden işlenir. Detay için ilgili randevu sayfasını inceleyebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate400),
                  ),
                );
              }
              final r = rows[i];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_resourceLabel(r['resource_type'] as String?)} #${r['resource_id']}',
                                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (r['created_at'] != null) (r['created_at'] as String).split('T').first,
                                if (r['payment_method'] != null) (r['payment_method'] == 'ONLINE' ? 'Online' : r['payment_method'] == 'CASH' ? 'Nakit' : '${r['payment_method']}'),
                                if (r['reference'] != null) 'Ref: ${r['reference']}',
                              ].join(' • '),
                              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate400),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_tl(r['gross_amount']),
                              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('${r['status_label'] ?? ''}',
                              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w600, color: _statusColor(r['status'] as String?))),
                        ],
                      ),
                    ],
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
