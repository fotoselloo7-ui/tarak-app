import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../customer/models/customer_address.dart';
import '../../customer/providers/instant_request_provider.dart';
import '../../customer/screens/request_tracking_screen.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/provider_list_tools.dart';
import '../../customer/providers/provider_list_origin.dart';
import '../models/offering_models.dart';
import '../providers/offerings_providers.dart';
import '../../../core/widgets/verified_tick.dart';

TextStyle _t(double size, {FontWeight weight = FontWeight.w500, Color color = AppTheme.textPrimary}) =>
    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: size, fontWeight: weight, color: color);

CustomerAddress? _defaultAddress(List<CustomerAddress> list) {
  if (list.isEmpty) return null;
  return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
}

String _addressLabel(CustomerAddress a) =>
    '${a.title ?? 'Adres'} — ${[a.district, a.province].whereType<String>().join(', ')}';

// ── Service → providers ──────────────────────────────────────────────────────

class ServiceProvidersScreen extends ConsumerStatefulWidget {
  final int serviceId;
  final String serviceName;

  const ServiceProvidersScreen({super.key, required this.serviceId, required this.serviceName});

  @override
  ConsumerState<ServiceProvidersScreen> createState() => _ServiceProvidersScreenState();
}

class _ServiceProvidersScreenState extends ConsumerState<ServiceProvidersScreen> {
  ProviderListFilters _filters = const ProviderListFilters();

  /// The recommended cards change every few seconds: the newest set replaces what the first answer carried.
  final RecommendedTicker _ticker = RecommendedTicker();
  List<ServiceProviderResult>? _live;
  ServiceProvidersQuery? _liveQuery;
  ServiceProvidersQuery? _currentQuery;

  @override
  void dispose() {
    _ticker.stop();
    super.dispose();
  }

  Future<void> _refreshRecommended() async {
    final q = _currentQuery;
    if (q == null) return;
    final list = await ref.read(customerOfferingsRepositoryProvider).fetchServiceProviderList(
          q.serviceId,
          addressId: q.addressId,
          filters: {...q.filters.toQuery(q.origin), 'sponsored_only': 1},
        );
    if (!mounted || _currentQuery != q) return;
    setState(() {
      _live = list.sponsored;
      _liveQuery = q;
    });
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(customerAddressesProvider);
    final origin = ref.watch(listOriginProvider);
    final addressId = _defaultAddress(addresses.value ?? const [])?.id;
    final query = (serviceId: widget.serviceId, addressId: addressId, filters: _filters, origin: origin);
    final results = ref.watch(serviceProvidersProvider(query));
    _currentQuery = query;

    Widget filterBar() => ProviderFilterBar(
          value: _filters,
          onChanged: (next) => setState(() => _filters = next),
          sorts: const [ProviderSort.relevance, ProviderSort.rating, ProviderSort.distance, ProviderSort.price, ProviderSort.reviews],
          searchHint: 'Uzman veya semt ara',
        );

    Widget content() {
      return results.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
        error: (e, _) => ErrorState(
          message: e is AppException ? e.message : 'Uzmanlar yüklenemedi.',
          onRetry: () => ref.invalidate(serviceProvidersProvider(query)),
        ),
        data: (list) {
          // The live set (if it was fetched for these very filters) wins over the first answer.
          final recommended = _live != null && _liveQuery == query ? _live! : list.sponsored;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ticker.start(recommended.isEmpty ? null : list.rotationSeconds, _refreshRecommended);
          });
          final shown = recommendedIds(recommended.map((r) => r.provider.userId));
          final organic = [for (final r in list.providers) if (!shown.contains('${r.provider.userId}')) r];
          if (organic.isEmpty && recommended.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _filters.isActive
                  ? Column(
                      children: [
                        const EmptyState(
                          icon: Icons.person_search_rounded,
                          title: 'Bu filtrelere uygun uzman yok',
                          description: 'Filtreleri gevşetmeyi dene.',
                        ),
                        TextButton(onPressed: () => setState(() => _filters = const ProviderListFilters()), child: const Text('Filtreleri temizle')),
                      ],
                    )
                  : const EmptyState(
                      icon: Icons.person_search_rounded,
                      title: 'Uygun uzman bulunamadı',
                      description: 'Bu hizmeti şu anda sunan doğrulanmış bir uzman yok. Genel Hemen Çağır ile teklif alabilirsin.',
                    ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recommended.isNotEmpty) ...[
                RecommendedSlot(
                  signature: recommended.map((r) => r.provider.userId).join(','),
                  children: [for (final r in recommended) _ProviderResultCard(result: r, recommended: true, margin: EdgeInsets.zero)],
                ),
                const SizedBox(height: 12),
              ],
              for (final r in organic) _ProviderResultCard(result: r),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(widget.serviceName)),
      body: addresses.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async => ref.invalidate(serviceProvidersProvider(query)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  filterBar(),
                  const SizedBox(height: 4),
                  content(),
                ],
              ),
            ),
    );
  }
}

