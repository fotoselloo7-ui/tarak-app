import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../instant/providers/provider_instant_providers.dart';

/// The provider's payout bank account (`GET /provider/payout-account`).
/// The backend never returns a full IBAN — only the masked one.
final providerPayoutAccountProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/payout-account');
  final data = res.data is Map ? res.data['data'] : null;
  return data is Map ? Map<String, dynamic>.from(data) : null;
});

/// Wallet movements (`GET /provider/wallet/transactions`).
final providerWalletTransactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.get(
        '/provider/wallet/transactions',
        queryParameters: {'per_page': 30},
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      throw const FormatException('Cüzdan hareketleri yanıtı geçersiz.');
    }, retry: (retryCount, error) => null);

/// Marketplace payout transfers (`GET /provider/payouts`).
final providerPayoutsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/payouts');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  throw const FormatException('Hakediş transferleri yanıtı geçersiz.');
}, retry: (retryCount, error) => null);

String _money(num? value) =>
    '${(value ?? 0).toStringAsFixed(2).replaceAll('.', ',')} TL';

/// Provider earnings: balances, payout bank account and the real movement
/// history. Payouts are transferred automatically by the marketplace once a
/// service payment becomes eligible, so this screen reports that process
/// instead of offering a withdrawal the backend does not implement.
class ProviderWalletScreen extends ConsumerStatefulWidget {
  const ProviderWalletScreen({super.key});

  @override
  ConsumerState<ProviderWalletScreen> createState() =>
      _ProviderWalletScreenState();
}

class _ProviderWalletScreenState extends ConsumerState<ProviderWalletScreen> {
  bool _sendingPaymentInfo = false;

