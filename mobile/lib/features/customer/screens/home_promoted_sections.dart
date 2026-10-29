import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/home_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/home_content_providers.dart';
import 'provider_detail_screen.dart';
import '../../../core/widgets/verified_tick.dart';

typedef ProviderTap = void Function(int userId, String name);

int? _userId(Map<String, dynamic> p) => (p['user_id'] is num)
    ? (p['user_id'] as num).toInt()
    : int.tryParse('${p['user_id']}');

String _roleLabel(Map<String, dynamic> p) =>
    p['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';

String _name(Map<String, dynamic> p) =>
    (p['business_name'] ?? p['name'] ?? 'Hizmet Veren').toString();

void _openProvider(
  BuildContext context,
  Map<String, dynamic> p,
  ProviderTap? onTap,
) {
  final id = _userId(p);
  if (id == null) return;
  if (onTap != null) {
    onTap(id, _name(p));
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProviderDetailScreen(providerUserId: id, fallbackName: _name(p)),
      ),
    );
  }
}

/// "3 gün önce katıldı" from the approval date.
String joinedLabel(String? iso, {DateTime? now}) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return 'Yeni katıldı';
  final days = (now ?? DateTime.now()).difference(date).inDays;
  if (days <= 0) return 'Bugün katıldı';
  if (days == 1) return 'Dün katıldı';
  if (days < 7) return '$days gün önce katıldı';
  if (days < 30) return '${days ~/ 7} hafta önce katıldı';
  if (days < 365) return '${days ~/ 30} ay önce katıldı';
  return 'Aramızda';
}

// ── Öne Çıkan Profesyoneller (paid placement), right under the categories ────

/// 2 columns x 3 rows. The grid always holds one full page and turns to the
/// next page every `rotate_seconds`; a touch pauses it for a while. Hidden while
/// no provider is currently featured (a profile leaves by itself when its
/// period ends).
class HomeSpotlightSection extends ConsumerStatefulWidget {
  final ProviderTap? onProviderTap;
  const HomeSpotlightSection({super.key, this.onProviderTap});

  static const columns = 2;
  static const rows = 3;
  static const pageSize = columns * rows;

  @override
  ConsumerState<HomeSpotlightSection> createState() =>
      _HomeSpotlightSectionState();
}

class _HomeSpotlightSectionState extends ConsumerState<HomeSpotlightSection> {
  Timer? _timer;
  int _page = 0;
  int _seconds = 0;
  int _pages = 1;
  DateTime? _pausedUntil;

