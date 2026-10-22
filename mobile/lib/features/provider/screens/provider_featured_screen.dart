import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/provider_preview_banner.dart';
import '../instant/providers/provider_instant_providers.dart';
import 'provider_customer_view_screen.dart';
import 'provider_featured_card_payment_screen.dart';
import 'provider_notification_ad_section.dart';

/// `GET /provider/featured`: the ad placements (home showcase / list ad) with their packages priced by
/// the admin, wallet balance, which payment methods are on offer, running / queued periods and the history.
final providerFeaturedProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/featured');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const FormatException('Öne çıkarma bilgileri yanıtı geçersiz.');
}, retry: (retryCount, error) => null);

String _money(num? value) {
  final v = (value ?? 0).toDouble();
  final text = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');
  final parts = text.split(',');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '₺${parts.length > 1 ? '$whole,${parts[1]}' : whole}';
}

String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

const _placementNames = {
  'home': 'Ana Sayfa Vitrini',
  'listing': 'Liste Reklamı',
  'notification': 'Bildirim Reklamı',
};
const _statusLabels = {
  'active': 'Aktif',
  'upcoming': 'Sırada',
  'expired': 'Süresi doldu',
  'cancelled': 'Durduruldu',
};
const _sourceLabels = {'wallet': 'Bakiye', 'card': 'Kart', 'admin': 'Hediye'};

/// "Reklam & Öne Çıkarma": the provider buys a period for an ad placement (Ana Sayfa Vitrini or
/// Liste Reklamı), paid from the wallet cash balance or with a card (PayTR). Every placement shows
/// a fixed screenshot of where the ad appears, and "Müşteri olarak kontrol et" opens the customer
/// list so the provider can see their ad running.
class ProviderFeaturedScreen extends ConsumerStatefulWidget {
  const ProviderFeaturedScreen({super.key});

  @override
  ConsumerState<ProviderFeaturedScreen> createState() =>
      _ProviderFeaturedScreenState();
}