  /// "Ödeme Bilgilerimi E-postama Gönder": the bank details (IBAN, TRK reference code) are never shown inside the app;
  /// they go to the e-mail registered on the business account (server side rate limited) or are read in the signed-in
  /// tarak.app İşletme Finans Merkezi.
  Future<void> _emailPaymentInfo() async {
    if (_sendingPaymentInfo) return;
    setState(() => _sendingPaymentInfo = true);
    String message;
    var ok = false;
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.post('/provider/finance/payment-info/email');
      final text = res.data is Map ? res.data['message']?.toString() : null;
      message = text == null || text.isEmpty
          ? 'Ödeme bilgileriniz kayıtlı e-posta adresinize gönderiliyor.'
          : text;
      ok = true;
    } on AppException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Ödeme bilgileri gönderilemedi. Lütfen tekrar deneyin.';
    }
    if (!mounted) return;
    setState(() => _sendingPaymentInfo = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ok ? AppTheme.success : AppTheme.error),
    );
  }

  void _refresh() {
    ref.invalidate(providerWalletSummaryProvider);
    ref.invalidate(providerPayoutAccountProvider);
    ref.invalidate(providerWalletTransactionsProvider);
    ref.invalidate(providerPayoutsProvider);
  }

  Future<void> _editPayoutAccount(Map<String, dynamic>? account) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayoutAccountSheet(account: account),
    );
    if (saved == true) {
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hakediş hesabı kaydedildi.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(providerWalletSummaryProvider);
    final account = ref.watch(providerPayoutAccountProvider);
    final transactions = ref.watch(providerWalletTransactionsProvider);
    final payouts = ref.watch(providerPayoutsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text(
          'Cüzdan ve Hakediş',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _financeCenterCard(summary),
            const SizedBox(height: 14),
            _balancesCard(summary),
            const SizedBox(height: 14),
            _payoutAccountCard(account),
            const SizedBox(height: 14),
            _sectionTitle('Cüzdan Hareketleri'),
            const SizedBox(height: 8),
            _transactionsCard(transactions),
            const SizedBox(height: 14),
            _sectionTitle('Hakediş Transferleri'),
            const SizedBox(height: 8),
            _payoutsCard(payouts),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: AppTheme.textPrimary,
    ),
  );

  /// İşletme Finans Merkezi: gift commission right, deposited / reserved / usable amounts, reservations and the
  /// e-mail action for the bank payment details (no IBAN in the app).
  Widget _financeCenterCard(AsyncValue<ProviderWalletSummary> summary) {
    return summary.maybeWhen(
      data: (w) {
        final gift = w.gift;
        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İşletme Finans Merkezi',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Müşteri hizmet bedelini doğrudan size öder. Tarak yalnızca tamamlanan hizmetin komisyonunu bakiyenizden düşer.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                key: const Key('gift-commission-card'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gift.campaignMessage,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gift.isDepleted
                          ? 'Hediye komisyon hakkınız tamamlandı'
                          : gift.hasGift
                              ? 'Hediye komisyon hakkınız aktif'
                              : 'Hediye komisyon hakkı hesabınız onaylandıktan sonra tanımlanır',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    if (gift.hasGift) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: gift.usedShare,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFFDE68A),
                          color: const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _balanceRow('Tanımlanan', _money(gift.granted)),
                      const SizedBox(height: 6),
                      _balanceRow('Kullanılan', _money(gift.used)),
                      const SizedBox(height: 6),
                      _balanceRow('Kalan', _money(gift.remaining)),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Hediye hak çekilebilir nakit değildir; yalnızca Tarak komisyonunu karşılar.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppTheme.slate400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _balanceRow('Yüklenen komisyon bakiyesi', _money(w.depositedBalance)),
              const SizedBox(height: 8),
              _balanceRow('Rezerve komisyon', _money(w.reservedTotal)),
              const SizedBox(height: 8),
              _balanceRow('Yeni işler için kullanılabilir', _money(w.usableCommission)),
              if (w.reservations.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.slate100),
                const SizedBox(height: 10),
                const Text(
                  'Rezerve edilen işler',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final r in w.reservations) ...[
                  _balanceRow(
                    r.inDispute ? '${r.label} (uyuşmazlıkta)' : r.label,
                    _money(r.commission),
                  ),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'Hizmet tamamlanınca kesinleşir; iptalde bakiyenize geri döner.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppTheme.slate100),
              const SizedBox(height: 12),
              const Text(
                "Komisyon bakiyesi yüklemek için banka bilgileriniz güvenlik gereği uygulamada gösterilmez. "
                "tarak.app İşletme Finans Merkezi'nde giriş yaparak görebilir veya kayıtlı işletme e-postanıza gönderebilirsiniz. "
                "Ödemeniz banka kaydında doğrulandıktan sonra bakiyeniz güncellenir.",
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('email-payment-info'),
                  onPressed: _sendingPaymentInfo ? null : _emailPaymentInfo,
                  icon: _sendingPaymentInfo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        )
                      : const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text(
                    'Ödeme Bilgilerimi E-postama Gönder',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _balancesCard(AsyncValue<ProviderWalletSummary> summary) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: summary.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
        error: (_, _) => const Text(
          'Bakiye bilgileri yüklenemedi.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondary,
          ),
        ),
        data: (w) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nakit Bakiye',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _money(w.cashBalance),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.slate100),
            const SizedBox(height: 12),
            _balanceRow('Transfer Edilebilir', _money(w.withdrawable)),
            const SizedBox(height: 8),
            _balanceRow('Bekleyen Hakediş', _money(w.pendingBalance)),
            const SizedBox(height: 8),
            _balanceRow('Hediye Komisyon Hakkı (çekilemez)', _money(w.promoBalance)),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12.5,
          color: AppTheme.textSecondary,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    ],
  );

  Widget _payoutAccountCard(AsyncValue<Map<String, dynamic>?> account) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: account.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
        error: (_, _) => const Text(
          'Hakediş hesabı bilgisi yüklenemedi.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondary,
          ),
        ),
        data: (acc) {
          final hasAccount = acc != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hakediş Banka Hesabı',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editPayoutAccount(acc),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      hasAccount ? 'Güncelle' : 'Ekle',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!hasAccount)
                const Text(
                  'Henüz kayıtlı bir hakediş hesabınız yok. Ödemelerinizin aktarılabilmesi için IBAN bilgisi ekleyin.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                )
              else ...[
                _balanceRow(
                  'Hesap Sahibi',
                  acc['account_holder_name']?.toString() ?? '—',
                ),
                const SizedBox(height: 8),
                _balanceRow('IBAN', acc['iban_masked']?.toString() ?? '—'),
                const SizedBox(height: 8),
                _balanceRow(
                  'Durum',
                  acc['status']?.toString() == 'ACTIVE'
                      ? 'Aktif'
                      : (acc['status']?.toString() ?? '—'),
                ),
                const SizedBox(height: 8),
                _balanceRow(
                  'Vergi Bilgisi',
                  acc['payout_tax_status']?.toString() == 'CONFIGURED'
                      ? 'Tanımlı'
                      : 'Tanımlı değil',
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Hakedişler, hizmet ödemesi transfer edilebilir duruma geldiğinde kayıtlı IBAN’ınıza otomatik aktarılır.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  color: AppTheme.slate400,
                  height: 1.35,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _transactionsCard(
    AsyncValue<List<Map<String, dynamic>>> transactions,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: transactions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
        error: (_, _) => const Text(
          'Hareketler yüklenemedi.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondary,
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Text(
              'Henüz cüzdan hareketiniz yok.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 18, color: AppTheme.slate100),
                _transactionRow(rows[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _transactionRow(Map<String, dynamic> tx) {
    final isCredit = tx['direction']?.toString() == 'CREDIT';
    final amount = (tx['amount'] as num?) ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
          size: 16,
          color: isCredit ? AppTheme.success : AppTheme.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx['description']?.toString().trim().isNotEmpty == true
                    ? tx['description'].toString()
                    : (tx['type']?.toString() ?? 'Hareket'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (tx['created_at'] != null)
                Text(
                  tx['created_at'].toString().split('T').first,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.slate400,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${isCredit ? '+' : '-'}${_money(amount)}',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isCredit ? AppTheme.success : AppTheme.error,
          ),
        ),
      ],
    );
  }

  Widget _payoutsCard(AsyncValue<List<Map<String, dynamic>>> payouts) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: payouts.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
        error: (_, _) => const Text(
          'Hakediş transferleri yüklenemedi.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondary,
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Text(
              'Henüz bir hakediş transferiniz yok.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 18, color: AppTheme.slate100),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[i]['status_label']?.toString() ??
                                rows[i]['status']?.toString() ??
                                'Transfer',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            [
                              rows[i]['iban_masked']?.toString(),
                              rows[i]['completed_at']
                                      ?.toString()
                                      .split('T')
                                      .first ??
                                  rows[i]['created_at']
                                      ?.toString()
                                      .split('T')
                                      .first,
                            ].whereType<String>().join(' · '),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: AppTheme.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _money(rows[i]['final_submerchant_amount'] as num?),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Add/update the payout bank account. The IBAN is validated server side
/// (TR format + MOD 97-10 checksum) and never returned in full afterwards.
class _PayoutAccountSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? account;

  const _PayoutAccountSheet({required this.account});

  @override
  ConsumerState<_PayoutAccountSheet> createState() =>
      _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends ConsumerState<_PayoutAccountSheet> {
  late final TextEditingController _holder = TextEditingController(
    text: widget.account?['account_holder_name']?.toString() ?? '',
  );
  final TextEditingController _iban = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _holder.dispose();
    _iban.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final holder = _holder.text.trim();
    final iban = _iban.text.trim();
    if (holder.length < 3) {
      setState(
        () => _error = 'Hesap sahibinin adı en az 3 karakter olmalıdır.',
      );
      return;
    }
    if (iban.isEmpty) {
      setState(() => _error = 'IBAN zorunludur.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.put(
        '/provider/payout-account',
        data: {'account_holder_name': holder, 'iban': iban},
      );
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Hakediş hesabı kaydedilemedi. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.account == null
                    ? 'Hakediş Hesabı Ekle'
                    : 'Hakediş Hesabını Güncelle',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'IBAN yalnızca size ait olmalıdır. Güvenlik gereği kayıtlı IBAN hiçbir zaman tam olarak gösterilmez.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _holder,
                decoration: InputDecoration(
                  labelText: 'Hesap Sahibi Ad Soyad',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _iban,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'IBAN',
                  hintText: 'TR00 0000 0000 0000 0000 0000 00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppTheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
