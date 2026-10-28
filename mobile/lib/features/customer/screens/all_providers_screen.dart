
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/provider_list_tools.dart';
import '../../shared/widgets/provider_preview_banner.dart';
import '../providers/provider_list_origin.dart';
import 'home_promoted_sections.dart' show ProviderTap;
import 'provider_detail_screen.dart';
import '../../../core/widgets/verified_tick.dart';

/// One page of `GET /providers` (the public "Tüm uzmanlar" list).
class ProviderListPage {
  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// The running list ads (shown as "Önerilen"); only the first page carries them.
  final List<Map<String, dynamic>> sponsored;

  /// How many seconds the recommended set stays before it changes.
  final int? rotationSeconds;
  const ProviderListPage({this.items = const [], this.currentPage = 1, this.lastPage = 1, this.total = 0, this.sponsored = const [], this.rotationSeconds});
}

class ProviderListQuery {
  final String type; // all | coiffeur | barber
  final String sort; // rating | distance | reviews | newest
  final double minRating;
  final int minReviews;
  final String q;
  final int maxDistanceKm;

  /// Where the customer is (device or saved address); lets the API return `distance_km` and filter / sort by it.
  final ListOrigin? origin;

  /// A signed-in provider checking their own list ad ("Müşteri görünümü").
  final bool preview;

  /// Only the recommended cards (the list asks again every few seconds); no organic rows.
  final bool sponsoredOnly;
  const ProviderListQuery({
    this.type = 'all',
    this.sort = 'rating',
    this.minRating = 0,
    this.minReviews = 0,
    this.q = '',
    this.maxDistanceKm = 0,
    this.origin,
    this.preview = false,
    this.sponsoredOnly = false,
  });

  bool get isDefault => type == 'all' && sort == 'rating' && minRating == 0 && minReviews == 0 && q.isEmpty && maxDistanceKm == 0;

  ProviderListQuery copyWith({String? type, String? sort, double? minRating, int? minReviews, String? q, int? maxDistanceKm, ListOrigin? origin, bool clearOrigin = false}) => ProviderListQuery(
        type: type ?? this.type,
        sort: sort ?? this.sort,
        minRating: minRating ?? this.minRating,
        minReviews: minReviews ?? this.minReviews,
        q: q ?? this.q,
        maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
        origin: clearOrigin ? null : (origin ?? this.origin),
        preview: preview,
        sponsoredOnly: sponsoredOnly,
      );

  ProviderListQuery asSponsoredOnly() => ProviderListQuery(type: type, sort: sort, minRating: minRating, minReviews: minReviews, q: q, maxDistanceKm: maxDistanceKm, origin: origin, preview: preview, sponsoredOnly: true);

  Map<String, dynamic> toParams(int page, int perPage) => {
        if (type != 'all') 'type': type,
        'sort': sort == 'distance' && origin == null ? 'rating' : sort,
        if (minRating > 0) 'min_rating': minRating,
        if (minReviews > 0) 'min_reviews': minReviews,
        if (q.isNotEmpty) 'q': q,
        if (origin != null) ...{
          'lat': double.parse(origin!.lat.toStringAsFixed(5)),
          'lng': double.parse(origin!.lng.toStringAsFixed(5)),
          if (maxDistanceKm > 0) 'max_distance_km': maxDistanceKm,
        },
        if (preview) 'preview': 1,
        if (sponsoredOnly) 'sponsored_only': 1,
        'page': page,
        'per_page': perPage,
      };
}

/// Fetches one page; overridable in tests.
typedef ProviderListLoader = Future<ProviderListPage> Function(ProviderListQuery query, int page);