class _ProviderFeaturedScreenState
    extends ConsumerState<ProviderFeaturedScreen> {
  int? _buyingId;
  String _placement = 'listing';

  /// Customer view: the platform as a customer sees it, opened on the provider list with this provider's own list ad first.
  void _openCustomerView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProviderCustomerViewScreen(
          initialTab: CustomerViewTab.providers,
        ),
      ),
    );
  }

  Future<void> _buy(
    Map<String, dynamic> pkg,
    bool queued, {
    required bool card,
    required String placement,
  }) async {
    final price = (pkg['price'] as num?) ?? 0;
    final when = queued
        ? 'Bu alandaki mevcut reklamının bitişinden sonra başlayacak.'
        : 'Ödeme onaylanınca hemen başlayacak.';
    final area = _placementNames[placement] ?? 'Reklam';
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Paketi satın al',
      message: card
          ? '$area için ${pkg['name']} paketi: ${_money(price)} kartından çekilecek; güvenli ödeme ekranı açılacak. $when'
          : '$area için ${pkg['name']} paketi: cüzdanından ${_money(price)} düşülecek. $when',
      confirmText: card ? 'Ödemeye Geç' : 'Onayla ve Öde',
    );
    if (ok != true || !mounted) return;

    setState(() => _buyingId = (pkg['id'] as num).toInt());
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.post(
        '/provider/featured/purchase',
        data: {
          'package_id': pkg['id'],
          'payment_method': card ? 'card' : 'wallet',
        },
      );
      if (card) {
        final data = res.data is Map ? res.data['data'] as Map? : null;
        final order = data?['order'] is Map
            ? Map<String, dynamic>.from(data!['order'] as Map)
            : const <String, dynamic>{};
        final paid = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => ProviderFeaturedCardPaymentScreen(
              orderId: (order['id'] as num).toInt(),
              iframeUrl: '${data!['iframe_url']}',
              amount: (order['amount'] as num?)?.toDouble() ?? price.toDouble(),
              packageName: '${order['package_name'] ?? pkg['name']}',
            ),
          ),
        );
        ref.invalidate(providerFeaturedProvider);
        if (paid == true) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Ödeme alındı, reklam paketin aktif.'),
            ),
          );
        }
      } else {
        ref.invalidate(providerFeaturedProvider);
        ref.invalidate(providerWalletSummaryProvider);
        ref.invalidate(providerAdVisibilityProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Reklam paketiniz aktif edildi.')),
        );
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Satın alma tamamlanamadı.')),
      );
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(providerFeaturedProvider);
    final visibility = ref.watch(providerAdVisibilityProvider).value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Reklam & Öne Çıkarma')),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(providerAdVisibilityProvider);
          ref.invalidate(providerFeaturedProvider);
          await ref.read(providerFeaturedProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            children: const [SizedBox(height: 120), LoadingState(height: 120)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorState(
                message: 'Reklam bilgileri yüklenemedi.',
                onRetry: () => ref.invalidate(providerFeaturedProvider),
              ),
            ],
          ),
          data: (data) {
            Map<String, dynamic> asMap(Object? v) => v is Map
                ? Map<String, dynamic>.from(v)
                : const <String, dynamic>{};
            List<Map<String, dynamic>> asList(Object? v) =>
                (v is List ? v : const [])
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

            final wallet = asMap(data['wallet']);
            final payment = asMap(data['payment']);
            final history = asList(data['history']);
            final balance =
                (wallet['usable_cash_balance'] as num?)?.toDouble() ?? 0;
            final frozen = wallet['is_frozen'] == true;
            final cardEnabled = payment['card_enabled'] == true;

            // Older API responses only know the homepage showcase.
            var placements = asList(data['placements']);
            if (placements.isEmpty) {
              placements = [
                {
                  'placement': 'home',
                  'is_enabled': true,
                  'title': _placementNames['home'],
                  'where': const [],
                  'how': const [],
                  'packages': data['packages'] ?? const [],
                  'status': data['status'] ?? const {},
                },
              ];
            }
            final current = placements.firstWhere(
              (p) => p['placement'] == _placement,
              orElse: () => placements.first,
            );
            final key = '${current['placement']}';
            final status = asMap(current['status']);
            final active = asList(status['active']);
            final upcoming = asList(status['upcoming']);
            final featured = status['is_featured'] == true && active.isNotEmpty;
            final packages = asList(current['packages']);
            final enabled = current['is_enabled'] != false;
            final listingVisibility = visibility?['listing'] is Map
                ? Map<String, dynamic>.from(visibility!['listing'] as Map)
                : null;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Profilini müşterilerin baktığı yerlerde öne çıkar (ana sayfa vitrini, hizmet veren listeleri) ya da müşterilere indirim bildirimi gönder. Süre dolunca reklam otomatik olarak kalkar.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kullanılabilir bakiye',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: AppTheme.slate500,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _money(balance),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          cardEnabled
                              ? 'Bakiyenden ya da kartınla ödeyebilirsin.'
                              : 'Paketler cüzdanındaki nakit bakiyeden ödenir.',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _LiveStatusCard(
                  placements: placements,
                  listing: listingVisibility,
                  onCustomerView: _openCustomerView,
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in placements) ...[
                        Expanded(
                          child: _PlacementTab(
                            key: Key('placement_tab_${p['placement']}'),
                            placement: '${p['placement']}',
                            selected: p['placement'] == current['placement'],
                            enabled: p['is_enabled'] != false,
                            running: p['kind'] == 'notification'
                                ? p['active_discount'] != null
                                : asMap(p['status'])['is_featured'] == true,
                            onTap: () => setState(
                              () => _placement = '${p['placement']}',
                            ),
                          ),
                        ),
                        if (p != placements.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${current['title'] ?? _placementNames[key] ?? 'Reklam'}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if ((current['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${current['description']}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                if (current['kind'] == 'notification') ...[
                  const SizedBox(height: 12),
                  if ((current['how'] as List? ?? const []).isNotEmpty) ...[
                    _BulletBlock(
                      title: 'Nasıl çalışır?',
                      lines: (current['how'] as List).map((e) => '$e').toList(),
                      icon: Icons.circle,
                      color: AppTheme.slate300,
                      small: true,
                    ),
                    const SizedBox(height: 14),
                  ],
                  ProviderNotificationAdSection(
                    onChanged: () {
                      ref.invalidate(providerFeaturedProvider);
                      ref.invalidate(providerWalletSummaryProvider);
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  _PlacementShot(placement: key),
                  const SizedBox(height: 12),
                  if ((current['where'] as List? ?? const []).isNotEmpty) ...[
                    _BulletBlock(
                      title: 'Görüneceği ekranlar',
                      lines: (current['where'] as List)
                          .map((e) => '$e')
                          .toList(),
                      icon: Icons.check_rounded,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if ((current['how'] as List? ?? const []).isNotEmpty) ...[
                    _BulletBlock(
                      title: 'Nasıl çalışır?',
                      lines: (current['how'] as List).map((e) => '$e').toList(),
                      icon: Icons.circle,
                      color: AppTheme.slate300,
                      small: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _StatusCard(
                    featured: featured,
                    active: featured
                        ? Map<String, dynamic>.from(active.first)
                        : null,
                    queued: upcoming.length,
                    until: status['featured_until']?.toString(),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Paketler'),
                  if (!enabled)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Bu reklam alanı şu an satışa kapalı.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.slate400,
                          ),
                        ),
                      ),
                    )
                  else if (packages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Şu an satışta paket yok.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.slate400,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final pkg in packages) ...[
                      _PackageCard(
                        pkg: pkg,
                        affordable:
                            !frozen &&
                            balance + 0.001 >= ((pkg['price'] as num?) ?? 0),
                        frozen: frozen,
                        busy: _buyingId == (pkg['id'] as num).toInt(),
                        onBuy: _buyingId == null
                            ? () => _buy(
                                pkg,
                                featured,
                                card: false,
                                placement: key,
                              )
                            : null,
                        cardAvailable: cardEnabled,
                        cardUnavailableReason:
                            payment['card_unavailable_reason']?.toString(),
                        onBuyWithCard:
                            cardEnabled &&
                                _buyingId == null &&
                                ((pkg['price'] as num?) ?? 0) > 0
                            ? () => _buy(
                                pkg,
                                featured,
                                card: true,
                                placement: key,
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Geçmiş'),
                  for (final h in history) _HistoryRow(item: h),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Yayın durumu": is each placement running, plus the customer-view switch to check it.
class _LiveStatusCard extends StatelessWidget {
  final List<Map<String, dynamic>> placements;
  final Map<String, dynamic>? listing;
  final VoidCallback onCustomerView;
  const _LiveStatusCard({
    required this.placements,
    required this.listing,
    required this.onCustomerView,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors_rounded, size: 16, color: AppTheme.slate500),
              SizedBox(width: 6),
              Text(
                'YAYIN DURUMU',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in placements)
            Builder(
              builder: (_) {
                final key = '${p['placement']}';
                final status = p['status'] is Map
                    ? Map<String, dynamic>.from(p['status'] as Map)
                    : const <String, dynamic>{};
                final period =
                    (status['active'] as List? ?? const [])
                        .whereType<Map>()
                        .isNotEmpty
                    ? Map<String, dynamic>.from(
                        (status['active'] as List).whereType<Map>().first,
                      )
                    : null;
                final isNotification = p['kind'] == 'notification';
                final discount = p['active_discount'] is Map
                    ? Map<String, dynamic>.from(p['active_discount'] as Map)
                    : null;
                final live = isNotification
                    ? discount != null
                    : (key == 'listing' && listing != null
                          ? listing!['running'] == true
                          : status['is_featured'] == true);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: live
                              ? const Color(0xFF10B981)
                              : AppTheme.slate300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_placementNames[key] ?? key}: ${isNotification ? (live ? 'İndirim yayında' : 'Aktif indirim yok') : (live ? 'Yayında' : 'Yayında değil')}',
                              key: Key('live_status_$key'),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              isNotification
                                  ? (discount != null
                                        ? '%${discount['percent']} indirim · ${discount['days_left'] ?? 0} gün kaldı'
                                        : (p['is_enabled'] != false
                                              ? 'Bildirim göndererek indirim başlat.'
                                              : 'Şu an satışa kapalı.'))
                                  : period != null
                                  ? '${period['days_left'] ?? 0} gün kaldı · ${_day(period['ends_at']?.toString())} tarihine kadar'
                                  : (p['is_enabled'] != false
                                        ? 'Aktif paketin yok.'
                                        : 'Şu an satışa kapalı.'),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (listing != null && listing!['running'] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Liste reklamında aynı anda en fazla ${listing!['slots']} hizmet veren "Önerilen" olarak yer alır ve her ${listing!['rotation_seconds']} saniyede bir değişir; şu an seninle yarışan ${listing!['competitors'] ?? 0} hizmet veren daha var.',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.slate500,
                  height: 1.35,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              key: const Key('open_customer_view'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.darkNavy),
              onPressed: onCustomerView,
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Müşteri Görünümüne Geç'),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aynı hesapla müşteri görünümüne geçip ana sayfayı, hizmetleri ve hizmet veren listesini bir müşteri gibi gör; reklamının listede yayınlanıp yayınlanmadığını kontrol et. Hesabın değişmez, hiçbir işlem yapamazsın.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              color: AppTheme.slate500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementTab extends StatelessWidget {
  final String placement;
  final bool selected;
  final bool enabled;
  final bool running;
  final VoidCallback onTap;
  const _PlacementTab({
    super.key,
    required this.placement,
    required this.selected,
    required this.enabled,
    required this.running,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final notification = placement == 'notification';
    final label = !enabled
        ? 'Satışa kapalı'
        : notification
        ? (running ? 'İndirim aktif' : 'Gönderebilirsin')
        : (running ? 'Paketin aktif' : 'Paket alabilirsin');
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.slate200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : AppTheme.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  placement == 'home'
                      ? Icons.home_rounded
                      : notification
                      ? Icons.notifications_active_rounded
                      : Icons.format_list_numbered_rounded,
                  size: 18,
                  color: selected ? Colors.white : AppTheme.slate500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _placementNames[placement] ?? placement,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: !enabled
                      ? AppTheme.slate100
                      : (running
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: !enabled
                        ? AppTheme.slate500
                        : (running
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309)),
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

/// Fixed screenshot (`assets/ads/{placement}-{mobile|web}.png`) of where the placement's ad shows, area framed in orange.
class _PlacementShot extends StatefulWidget {
  final String placement;
  const _PlacementShot({required this.placement});

  @override
  State<_PlacementShot> createState() => _PlacementShotState();
}

class _PlacementShotState extends State<_PlacementShot> {
  String _device = 'mobile';

  @override
  Widget build(BuildContext context) {
    final name = _placementNames[widget.placement] ?? 'Reklam';
    final asset = 'assets/ads/${widget.placement}-$_device.png';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Reklamın nerede görünür',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              for (final (value, label) in const [
                ('mobile', 'Mobil'),
                ('web', 'Web'),
              ])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    key: Key('shot_$value'),
                    onTap: () => setState(() => _device = value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _device == value
                            ? AppTheme.darkNavy
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _device == value
                              ? AppTheme.darkNavy
                              : AppTheme.slate200,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _device == value
                              ? Colors.white
                              : AppTheme.slate600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.asset(asset),
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _device == 'mobile' ? 420 : 240,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      asset,
                      key: Key('placement_shot_${widget.placement}_$_device'),
                      fit: BoxFit.contain,
                      semanticLabel:
                          '$name reklam alanının ${_device == 'mobile' ? 'mobil' : 'web'} uygulamadaki yeri; turuncu çerçeveli bölüm reklamın göründüğü alandır',
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ekran görüntüsü yüklenemedi.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Turuncu çerçeveli bölüm, $name reklamının müşteriye gösterildiği alandır. Büyütmek için dokun.',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              color: AppTheme.slate500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletBlock extends StatelessWidget {
  final String title;
  final List<String> lines;
  final IconData icon;
  final Color color;
  final bool small;
  const _BulletBlock({
    required this.title,
    required this.lines,
    required this.icon,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: small ? 6 : 2),
                  child: Icon(icon, size: small ? 6 : 14, color: color),
                ),
                SizedBox(width: small ? 8 : 6),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.slate600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool featured;
  final Map<String, dynamic>? active;
  final int queued;
  final String? until;
  const _StatusCard({
    required this.featured,
    required this.active,
    required this.queued,
    required this.until,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: featured
            ? const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFFF1E6)],
              )
            : null,
        color: featured ? null : Colors.white,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(
          color: featured ? const Color(0xFFFDE68A) : AppTheme.slate200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: featured ? const Color(0xFFFBBF24) : AppTheme.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: featured ? Colors.white : AppTheme.slate400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featured
                      ? 'Bu alanda yayındasın'
                      : 'Bu alanda şu an reklamın yok',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  featured
                      ? '${active?['package_name'] ?? ''} · ${active?['days_left'] ?? 0} gün kaldı (${_day(active?['ends_at']?.toString())} tarihine kadar)'
                      : 'Aşağıdan bir paket seçerek yayına girebilirsin.',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
                if (featured && queued > 0)
                  Text(
                    'Sırada $queued paket daha var; toplam ${_day(until)} tarihine kadar.',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.slate500,
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

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final bool affordable;
  final bool frozen;
  final bool busy;
  final VoidCallback? onBuy;
  final VoidCallback? onBuyWithCard;

  /// False while the card gateway is not configured: the button stays visible but disabled, with the reason.
  final bool cardAvailable;
  final String? cardUnavailableReason;
  const _PackageCard({
    required this.pkg,
    required this.affordable,
    required this.frozen,
    required this.busy,
    required this.onBuy,
    this.onBuyWithCard,
    this.cardAvailable = true,
    this.cardUnavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    final price = (pkg['price'] as num?)?.toDouble() ?? 0;
    final days = (pkg['duration_days'] as num?)?.toInt() ?? 1;
    final badge = pkg['badge']?.toString();
    final description = pkg['description']?.toString() ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pkg['name']}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (badge != null && badge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (description.isNotEmpty)
            Text(
              description,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(price),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${days > 1 ? '$days gün · ' : ''}günlüğü ${_money((price / days * 100).round() / 100)}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.slate500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: affordable ? onBuy : null,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      affordable
                          ? 'Bakiyeden Öde'
                          : (frozen ? 'Cüzdan donduruldu' : 'Bakiye yetersiz'),
                    ),
            ),
          ),
          if (onBuyWithCard != null ||
              (!cardAvailable && ((pkg['price'] as num?) ?? 0) > 0)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('buy_with_card'),
                onPressed: onBuyWithCard,
                icon: const Icon(Icons.credit_card_rounded, size: 18),
                label: const Text('Kartla Öde'),
              ),
            ),
            if (!cardAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  cardUnavailableReason ??
                      'Kartla ödeme şu anda kullanılamıyor.',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? '';
    final source = item['source']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['package_name']} · ${_placementNames[item['placement']] ?? _placementNames['home']}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${_day(item['starts_at']?.toString())} – ${_day(item['ends_at']?.toString())}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                source == 'admin'
                    ? 'Hediye'
                    : '${_money(item['price_paid'] as num?)} · ${_sourceLabels[source] ?? source}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _statusLabels[status] ?? status,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: status == 'active'
                      ? const Color(0xFF047857)
                      : AppTheme.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