class _ProviderResultCard extends StatelessWidget {
  final ServiceProviderResult result;
  final bool recommended;
  final EdgeInsetsGeometry margin;

  const _ProviderResultCard({required this.result, this.recommended = false, this.margin = const EdgeInsets.only(bottom: 12)});

  @override
  Widget build(BuildContext context) {
    final p = result.provider;
    final o = result.offering;
    return AppCard(
      margin: margin,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProviderOfferingsDetailScreen(providerUserId: p.userId)),
      ),
      child: Row(
        children: [
          _Avatar(url: p.avatarUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommended) const Padding(padding: EdgeInsets.only(bottom: 4), child: RecommendedTag()),
                Row(
                  children: [
                    Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(15, weight: FontWeight.w700))),
                    if (p.isVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedTick(size: 16),
                    ],
                    if (p.distanceKm != null) ...[
                      const SizedBox(width: 6),
                      DistancePill(km: p.distanceKm),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: joinSpans([
                      if (p.region.isNotEmpty) TextSpan(text: p.region),
                      TextSpan(text: '${o.durationMinutes} dk'),
                      p.rating != null ? tarakRatingSpan(p.rating!, size: 13) : const TextSpan(text: 'Henüz değerlendirme yok'),
                    ]),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, color: AppTheme.slate500),
                ),
                const SizedBox(height: 4),
                _AvailabilityText(availability: o.availability),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OfferPrice(price: o.price, originalPrice: o.originalPrice, percent: o.discountPercent),
        ],
      ),
    );
  }
}

// ── Provider detail: services & packages ─────────────────────────────────────

class ProviderOfferingsDetailScreen extends ConsumerWidget {
  final int providerUserId;