final providerListLoaderProvider = Provider<ProviderListLoader>((ref) {
  final ApiClient api = ref.read(apiClientProvider);
  return (query, page) async {
    final res = await api.get('/providers', queryParameters: query.toParams(page, 12));
    final body = res.data is Map ? res.data as Map : const {};
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    // "sponsored_only" answers carry no organic rows.
    final data = body['data'] ?? (body['sponsored'] is List ? const [] : null);
    if (data is! List) throw const FormatException('Hizmet veren listesi geçersiz.');
    return ProviderListPage(
      items: data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      sponsored: body['sponsored'] is List ? (body['sponsored'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [],
      rotationSeconds: (meta['rotation_seconds'] as num?)?.toInt(),
    );
  };
});

const _reviewOptions = [(0, 'Tümü'), (5, '5+'), (10, '10+'), (25, '25+')];
const _typeOptions = [('all', 'Tümü'), ('coiffeur', 'Kadın Kuaför'), ('barber', 'Erkek Berber')];

/// "Tüm uzmanlar": every listable provider, filterable by gender, Tarak puanı, distance
/// and review count, sortable, searchable and paged (loads more while scrolling). The running
/// list ads ("Sponsorlu") sit at the top of the first page.
class AllProvidersScreen extends ConsumerStatefulWidget {
  /// Where a tapped provider opens; defaults to the signed-in customer's detail screen.
  final ProviderTap? onProviderTap;

  /// "Müşteri görünümü": a provider sees this list as a customer does, with their own list ad first.
  final bool preview;

  /// Inside another screen (the provider's customer view): no app bar and no preview banner of its own.
  final bool embedded;
  const AllProvidersScreen({super.key, this.onProviderTap, this.preview = false, this.embedded = false});

  @override
  ConsumerState<AllProvidersScreen> createState() => _AllProvidersScreenState();
}

class _AllProvidersScreenState extends ConsumerState<AllProvidersScreen> {
  final _scroll = ScrollController();

  /// The recommended cards change every few seconds.
  final RecommendedTicker _ticker = RecommendedTicker();
  int? _rotationSeconds;

  late ProviderListQuery _query = ProviderListQuery(preview: widget.preview);
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _sponsored = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;
  int _generation = 0; // drops answers of superseded requests

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _query = _query.copyWith(origin: ref.read(listOriginProvider));
    _load(reset: true);
  }

  @override
  void dispose() {
    _ticker.stop();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _sponsored = [];
        _page = 1;
        _lastPage = 1;
      }
    });
    try {
      final result = await ref.read(providerListLoaderProvider)(_query, page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.items);
        if (reset) {
          _sponsored = result.sponsored;
          _rotationSeconds = result.rotationSeconds;
        }
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
        _loading = false;
      });
      _ticker.start(_sponsored.isEmpty ? null : _rotationSeconds, _refreshRecommended);
      // A tall screen can show the whole first page: nothing would scroll, so ask for the next page now.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && _scroll.position.maxScrollExtent <= 0) _loadMore();
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e is AppException ? e.message : 'Hizmet verenler yüklenemedi.';
        _loading = false;
      });
    }
  }

  /// New recommended set (just the cards, same filters).
  Future<void> _refreshRecommended() async {
    final result = await ref.read(providerListLoaderProvider)(_query.asSponsoredOnly(), 1);
    if (!mounted) return;
    setState(() {
      _sponsored = result.sponsored;
      _rotationSeconds = result.rotationSeconds ?? _rotationSeconds;
    });
  }

  void _loadMore() {
    if (_loading || _error != null || _page >= _lastPage) return;
    _load(reset: false);
  }

  void _apply(ProviderListQuery next) {
    _query = next;
    _load(reset: true);
  }

  void _reset() {
    _apply(ProviderListQuery(preview: widget.preview, origin: _query.origin));
  }

  ProviderListFilters get _filters => ProviderListFilters(
        q: _query.q,
        minRating: _query.minRating,
        maxDistanceKm: _query.maxDistanceKm,
        sort: ProviderSort.values.firstWhere((s) => s.name == _query.sort, orElse: () => ProviderSort.rating),
      );

  void _onFilters(ProviderListFilters next) => _apply(_query.copyWith(q: next.q, minRating: next.minRating, maxDistanceKm: next.maxDistanceKm, sort: next.sort.name));

  void _open(Map<String, dynamic> provider) {
    final id = (provider['user_id'] is num) ? (provider['user_id'] as num).toInt() : int.tryParse('${provider['user_id']}');
    if (id == null) return;
    final name = (provider['business_name'] ?? provider['name'] ?? 'Hizmet Veren').toString();
    final tap = widget.onProviderTap;
    if (tap != null) {
      tap(id, name);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderDetailScreen(providerUserId: id, fallbackName: name)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A provider in the recommended slots is not listed again below while it is there.
    final shown = recommendedIds(_sponsored.map((p) => p['user_id']));
    final visible = [for (final p in _items) if (!shown.contains('${p['user_id']}')) p];
    // The position arrives later (saved address loaded / device located): list again with distances.
    ref.listen<ListOrigin?>(listOriginProvider, (previous, next) {
      if (next == null || (previous?.lat == next.lat && previous?.lng == next.lng)) return;
      _apply(_query.copyWith(origin: next));
    });
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: widget.embedded ? null : AppBar(title: Text(widget.preview ? 'Müşteri Görünümü' : 'Hizmet Verenler')),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => _load(reset: true),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.preview && !widget.embedded) const SliverToBoxAdapter(child: ProviderPreviewBanner()),
            SliverToBoxAdapter(child: _filtersView()),
            if (_sponsored.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: RecommendedSlot(signature: _sponsored.map((p) => p['user_id']).join(','), children: [for (final p in _sponsored) _ProviderRow(key: ValueKey('recommended_${p['user_id']}'), provider: p, recommended: true, onTap: () => _open(p))]),
                ),
              ),
            if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(padding: const EdgeInsets.all(16), child: ErrorState(message: _error!, onRetry: () => _load(reset: true))),
              )
            else if (!_loading && _items.isEmpty && _sponsored.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Bu filtrelere uygun hizmet veren bulunamadı.', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.slate500)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _reset, child: const Text('Filtreleri temizle')),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == visible.length) return _footer();
                    return _ProviderRow(provider: visible[i], onTap: () => _open(visible[i]));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: TextButton(onPressed: _loadMore, child: Text('$_error Tekrar dene'))),
      );
    }
    return const SizedBox(height: 8);
  }

  Widget _filtersView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProviderFilterBar(
            searchKey: const Key('all_providers_search'),
            searchHint: 'Uzman veya şehir ara',
            value: _filters,
            onChanged: _onFilters,
            sorts: const [ProviderSort.rating, ProviderSort.distance, ProviderSort.reviews, ProviderSort.newest],
            extraRows: [
              _chipRow<String>('Tür', _typeOptions, _query.type, (v) => _apply(_query.copyWith(type: v)), keyPrefix: 'type'),
              _chipRow<int>('Yorum', _reviewOptions, _query.minReviews, (v) => _apply(_query.copyWith(minReviews: v)), keyPrefix: 'reviews'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _loading && _items.isEmpty ? 'Uzmanlar yükleniyor…' : '$_total uzman${_query.isDefault ? '' : ' bulundu'}',
                  key: const Key('all_providers_count'),
                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.slate500),
                ),
              ),
              if (!_query.isDefault) TextButton(onPressed: _reset, child: const Text('Filtreleri temizle')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipRow<T>(String label, List<(T, String)> options, T selected, ValueChanged<T> onSelect, {required String keyPrefix}) {
    return ProviderFilterRow(
      label: label,
      children: [
        for (final (value, text) in options)
          ProviderFilterChip(key: Key('${keyPrefix}_chip_$text'), label: text, selected: selected == value, onTap: () => onSelect(value)),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onTap;
  final bool recommended;
  const _ProviderRow({super.key, required this.provider, required this.onTap, this.recommended = false});

  @override
  Widget build(BuildContext context) {
    final name = (provider['business_name'] ?? provider['name'] ?? 'Hizmet Veren').toString();
    final avatar = provider['avatar_url']?.toString() ?? '';
    final isDemo = provider['is_demo'] == true;
    final rating = isDemo ? null : (provider['rating'] as num?)?.toDouble();
    final reviews = isDemo ? 0 : (provider['review_count'] as num?)?.toInt() ?? 0;
    final services = (provider['service_count'] as num?)?.toInt() ?? 0;
    final location = [provider['district'], provider['city']].where((e) => e != null && '$e'.isNotEmpty).join(', ');
    final role = provider['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: AppTheme.radiusCard, border: Border.all(color: AppTheme.slate200), boxShadow: AppTheme.cardShadow),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 64,
                height: 72,
                child: avatar.startsWith('http')
                    ? Image.network(avatar, fit: BoxFit.cover, alignment: const Alignment(0, -0.5), cacheWidth: 220, errorBuilder: (_, _, _) => Container(color: AppTheme.primaryLight))
                    : Container(
                        color: AppTheme.primaryLight,
                        alignment: Alignment.center,
                        child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recommended) const Padding(padding: EdgeInsets.only(bottom: 4), child: RecommendedTag()),
                  Row(
                    children: [
                      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                      if (isVerifiedMap(provider)) ...[const SizedBox(width: 4), const VerifiedTick(size: 15)],
                      if (isDemo) ...[const SizedBox(width: 4), const DemoProfileTag()],
                    ],
                  ),
                  Text(role, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 5),
                  if (rating != null && reviews > 0)
                    TarakRatingLabel(value: rating, count: reviews, size: 13, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))
                  else
                    const Text('Henüz değerlendirme yok', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate400)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (location.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.slate400),
                        const SizedBox(width: 2),
                        Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textSecondary))),
                        const SizedBox(width: 6),
                      ],
                      DistancePill(km: provider['distance_km']),
                      const SizedBox(width: 6),
                      Text('$services hizmet', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate400)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }
}
