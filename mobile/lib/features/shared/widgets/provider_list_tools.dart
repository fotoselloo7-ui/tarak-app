import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../customer/providers/provider_list_origin.dart';

/// Shared controls of every provider list (all providers, per-service "Uzmanlar", the appointment
/// provider step): search, minimum Tarak points, maximum distance, sorting and the "Önerilen"
/// cards of the list ads (they read as a recommendation, never as an advertisement). The lists send
/// these values to the API (see ProviderListFilters.php).
enum ProviderSort { relevance, rating, distance, reviews, newest, price }

const providerSortLabels = <ProviderSort, String>{
  ProviderSort.relevance: 'Varsayılan',
  ProviderSort.rating: 'En yüksek puan',
  ProviderSort.distance: 'En yakın',
  ProviderSort.reviews: 'En çok yorum',
  ProviderSort.newest: 'En yeni',
  ProviderSort.price: 'En uygun fiyat',
};

const providerRatingOptions = <(double, String)>[(0, 'Tümü'), (3, '3+'), (4, '4+'), (4.5, '4,5+')];
const providerDistanceOptions = <(int, String)>[(0, 'Tümü'), (5, '5 km'), (10, '10 km'), (25, '25 km'), (50, '50 km')];

class ProviderListFilters {
  final String q;
  final double minRating;
  final int maxDistanceKm;
  final ProviderSort sort;
  const ProviderListFilters({this.q = '', this.minRating = 0, this.maxDistanceKm = 0, this.sort = ProviderSort.relevance});

  bool get isActive => q.trim().isNotEmpty || minRating > 0 || maxDistanceKm > 0 || sort != ProviderSort.relevance;

  ProviderListFilters copyWith({String? q, double? minRating, int? maxDistanceKm, ProviderSort? sort}) => ProviderListFilters(
        q: q ?? this.q,
        minRating: minRating ?? this.minRating,
        maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
        sort: sort ?? this.sort,
      );

  /// Query-string fragment every provider list endpoint understands.
  Map<String, dynamic> toQuery(ListOrigin? origin) {
    final term = q.trim();
    final effectiveSort = sort == ProviderSort.distance && origin == null ? ProviderSort.relevance : sort;
    return {
      if (term.isNotEmpty) 'q': term,
      if (minRating > 0) 'min_rating': minRating,
      if (origin != null) ...{
        'lat': double.parse(origin.lat.toStringAsFixed(5)),
        'lng': double.parse(origin.lng.toStringAsFixed(5)),
        if (maxDistanceKm > 0) 'max_distance_km': maxDistanceKm,
      },
      if (effectiveSort != ProviderSort.relevance) 'sort': effectiveSort.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ProviderListFilters && other.q == q && other.minRating == minRating && other.maxDistanceKm == maxDistanceKm && other.sort == sort;

  @override
  int get hashCode => Object.hash(q, minRating, maxDistanceKm, sort);
}

String? formatDistanceKm(Object? km) {
  final value = km is num ? km.toDouble() : double.tryParse('$km');
  if (value == null) return null;
  if (value < 0.95) return '${(value * 10).round().clamp(1, 9) * 100} m';
  if (value < 1.05) return '1 km';
  final text = value.toStringAsFixed(value < 10 ? 1 : 0).replaceAll('.', ',');
  return '${text.endsWith(',0') ? text.substring(0, text.length - 2) : text} km';
}

/// Search + stars + distance + sort. Controlled: the screen owns the [ProviderListFilters].
class ProviderFilterBar extends ConsumerStatefulWidget {
  final ProviderListFilters value;
  final ValueChanged<ProviderListFilters> onChanged;
  final List<ProviderSort> sorts;
  final String searchHint;
  final Key? searchKey;

  /// Extra rows (e.g. the gender / review chips of "Tüm uzmanlar") shown under the search box.
  final List<Widget> extraRows;

  const ProviderFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.sorts = const [ProviderSort.relevance, ProviderSort.rating, ProviderSort.distance, ProviderSort.reviews, ProviderSort.newest],
    this.searchHint = 'Uzman, işletme veya şehir ara',
    this.searchKey,
    this.extraRows = const [],
  });

  @override
  ConsumerState<ProviderFilterBar> createState() => _ProviderFilterBarState();
}

class _ProviderFilterBarState extends ConsumerState<ProviderFilterBar> {
  late final TextEditingController _search = TextEditingController(text: widget.value.q);
  Timer? _debounce;