  const ProviderOfferingsDetailScreen({super.key, required this.providerUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(customerAddressesProvider);
    final addressList = addresses.value ?? const <CustomerAddress>[];
    final query = (providerUserId: providerUserId, addressId: _defaultAddress(addressList)?.id);
    final bundle = ref.watch(providerOfferingsProvider(query));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Uzman Profili')),
        body: addresses.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : bundle.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => ErrorState(
                  message: e is AppException ? e.message : 'Profil yüklenemedi.',
                  onRetry: () => ref.invalidate(providerOfferingsProvider(query)),
                ),
                data: (b) => NestedScrollView(
                  headerSliverBuilder: (_, _) => [
                    SliverToBoxAdapter(child: _ProviderHeader(provider: b.provider)),
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        child: TabBar(
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: AppTheme.slate500,
                          indicatorColor: AppTheme.primary,
                          labelStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
                          tabs: [
                            Tab(text: 'Hizmetler (${b.services.length})'),
                            Tab(text: 'Paketler (${b.packages.length})'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      b.services.isEmpty
                          ? const EmptyState(
                              icon: Icons.content_cut_rounded,
                              title: 'Aktif hizmet yok',
                              description: 'Bu uzman şu anda aktif bir hizmet sunmuyor.',
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: b.services
                                  .map((s) => _OfferingTile(
                                        title: s.name,
                                        description: s.description,
                                        price: s.price,
                                        originalPrice: s.originalPrice,
                                        discountPercent: s.discountPercent,
                                        durationMinutes: s.durationMinutes,
                                        availability: s.availability,
                                        onCall: () => _openCall(context, b.provider, addressList,
                                            title: s.name, price: s.price, originalPrice: s.originalPrice, discountPercent: s.discountPercent, durationMinutes: s.durationMinutes, providerServiceId: s.providerServiceId),
                                      ))
                                  .toList(),
                            ),
                      b.packages.isEmpty
                          ? const EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'Özel paket yok',
                              description: 'Bu uzmanın aktif bir özel paketi bulunmuyor.',
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: b.packages
                                  .map((p) => _OfferingTile(
                                        title: p.title,
                                        description: p.description,
                                        price: p.price,
                                        originalPrice: p.originalPrice,
                                        discountPercent: p.discountPercent,
                                        durationMinutes: p.durationMinutes,
                                        availability: p.availability,
                                        chips: p.services.map((s) => s.name).toList(),
                                        onCall: () => _openCall(context, b.provider, addressList,
                                            title: p.title, price: p.price, originalPrice: p.originalPrice, discountPercent: p.discountPercent, durationMinutes: p.durationMinutes, providerPackageId: p.id),
                                      ))
                                  .toList(),
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _openCall(
    BuildContext context,
    OfferingProvider provider,
    List<CustomerAddress> addresses, {
    required String title,
    required double price,
    double? originalPrice,
    int discountPercent = 0,
    required int durationMinutes,
    int? providerServiceId,
    int? providerPackageId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DirectCallSheet(
        providerName: provider.name,
        title: title,
        price: price,
        originalPrice: originalPrice,
        discountPercent: discountPercent,
        durationMinutes: durationMinutes,
        providerServiceId: providerServiceId,
        providerPackageId: providerPackageId,
        addresses: addresses,
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  final OfferingProvider provider;

  const _ProviderHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(url: provider.avatarUrl, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProviderNameRow(name: provider.name, verified: provider.isVerified, tickSize: 20, maxLines: 2, style: _t(19, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      [provider.typeLabel, if (provider.region.isNotEmpty) provider.region].join(' • '),
                      style: _t(13, color: AppTheme.slate500),
                    ),
                    const SizedBox(height: 4),
                    provider.rating != null
                        ? TarakRatingLabel(
                            value: provider.rating!,
                            count: provider.reviewCount,
                            size: 14,
                            style: _t(12, color: AppTheme.slate700),
                          )
                        : Text('Henüz değerlendirme yok', style: _t(12, color: AppTheme.slate500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (provider.isVerified)
                const _Badge(icon: Icons.verified_rounded, text: 'Mesleki belgesi doğrulandı', color: AppTheme.success, bg: AppTheme.successLight),
              _Badge(
                icon: Icons.circle,
                text: provider.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                color: provider.isOnline ? AppTheme.success : AppTheme.slate500,
                bg: provider.isOnline ? AppTheme.successLight : AppTheme.slate100,
              ),
            ],
          ),
          if (provider.bio != null) ...[
            const SizedBox(height: 12),
            Text(provider.bio!, style: _t(13, color: AppTheme.slate600)),
          ],
        ],
      ),
    );
  }
}

class _OfferingTile extends StatelessWidget {
  final String title;
  final String? description;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;
  final OfferingAvailability availability;
  final List<String> chips;
  final VoidCallback onCall;

  const _OfferingTile({
    required this.title,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
    required this.availability,
    this.chips = const [],
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: _t(15, weight: FontWeight.w700))),
              OfferPrice(price: price, originalPrice: originalPrice, percent: discountPercent),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!, style: _t(13, color: AppTheme.slate600)),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(20)),
                        child: Text(c, style: _t(11, color: AppTheme.slate700)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.slate500),
              const SizedBox(width: 4),
              Text('$durationMinutes dk', style: _t(12, color: AppTheme.slate500)),
              const SizedBox(width: 10),
              Expanded(child: _AvailabilityText(availability: availability)),
              ElevatedButton.icon(
                onPressed: availability.available ? onCall : null,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Hemen Çağır'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  // The app theme uses a full-width minimum. Inside this Row
                  // the action must size to its label instead of infinity.
                  minimumSize: const Size(0, 42),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A price; while the provider's campaign discount runs, the old price is struck through and the percentage shown.
class OfferPrice extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final int percent;
  final double size;
  final Color? color;
  const OfferPrice({super.key, required this.price, this.originalPrice, this.percent = 0, this.size = 17, this.color});

  @override
  Widget build(BuildContext context) {
    final discounted = originalPrice != null && originalPrice! > price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatTry(price), style: _t(size, weight: FontWeight.w900, color: color ?? AppTheme.textPrimary)),
        if (discounted)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatTry(originalPrice!), style: _t(12, color: AppTheme.slate400).copyWith(decoration: TextDecoration.lineThrough)),
              if (percent > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(5)),
                  child: Text('%$percent', style: _t(10.5, weight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

// ── Direct call confirmation ─────────────────────────────────────────────────

class DirectCallSheet extends ConsumerStatefulWidget {
  final String providerName;
  final String title;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;
  final int? providerServiceId;
  final int? providerPackageId;
  final List<CustomerAddress> addresses;

  const DirectCallSheet({
    super.key,
    required this.providerName,
    required this.title,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
    this.providerServiceId,
    this.providerPackageId,
    required this.addresses,
  });

  @override
  ConsumerState<DirectCallSheet> createState() => _DirectCallSheetState();
}

class _DirectCallSheetState extends ConsumerState<DirectCallSheet> {
  int? _addressId;
  String _payment = 'CASH';
  final _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressId = _defaultAddress(widget.addresses)?.id;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_addressId == null) {
      setState(() => _error = 'Uzmanın size ulaşabilmesi için bir adres seçmelisiniz.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref.read(customerOfferingsRepositoryProvider).createDirectRequest(
            providerServiceId: widget.providerServiceId,
            providerPackageId: widget.providerPackageId,
            addressId: _addressId!,
            paymentMethod: _payment,
            note: _note.text,
          );
      ref.invalidate(myServiceRequestsProvider);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RequestTrackingScreen(requestId: created.id)),
        (route) => route.isFirst,
      );
    } on AppException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Talep oluşturulamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hemen Çağır', style: _t(18, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: AppTheme.radiusCard,
              border: Border.all(color: AppTheme.primaryBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.providerName, style: _t(12, color: AppTheme.slate500)),
                Text(widget.title, style: _t(16, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${widget.durationMinutes} dk', style: _t(13, color: AppTheme.slate600)),
                    const Spacer(),
                    OfferPrice(price: widget.price, originalPrice: widget.originalPrice, percent: widget.discountPercent, size: 20, color: AppTheme.primary),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Fiyat talep anında sabitlenir; uzman sonradan değiştirse de talebin etkilenmez.',
                    style: _t(11, color: AppTheme.slate500)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (widget.addresses.isEmpty)
            Text('Kayıtlı adresin yok. Profil > Adreslerim bölümünden adres ekleyebilirsin.', style: _t(13, color: AppTheme.warning))
          else
            DropdownButtonFormField<int>(
              initialValue: _addressId,
              decoration: const InputDecoration(labelText: 'Hizmet adresi'),
              items: widget.addresses
                  .map((a) => DropdownMenuItem<int>(value: a.id, child: Text(_addressLabel(a), overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _addressId = v),
            ),
          const SizedBox(height: 4),
          Text('Uzman kabul edene kadar yalnızca ilçe bilgisi paylaşılır.', style: _t(11, color: AppTheme.slate500)),
          const SizedBox(height: 14),
          Text('Ödeme yöntemi', style: _t(13, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (value, label) in const [('CASH', 'Nakit'), ('ONLINE', 'Online (kart)')])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: SizedBox(width: double.infinity, child: Text(label, textAlign: TextAlign.center)),
                      selected: _payment == value,
                      showCheckmark: false,
                      selectedColor: AppTheme.primary,
                      labelStyle: _t(13, weight: FontWeight.w700, color: _payment == value ? Colors.white : AppTheme.slate700),
                      onSelected: (_) => setState(() => _payment = value),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: _t(13, color: AppTheme.error)),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            key: const Key('direct_call_submit'),
            onPressed: _submitting || widget.addresses.isEmpty ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
            ),
            child: Text(_submitting ? 'Gönderiliyor...' : '${formatTry(widget.price)} ile Çağır'),
          ),
        ],
      ),
    );
  }
}

// ── Small shared pieces ──────────────────────────────────────────────────────

class _AvailabilityText extends StatelessWidget {
  final OfferingAvailability availability;

  const _AvailabilityText({required this.availability});

  @override
  Widget build(BuildContext context) {
    if (availability.available) {
      final km = availability.distanceKm;
      return Text(
        'Şu an çağrılabilir${km != null ? ' • ~${km.toStringAsFixed(1)} km' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _t(12, weight: FontWeight.w600, color: AppTheme.success),
      );
    }
    return Text(
      availability.reason ?? 'Şu an müsait değil',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _t(12, color: AppTheme.warning),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.slate100,
        child: url != null
            ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.person_rounded, color: AppTheme.slate400, size: size / 2))
            : Icon(Icons.person_rounded, color: AppTheme.slate400, size: size / 2),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color bg;

  const _Badge({required this.icon, required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 8 : 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: _t(12, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