  void _schedule(int seconds, int pages) {
    if (seconds == _seconds &&
        pages == _pages &&
        (_timer != null || pages <= 1)) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _seconds = seconds;
    _pages = pages;
    if (pages <= 1) return;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted) return;
      final paused = _pausedUntil;
      if (paused != null && DateTime.now().isBefore(paused)) return;
      // Do not turn pages while another screen covers the home tab.
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      setState(() => _page = (_page + 1) % _pages);
    });
  }

  void _pause() =>
      _pausedUntil = DateTime.now().add(const Duration(seconds: 12));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data =
        ref.watch(spotlightProvidersProvider).asData?.value ??
        const SpotlightData();
    final copy =
        ref.watch(homeGroupProvider('spotlight')).asData?.value ??
        const <String, dynamic>{};
    final pool = data.providers;
    if (pool.isEmpty) return const SizedBox.shrink();

    final pages = (pool.length / HomeSpotlightSection.pageSize).ceil();
    _schedule(data.rotateSeconds, pages);
    final current = _page % pages;
    // A full grid on every page: the last page borrows from the start of the pool.
    final visible = [
      for (
        var i = 0;
        i <
            (pool.length < HomeSpotlightSection.pageSize
                ? pool.length
                : HomeSpotlightSection.pageSize);
        i++
      )
        pool[(current * HomeSpotlightSection.pageSize + i) % pool.length],
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: homeCopy(copy['eyebrow'], 'Vitrindeki Uzmanlar'),
            title: homeCopy(copy['title'], 'Öne Çıkan Profesyoneller'),
            subtitle: homeCopy(
              copy['subtitle'],
              'Bu hafta vitrinde yer alan, işini severek yapan uzmanlarla tanışın.',
            ),
          ),
          const SizedBox(height: 6),
          Listener(
            onPointerDown: (_) => _pause(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final cardWidth =
                    (constraints.maxWidth - spacing) /
                    HomeSpotlightSection.columns;
                const cardHeight = 208.0;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: SizedBox(
                    key: ValueKey('spotlight-$current'),
                    height:
                        cardHeight * HomeSpotlightSection.rows +
                        spacing * (HomeSpotlightSection.rows - 1),
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final p in visible)
                          SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: _SpotlightCard(
                              provider: p,
                              onTap: () => _openProvider(
                                context,
                                p,
                                widget.onProviderTap,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (pages > 1) ...[
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < pages; i++)
                    GestureDetector(
                      key: Key('spotlight_dot_$i'),
                      onTap: () => setState(() {
                        _page = i;
                        _pause();
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 8,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 6,
                          width: i == current ? 22 : 6,
                          decoration: BoxDecoration(
                            color: i == current
                                ? AppTheme.primary
                                : AppTheme.slate300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onTap;
  const _SpotlightCard({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = _name(provider);
    final gallery = provider['gallery'] is List
        ? (provider['gallery'] as List)
        : const [];
    final photo =
        [
              provider['cover_url'],
              if (gallery.isNotEmpty) gallery.first,
              provider['avatar_url'],
            ]
            .map((e) => e?.toString() ?? '')
            .firstWhere((e) => e.startsWith('http'), orElse: () => '');
    final avatar = provider['avatar_url']?.toString() ?? '';
    final rating = (provider['rating'] as num?)?.toDouble();
    final reviews = (provider['review_count'] as num?)?.toInt() ?? 0;
    final city = (provider['city'] ?? '').toString();

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  if (photo.isNotEmpty)
                    Image.network(
                      photo,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.4),
                      cacheWidth: 520,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppTheme.primaryLight),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : Container(color: AppTheme.slate100),
                    )
                  else
                    Container(color: AppTheme.primaryLight),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0x73000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: Color(0xFFF59E0B),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Önerilen',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: -20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatar.startsWith('http')
                          ? Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.5),
                              cacheWidth: 120,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 26, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProviderNameRow(
                    name: name,
                    verified: isVerifiedMap(provider),
                    demo: false,
                    tickSize: 14,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _roleLabel(provider),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null && reviews > 0)
                        TarakRatingLabel(
                          value: rating,
                          count: reviews,
                          size: 12,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        )
                      else
                        const Text(
                          'Yeni profil',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            color: AppTheme.slate400,
                          ),
                        ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              color: AppTheme.slate400,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yeni Katılan Profesyoneller ──────────────────────────────────────────────

class HomeNewestSection extends ConsumerWidget {
  final ProviderTap? onProviderTap;
  const HomeNewestSection({super.key, this.onProviderTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(newestProvidersProvider).asData?.value ??
        const <Map<String, dynamic>>[];
    final copy =
        ref.watch(homeGroupProvider('newest')).asData?.value ??
        const <String, dynamic>{};
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: homeCopy(copy['eyebrow'], 'Aramıza Yeni Katıldı'),
            title: homeCopy(copy['title'], 'Yeni Katılan Profesyoneller'),
            subtitle: homeCopy(
              copy['subtitle'],
              'Platforma yeni katılan doğrulanmış berber ve kuaförler.',
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 118,
            child: ListView.separated(
              key: const Key('newest_providers_list'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _NewestCard(
                provider: items[i],
                onTap: () => _openProvider(context, items[i], onProviderTap),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewestCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onTap;
  const _NewestCard({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = _name(provider);
    final avatar = provider['avatar_url']?.toString() ?? '';
    final rating = (provider['rating'] as num?)?.toDouble();
    final reviews = (provider['review_count'] as num?)?.toInt() ?? 0;
    final city = (provider['city'] ?? '').toString();

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 62,
                height: 62,
                child: avatar.startsWith('http')
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.5),
                        cacheWidth: 200,
                        errorBuilder: (_, _, _) =>
                            Container(color: AppTheme.primaryLight),
                      )
                    : Container(
                        color: AppTheme.primaryLight,
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      joinedLabel(provider['joined_at']?.toString()),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ProviderNameRow(
                    name: name,
                    verified: isVerifiedMap(provider),
                    demo: false,
                    tickSize: 14,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _roleLabel(provider),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (rating != null && reviews > 0)
                        TarakRatingLabel(
                          value: rating,
                          count: reviews,
                          size: 11,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      if (city.isNotEmpty) ...[
                        if (rating != null && reviews > 0)
                          const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              color: AppTheme.slate400,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Platform statistics (real or admin-typed, decided by the server) ─────────

class HomeStatsSection extends ConsumerWidget {
  /// `all` (landing) | `customer` | `provider`
  final String audience;
  const HomeStatsSection({super.key, this.audience = 'all'});

  static const _icons = <String, IconData>{
    'providers': Icons.verified_user_outlined,
    'customers': Icons.groups_2_outlined,
    'weekly_services': Icons.event_available_outlined,
    'total_services': Icons.content_cut_rounded,
    'reviews': Icons.forum_outlined,
    'new_providers_week': Icons.person_add_alt_1_outlined,
    'cities': Icons.location_on_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(homeStatsProvider(audience)).asData?.value ??
        const <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(6).toList();
    // Three numbers sit side by side as compact tiles; otherwise two per row, and a lone last
    // tile spans the row — no orphan half-width card under a full pair.
    final compact = shown.length == 3;
    final perRow = compact ? 3 : 2;

    Widget tile(Map<String, dynamic> s) => _StatTile(
      metric: s['metric']?.toString(),
      value: (s['value'] ?? '').toString(),
      label: (s['label'] ?? '').toString(),
      desc: compact ? null : s['desc']?.toString(),
      compact: compact,
    );

    final rows = <Widget>[];
    for (var i = 0; i < shown.length; i += perRow) {
      final chunk = shown.sublist(i, (i + perRow).clamp(0, shown.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < chunk.length; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                Expanded(child: tile(chunk[j])),
              ],
            ],
          ),
        ),
      );
      if (i + perRow < shown.length) rows.add(const SizedBox(height: 10));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        key: const Key('home_stats_grid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String? metric;
  final String value;
  final String label;
  final String? desc;
  final bool compact;
  const _StatTile({
    required this.metric,
    required this.value,
    required this.label,
    this.desc,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6ECF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          metric == 'avg_rating'
              ? const TarakMark(size: 20)
              : Icon(
                  HomeStatsSection._icons[metric] ?? Icons.insights_outlined,
                  size: 20,
                  color: AppTheme.primary,
                ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          if (desc != null && desc!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              desc!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10,
                color: AppTheme.textSecondary,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