  @override
  void didUpdateWidget(ProviderFilterBar old) {
    super.didUpdateWidget(old);
    // "Filtreleri temizle" resets the filters from outside: keep the text box in step.
    if (widget.value.q != old.value.q && widget.value.q != _search.text.trim()) _search.text = widget.value.q;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final term = text.trim();
      if (term != widget.value.q) widget.onChanged(widget.value.copyWith(q: term));
    });
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(listOriginProvider);
    final locating = ref.watch(providerListOriginProvider.select((s) => s.status));
    final value = widget.value;
    final sort = value.sort == ProviderSort.distance && origin == null ? ProviderSort.relevance : value.sort;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: widget.searchKey ?? const Key('provider_filter_search'),
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Aramayı temizle',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _search.clear();
                      _debounce?.cancel();
                      setState(() {});
                      widget.onChanged(value.copyWith(q: ''));
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.extraRows,
        ProviderFilterRow(
          label: 'Sırala',
          children: [
            for (final key in widget.sorts)
              ProviderFilterChip(
                key: Key('filter_sort_${key.name}'),
                label: providerSortLabels[key]!,
                selected: sort == key,
                // "En yakın" needs a position: tapping it asks for the location instead.
                onTap: () {
                  if (key == ProviderSort.distance && origin == null) {
                    ref.read(providerListOriginProvider.notifier).useDevice();
                    return;
                  }
                  widget.onChanged(value.copyWith(sort: key));
                },
              ),
          ],
        ),
        ProviderFilterRow(
          label: 'Puan',
          children: [
            for (final (rating, text) in providerRatingOptions)
              ProviderFilterChip(key: Key('filter_rating_$text'), label: text, selected: value.minRating == rating, onTap: () => widget.onChanged(value.copyWith(minRating: rating))),
          ],
        ),
        ProviderFilterRow(
          label: 'Mesafe',
          children: origin != null
              ? [
                  for (final (km, text) in providerDistanceOptions)
                    ProviderFilterChip(key: Key('filter_distance_$text'), label: text, selected: value.maxDistanceKm == km, onTap: () => widget.onChanged(value.copyWith(maxDistanceKm: km))),
                ]
              : [
                  _LocationButton(locating: locating == DeviceLocationStatus.locating, onTap: () => ref.read(providerListOriginProvider.notifier).useDevice()),
                ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            origin != null
                ? (origin.fromDevice ? 'Mesafe, şu anki konumuna göre.' : 'Mesafe, kayıtlı adresine göre.')
                : switch (locating) {
                    DeviceLocationStatus.denied => 'Konum izni verilmedi; telefon ayarlarından açabilirsin.',
                    DeviceLocationStatus.unavailable => 'Konum alınamadı; konum servisinin açık olduğundan emin ol.',
                    _ => 'Mesafeye göre süzmek ve sıralamak için konum gerekir.',
                  },
            key: const Key('filter_origin_hint'),
            style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, color: AppTheme.slate400),
          ),
        ),
      ],
    );
  }
}

/// One labelled row of chips that scrolls sideways, so the whole filter bar stays short on a phone
/// and the sponsored cards underneath are not pushed off the screen.
class ProviderFilterRow extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const ProviderFilterRow({super.key, required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label.toUpperCase(), style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppTheme.slate400)),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ProviderFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.darkNavy : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppTheme.darkNavy : AppTheme.slate200),
          ),
          child: Text(label, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.slate600)),
        ),
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final bool locating;
  final VoidCallback onTap;
  const _LocationButton({required this.locating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('filter_use_location'),
      onTap: locating ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.primaryBorder)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locating)
              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
            else
              const Icon(Icons.my_location_rounded, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(locating ? 'Konum alınıyor…' : 'Konumumu kullan', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

/// The small "Önerilen" tag on a list-ad card (same look as the homepage showcase badge).
class RecommendedTag extends StatelessWidget {
  const RecommendedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('recommended_tag'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFDE68A))),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFF59E0B)),
          SizedBox(width: 4),
          Text('Önerilen', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
        ],
      ),
    );
  }
}

/// The recommended slots at the top of a list. [signature] identifies the current set: when it
/// changes (the set rotates every few seconds) the new cards fade in.
class RecommendedSlot extends StatelessWidget {
  final List<Widget> children;
  final String? signature;
  const RecommendedSlot({super.key, required this.children, this.signature});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('recommended_slot'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0x0DFF5722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE4D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Expanded(child: Text('ÖNERİLEN HİZMET VERENLER', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Color(0xFFB45309)))),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation), child: child),
            ),
            child: Column(
              key: ValueKey(signature ?? children.length),
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calls [refresh] every few seconds while a list with recommended cards is on screen (with hundreds of
/// advertisers every one gets its turn). Nothing runs while the app is in the background; a failed
/// refresh just keeps the current set. Own one per screen and call [stop] from `dispose`.
class RecommendedTicker {
  Timer? _timer;
  int? _seconds;

  /// Idempotent: calling it again with the same period keeps the running timer.
  void start(int? seconds, Future<void> Function() refresh) {
    if (seconds == null || seconds <= 0) {
      stop();
      return;
    }
    if (_timer != null && _seconds == seconds) return;
    stop();
    _seconds = seconds;
    _timer = Timer.periodic(Duration(seconds: seconds < 5 ? 5 : seconds), (_) async {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      try {
        await refresh();
      } catch (_) {
        // keep the current set
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _seconds = null;
  }
}

/// Ids of the providers currently shown in the recommended slots, to hide them from the organic list.
Set<String> recommendedIds(Iterable<Object?> userIds) => {for (final id in userIds) '$id'};

/// Small pill with the distance of a provider card ("2,4 km"); nothing when unknown.
class DistancePill extends StatelessWidget {
  final Object? km;
  const DistancePill({super.key, required this.km});

  @override
  Widget build(BuildContext context) {
    final text = formatDistanceKm(km);
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.slate600)),
    );
  }
}
