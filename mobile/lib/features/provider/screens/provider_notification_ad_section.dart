import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/verified_tick.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import 'provider_featured_card_payment_screen.dart';

/// `GET /provider/notification-ads`: audiences with their admin-set prices, limits, the running campaign discount,
/// wallet / card availability and the last sends.
final providerNotificationAdProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/notification-ads');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const FormatException('Bildirim reklamı bilgileri yanıtı geçersiz.');
}, retry: (retryCount, error) => null);

String _money(num? value) {
  final v = (value ?? 0).toDouble();
  final text = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');
  final parts = text.split(',');
  final whole = parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '₺${parts.length > 1 ? '$whole,${parts[1]}' : whole}';
}

String _count(num value) => value.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  return '${d.day} ${months[d.month - 1]}';
}

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? v) => (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

const _audienceIcons = {'service_area': Icons.radar_rounded, 'location': Icons.place_outlined, 'all': Icons.groups_outlined};

/// "Bildirim Reklamı": write the notification (title, description, discount %), pick who gets it (service area / a
/// province / everyone) and pay from the wallet or by card. The discount is applied to the provider's prices.
class ProviderNotificationAdSection extends ConsumerStatefulWidget {
  /// Called after something changed (a send, the discount ended) so the screen around can refresh.
  final VoidCallback? onChanged;
  const ProviderNotificationAdSection({super.key, this.onChanged});

  @override
  ConsumerState<ProviderNotificationAdSection> createState() => _ProviderNotificationAdSectionState();
}

class _ProviderNotificationAdSectionState extends ConsumerState<ProviderNotificationAdSection> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _percent;
  int? _days;
  String _audience = 'service_area';
  String _province = '';
  String _district = '';
  List<Map<String, dynamic>> _districts = const [];
  final Map<String, int> _estimates = {};
  Timer? _estimateTimer;
  bool _busy = false;
  Map<String, String> _fieldErrors = const {};
  bool _estimating = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _estimateTimer?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _scheduleEstimates() {
    _estimateTimer?.cancel();
    _estimateTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted || _estimating) return;
      _estimating = true;
      final ApiClient api = ref.read(apiClientProvider);
      Future<void> ask(String audience) async {
        try {
          final res = await api.post('/provider/notification-ads/estimate', data: {
            'audience': audience,
            'province': audience == 'location' ? _province : null,
            'district': audience == 'location' && _district.isNotEmpty ? _district : null,
          });
          final recipients = _map(res.data is Map ? res.data['data'] : null)['recipients'];
          if (mounted && recipients is num) setState(() => _estimates[audience] = recipients.toInt());
        } catch (_) {
          // The estimate is a hint; the send itself is validated on the server.
        }
      }

      await ask('service_area');
      await ask('all');
      if (_province.isNotEmpty) await ask('location');
      _estimating = false;
    });
  }

  Future<void> _loadDistricts(String province) async {
    if (province.isEmpty) {
      setState(() => _districts = const []);
      return;
    }
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.get('/provider/notification-ads/districts', queryParameters: {'province': province});
      if (mounted && _province == province) setState(() => _districts = _list(res.data is Map ? res.data['data'] : null));
    } catch (_) {
      if (mounted) setState(() => _districts = const []);
    }
  }

  Map<String, dynamic> _payload() => {
        'audience': _audience,
        'province': _audience == 'location' ? _province : null,
        'district': _audience == 'location' && _district.isNotEmpty ? _district : null,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'discount_percent': _percent,
        'discount_days': _days,
      };

  Future<void> _send(Map<String, dynamic> data, {required bool card}) async {
    final audiences = _list(data['audiences']);
    final chosen = audiences.firstWhere((a) => a['audience'] == _audience, orElse: () => audiences.first);
    final price = (chosen['price'] as num?) ?? 0;
    final reach = _estimates[_audience];
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Bildirimi gönder',
      message: '${chosen['name']}${reach != null ? ' (≈ ${_count(reach)} kişi)' : ''} hedefine %$_percent indirim bildirimi gönderilecek; indirim $_days gün boyunca tüm fiyatlarına uygulanır. '
          '${card ? 'Kartından ${_money(price)} çekilecek; bildirim ödeme onaylanınca gider.' : 'Cüzdanından ${_money(price)} düşülecek ve bildirim hemen gider.'} Gönderilen bildirim geri alınamaz.',
      confirmText: card ? 'Ödemeye Geç' : 'Onayla ve Gönder',
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _fieldErrors = const {};
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.post('/provider/notification-ads', data: {..._payload(), 'payment_method': card ? 'card' : 'wallet'});
      final body = _map(res.data is Map ? res.data['data'] : null);
      if (card) {
        final ad = _map(body['ad']);
        final paid = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => ProviderFeaturedCardPaymentScreen(
              orderId: (ad['id'] as num).toInt(),
              iframeUrl: '${body['iframe_url']}',
              amount: (ad['amount'] as num?)?.toDouble() ?? price.toDouble(),
              packageName: '${ad['audience_name'] ?? chosen['name']}',
              notification: true,
            ),
          ),
        );
        ref.invalidate(providerNotificationAdProvider);
        widget.onChanged?.call();
        if (paid == true) {
          _clearForm();
          messenger.showSnackBar(const SnackBar(content: Text('Ödeme alındı; bildirimin gönderiliyor, indirim başladı.')));
        }
      } else {
        final sent = _map(body['sent']);
        ref.invalidate(providerNotificationAdProvider);
        widget.onChanged?.call();
        _clearForm();
        messenger.showSnackBar(SnackBar(content: Text('Bildirimin ${_count((sent['recipients_count'] as num?) ?? 0)} kullanıcıya gönderildi; %${sent['discount_percent']} indirim ${sent['discount_days']} gün boyunca fiyatlarına uygulanır.')));
      }
    } on AppException catch (e) {
      final errors = <String, String>{};
      e.validationErrors?.forEach((key, value) {
        if (value.isNotEmpty) errors[key] = value.first;
      });
      if (mounted) setState(() => _fieldErrors = errors);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Bildirim gönderilemedi.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _title.clear();
    _body.clear();
  }

  Future<void> _endDiscount() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'İndirimi bitir',
      message: 'Aktif indirim şimdi sonlandırılsın mı? Fiyatların hemen eski haline döner (gönderilmiş bildirim geri alınmaz).',
      confirmText: 'İndirimi bitir',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.delete('/provider/notification-ads/discount');
      ref.invalidate(providerNotificationAdProvider);
      widget.onChanged?.call();
      messenger.showSnackBar(const SnackBar(content: Text('İndirim sonlandırıldı.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('İndirim sonlandırılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(providerNotificationAdProvider);
    return async.when(
      loading: () => const LoadingState(height: 120),
      error: (e, _) => ErrorState(message: 'Bildirim reklamı bilgileri yüklenemedi.', onRetry: () => ref.invalidate(providerNotificationAdProvider)),
      data: _form,
    );
  }

  Widget _form(Map<String, dynamic> data) {
    if (data['is_enabled'] == false) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Bildirim reklamı şu an satışa kapalı.', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.slate400))),
      );
    }
    final limits = _map(data['limits']);
    final minP = (limits['min_discount_percent'] as num?)?.toInt() ?? 5;
    final maxP = (limits['max_discount_percent'] as num?)?.toInt() ?? 50;
    final maxDays = (limits['max_discount_days'] as num?)?.toInt() ?? 14;
    final titleMax = (limits['title_max'] as num?)?.toInt() ?? 50;
    final bodyMax = (limits['body_max'] as num?)?.toInt() ?? 120;
    final percent = (_percent ?? 20).clamp(minP, maxP);
    final days = (_days ?? 7).clamp(1, maxDays);
    _percent = percent;
    _days = days;

    final audiences = _list(data['audiences']);
    final chosen = audiences.firstWhere((a) => a['audience'] == _audience, orElse: () => audiences.first);
    final price = (chosen['price'] as num?) ?? 0;
    final wallet = _map(data['wallet']);
    final balance = (wallet['usable_cash_balance'] as num?)?.toDouble() ?? 0;
    final frozen = wallet['is_frozen'] == true;
    final payment = _map(data['payment']);
    final cardEnabled = payment['card_enabled'] == true;
    final affordable = !frozen && balance + 0.001 >= price;
    final sendsLeft = (data['sends_left_today'] as num?)?.toInt() ?? 0;
    final reach = _estimates[_audience];
    final ready = _title.text.trim().length >= 3 && _body.text.trim().length >= 5 && (_audience != 'location' || _province.isNotEmpty) && sendsLeft > 0;
    final active = data['active_discount'] is Map ? _map(data['active_discount']) : null;
    final provinces = _list(data['provinces']);
    final history = _list(data['history']);

    final percentChoices = {minP, 10, 15, 20, 25, 30, 40, maxP}.where((p) => p >= minP && p <= maxP).toList()..sort();
    final dayChoices = [1, 3, 7, 14, 30].where((d) => d <= maxDays).toList();
    if (!dayChoices.contains(maxDays)) dayChoices.add(maxDays);

    if (_estimates.isEmpty && !_estimating) _scheduleEstimates();

    String? err(String key) => _fieldErrors[key];

    return Column(
      key: const Key('notification_ad_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active != null) ...[
          Container(
            key: const Key('notification_ad_active_discount'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('%${active['percent']} indirim yayında', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('${active['days_left']} gün kaldı (${_day(active['ends_at']?.toString())} tarihine kadar). Yeni bir bildirim reklamı bunun yerine geçer.', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate600, height: 1.35)),
                const SizedBox(height: 6),
                OutlinedButton(key: const Key('notification_ad_end_discount'), onPressed: _endDiscount, child: const Text('İndirimi bitir')),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _label('Başlık'),
        TextField(
          key: const Key('notification_ad_title'),
          controller: _title,
          maxLength: titleMax,
          decoration: InputDecoration(hintText: 'Örn. Hafta sonu fırsatı', errorText: err('title'), counterText: '${_title.text.length}/$titleMax'),
        ),
        const SizedBox(height: 8),
        _label('Açıklama'),
        TextField(
          key: const Key('notification_ad_body'),
          controller: _body,
          maxLength: bodyMax,
          maxLines: 3,
          decoration: InputDecoration(hintText: 'Örn. Saç kesimi ve sakal tıraşında geçerli.', errorText: err('body'), counterText: '${_body.text.length}/$bodyMax'),
        ),
        const SizedBox(height: 12),
        _label('İndirim oranı'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in percentChoices) _Choice(key: Key('notification_ad_percent_$p'), label: '%$p', selected: percent == p, onTap: () => setState(() => _percent = p)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(err('discount_percent') ?? '%$minP – %$maxP arası. Bu oran tüm hizmet ve paket fiyatlarına uygulanır.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: err('discount_percent') != null ? AppTheme.error : AppTheme.slate500)),
        ),
        const SizedBox(height: 12),
        _label('İndirim süresi'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in dayChoices) _Choice(key: Key('notification_ad_days_$d'), label: '$d gün', selected: days == d, onTap: () => setState(() => _days = d)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(err('discount_days') ?? 'Gönderimden itibaren; süre dolunca fiyatlar kendiliğinden eski haline döner.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: err('discount_days') != null ? AppTheme.error : AppTheme.slate500)),
        ),
        const SizedBox(height: 16),
        _label('Kimlere gitsin?'),
        for (final a in audiences) ...[
          _AudienceCard(
            key: Key('notification_ad_audience_${a['audience']}'),
            icon: _audienceIcons['${a['audience']}'] ?? Icons.people_outline,
            name: '${a['name']}',
            description: '${a['description']}',
            price: (a['price'] as num?) ?? 0,
            selected: a['audience'] == _audience,
            reach: a['audience'] == 'location' && _province.isEmpty ? 'Önce bir il seç' : (_estimates['${a['audience']}'] == null ? 'Hesaplanıyor…' : '≈ ${_count(_estimates['${a['audience']}']!)} kişiye ulaşır'),
            onTap: () {
              setState(() => _audience = '${a['audience']}');
              _scheduleEstimates();
            },
          ),
          if (a['audience'] == 'location' && _audience == 'location')
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('notification_ad_province'),
                    initialValue: _province.isEmpty ? null : _province,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'İl'),
                    items: [for (final p in provinces) DropdownMenuItem(value: '${p['province']}', child: Text('${p['province']} (${_count((p['customers'] as num?) ?? 0)})', overflow: TextOverflow.ellipsis))],
                    onChanged: (v) {
                      setState(() {
                        _province = v ?? '';
                        _district = '';
                        _districts = const [];
                        _estimates.remove('location');
                      });
                      _loadDistricts(_province);
                      _scheduleEstimates();
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('notification_ad_district_$_province'),
                    initialValue: _district.isEmpty ? null : _district,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'İlçe (isteğe bağlı)'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Tüm ilçeler')),
                      for (final d in _districts) DropdownMenuItem(value: '${d['district']}', child: Text('${d['district']} (${_count((d['customers'] as num?) ?? 0)})', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _province.isEmpty
                        ? null
                        : (v) {
                            setState(() {
                              _district = v ?? '';
                              _estimates.remove('location');
                            });
                            _scheduleEstimates();
                          },
                  ),
                ],
              ),
            ),
        ],
        if (err('province') != null || err('audience') != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(err('province') ?? err('audience')!, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.error))),
        const SizedBox(height: 14),
        _Preview(name: '${data['provider_name'] ?? 'Hizmet Veren'}', verified: data['is_verified'] == true, percent: percent, title: _title.text, body: _body.text),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow('Hedef', '${chosen['name']}${_audience == 'location' && _province.isNotEmpty ? ' · $_province${_district.isNotEmpty ? ' / $_district' : ''}' : ''}'),
              _SummaryRow('Ulaşacağı kişi', reach == null ? '—' : '≈ ${_count(reach)}'),
              _SummaryRow('Ücret', _money(price), bold: true),
              const SizedBox(height: 4),
              Text('Bakiyen: ${_money(balance)}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate500)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  key: const Key('notification_ad_send_wallet'),
                  onPressed: !ready || !affordable || _busy ? null : () => _send(data, card: false),
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 17),
                  label: Text(!ready ? 'Başlık, açıklama ve hedefi tamamla' : affordable ? 'Bakiyeden Öde ve Gönder' : (frozen ? 'Cüzdan donduruldu' : 'Bakiye yetersiz')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  key: const Key('notification_ad_send_card'),
                  onPressed: !ready || !cardEnabled || _busy ? null : () => _send(data, card: true),
                  child: const Text('Kartla Öde ve Gönder'),
                ),
              ),
              if (!cardEnabled)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('${payment['card_unavailable_reason'] ?? 'Kartla ödeme şu anda kullanılamıyor.'}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, color: AppTheme.slate400))),
              const SizedBox(height: 8),
              Text('Bugün $sendsLeft gönderim hakkın kaldı. Bildirimleri kapatan kullanıcılara gönderilmez; gönderilen bildirim geri alınamaz.', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, color: AppTheme.slate500, height: 1.35)),
            ],
          ),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(title: 'Gönderilenler'),
          for (final h in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                      child: Text('%${h['discount_percent']}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${h['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          Text('${h['audience_name']} · ${_day((h['sent_at'] ?? h['created_at'])?.toString())} · ${h['status'] == 'SENT' ? '${_count((h['recipients_count'] as num?) ?? 0)} kişiye' : 'gönderiliyor'}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate500)),
                        ],
                      ),
                    ),
                    Text(_money(h['amount'] as num?), style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)));
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.slate200, width: selected ? 1.6 : 1),
        ),
        child: Text(label, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w800, color: selected ? AppTheme.primary : AppTheme.slate700)),
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final num price;
  final bool selected;
  final String reach;
  final VoidCallback onTap;
  const _AudienceCard({super.key, required this.icon, required this.name, required this.description, required this.price, required this.selected, required this.reach, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppTheme.primary : AppTheme.slate200, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: selected ? AppTheme.primary : AppTheme.slate100, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: selected ? Colors.white : AppTheme.slate600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    Text(description, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate500, height: 1.3)),
                    const SizedBox(height: 3),
                    Text(reach, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.slate700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_money(price), style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, color: AppTheme.slate600)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: bold ? 17 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }
}

/// What the customer will get, drawn the way the notification looks (the same copy the server builds).
class _Preview extends StatelessWidget {
  final String name;
  final bool verified;
  final int percent;
  final String title;
  final String body;
  const _Preview({required this.name, required this.verified, required this.percent, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('notification_ad_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.darkNavy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MÜŞTERİNİN TELEFONUNDA BÖYLE GÖRÜNÜR', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFD97706)])),
                  child: const Icon(Icons.notifications_active_rounded, size: 20, color: AppTheme.darkNavy),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                            child: Text('%$percent', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                          Text('indirim · $name', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          if (verified) const VerifiedTick(size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${title.trim().isEmpty ? 'Başlığın' : title.trim()} — ${body.trim().isEmpty ? 'açıklaman burada görünür.' : body.trim()}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate600, height: 1.35)),
                      const SizedBox(height: 4),
                      const Text('Tarak · şimdi', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10, color: AppTheme.slate400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
