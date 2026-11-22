import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../../core/widgets/verified_tick.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/widgets/tarak_provider_profile_content.dart';
import '../../provider/staff/models/provider_staff_model.dart';
import '../../shared/widgets/provider_gallery.dart';
import '../models/map_business_model.dart';
import '../services/directions_launcher.dart';
import '../services/tarak_marker_renderer.dart';

/// Unified expandable DraggableScrollableSheet for a registered Tarak business.
/// Collapsed state (~40%) shows summary details, `Yol Tarifi`, and `Profili İncele`.
/// Dragging upward or tapping `Profili İncele` expands the SAME sheet (~93%) to
/// reveal Tarak's original canonical profile (cover, avatar, TarakMark rating,
/// gallery, staff, services, packages, working hours, reviews, and booking CTAs).
class TarakBusinessDetailSheet extends ConsumerStatefulWidget {
  final MapBusinessSummary business;
  final bool isGuest;
  final VoidCallback onClose;
  final VoidCallback? onInAppDirections;
  final VoidCallback? onOpenShowcase;
  final ValueChanged<bool>? onExpansionChanged;
  final VoidCallback? onDirectBooking;
  final VoidCallback? onInstantCall;
  final void Function(ProviderStaffModel staff)? onSelectStaff;
  final ExternalUriLauncher? uriLauncher;
  final Future<TarakProviderProfileData> Function()? profileLoader;

  const TarakBusinessDetailSheet({
    super.key,
    required this.business,
    required this.isGuest,
    required this.onClose,
    required this.onInAppDirections,
    this.onOpenShowcase,
    this.onExpansionChanged,
    this.onDirectBooking,
    this.onInstantCall,
    this.onSelectStaff,
    this.uriLauncher,
    this.profileLoader,
  });

  @override
  ConsumerState<TarakBusinessDetailSheet> createState() =>
      _TarakBusinessDetailSheetState();
}

class _TarakBusinessDetailSheetState
    extends ConsumerState<TarakBusinessDetailSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  TarakProviderProfileData? _profile;
  bool _loading = true;
  bool _error = false;
  bool _lastNotifiedExpanded = false;
  int _loadEpoch = 0;

  String get _identifier => widget.business.slug.trim().isNotEmpty
      ? widget.business.slug.trim()
      : widget.business.userId;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_handleSheetExtentChanged);
    _loadProfile();
  }

  void _handleSheetExtentChanged() {
    if (!_sheetController.isAttached || !mounted) return;
    final expanded = _sheetController.size > 0.52;
    if (expanded != _lastNotifiedExpanded) {
      _lastNotifiedExpanded = expanded;
      widget.onExpansionChanged?.call(expanded);
    }
  }

  @override
  void didUpdateWidget(covariant TarakBusinessDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.userId != widget.business.userId ||
        oldWidget.business.slug != widget.business.slug ||
        oldWidget.isGuest != widget.isGuest) {
      _loadProfile();
      if (_sheetController.isAttached && _sheetController.size > 0.5) {
        _sheetController.animateTo(
          0.40,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetExtentChanged);
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final epoch = ++_loadEpoch;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
        _profile = null;
      });
    }
    try {
      final api = ref.read(apiClientProvider);
      final data = widget.profileLoader != null
          ? await widget.profileLoader!()
          : await CanonicalProviderProfileLoader.load(
              api: api,
              providerUserId: int.tryParse(widget.business.userId),
              slugOrIdentifier: _identifier,
              fallbackName: widget.business.businessName,
              initialSummary: widget.business,
              isGuest: widget.isGuest,
            );
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _expandSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.92,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    widget.onOpenShowcase?.call();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.business;
    final profile = _profile;

    final categoryColor = summary.providerType == 'coiffeur'
        ? TarakMarkerRenderer.coiffeurColor
        : TarakMarkerRenderer.barberColor;
    final categoryBg = summary.providerType == 'coiffeur'
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFDBEAFE);

    final businessName = profile?.businessName ?? summary.businessName;
    final avatarUrl =
        profile?.avatarUrl ?? summary.avatarUrl ?? summary.displayImageUrl;
    final isVerified = profile?.isVerified ?? summary.isVerified;
    final acceptsBookings =
        profile?.acceptsTarakBookings ?? summary.acceptsTarakBookings;
    final reviewCount = profile?.reviewCount ?? summary.reviewCount;
    final ratingAvg = profile?.ratingAvg ?? summary.rating ?? 0;
    final addressText = (profile?.formattedAddress != null &&
            profile!.formattedAddress!.isNotEmpty)
        ? profile.formattedAddress!
        : summary.publicLocationSummary;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.40,
      minChildSize: 0.24,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.40, 0.92],
      builder: (ctx, scrollController) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Color(0x240F172A),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Collapsed / Persistent Summary Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ClipOval(
                      child: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _avatarFallback(businessName),
                            )
                          : _avatarFallback(businessName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 5),
                              const VerifiedTick(size: 17),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: categoryBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                summary.typeLabel,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                            reviewCount > 0
                                ? TarakRatingLabel(
                                    value: ratingAvg,
                                    count: reviewCount,
                                    size: 12.5,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Henüz değerlendirme yok',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.slate400,
                                    ),
                                  ),
                            if (summary.distanceKm != null)
                              Text(
                                '• ${summary.distanceKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          addressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          children: [
                            _MiniStatusTag(
                              label: acceptsBookings
                                  ? 'Randevuya Açık'
                                  : 'Tarak Harita Rehberi',
                              bgColor: acceptsBookings
                                  ? const Color(0xFFDCFCE7)
                                  : AppTheme.slate100,
                              textColor: acceptsBookings
                                  ? const Color(0xFF15803D)
                                  : AppTheme.slate700,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('map_preview_close_button'),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded, size: 19),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Compact single-row quick action bar
              Row(
                children: [
                  if (widget.onInAppDirections != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('map_directions_button'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed: widget.onInAppDirections,
                        child: const _CompactActionButtonContent(
                          icon: Icons.directions_rounded,
                          label: 'Yol Tarifi',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('map_open_showcase_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: _expandSheet,
                      child: const _CompactActionButtonContent(
                        icon: Icons.person_outline_rounded,
                        label: 'Profili İncele',
                      ),
                    ),
                  ),
                  if (widget.onDirectBooking != null && acceptsBookings) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('map_provider_direct_book_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed: widget.onDirectBooking,
                        child: const _CompactActionButtonContent(
                          icon: Icons.calendar_month_rounded,
                          label: 'Randevu Al',
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: AppTheme.slate400,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Tam profil, galeri ve ustalar için yukarı kaydırın',
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 18, color: AppTheme.slate200),

              // Expanded Canonical Original Tarak Profile Body
              if (_loading && profile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_error && profile == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Detaylı işletme bilgileri yüklenemedi.',
                          style: AppTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _loadProfile,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              else if (profile != null) ...[
                if (profile.coverUrl != null &&
                    profile.coverUrl!.startsWith('http')) ...[
                  ProviderCover(url: profile.coverUrl!),
                  const SizedBox(height: 14),
                ],
                TarakProviderProfileContent(
                  data: profile,
                  isGuest: widget.isGuest,
                  showHeaderAndCover: false,
                  onBookAppointment: widget.onDirectBooking,
                  onInstantCall: widget.onInstantCall,
                  onSelectStaff: widget.onSelectStaff,
                  onInAppDirections: widget.onInAppDirections,
                  uriLauncher: widget.uriLauncher,
                ),
              ],
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppTheme.primaryLight,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

/// Modal list shown when multiple Tarak pins overlap at the same spot.
class CoLocatedBusinessesSheet extends StatelessWidget {
  final List<MapBusinessSummary> tarakPins;
  final void Function(MapBusinessSummary business) onSelectBusiness;

  const CoLocatedBusinessesSheet({
    super.key,
    required this.tarakPins,
    required this.onSelectBusiness,
  });

  @override
  Widget build(BuildContext context) {
    final total = tarakPins.length;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bu Konumdaki İşletmeler ($total)',
                    style: AppTheme.headingSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final b in tarakPins)
                  ListTile(
                    key: Key('colocated_tarak_${b.userId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const TarakMark(size: 24),
                    title: ProviderNameRow(
                      name: b.businessName,
                      verified: b.isVerified,
                      style: AppTheme.headingSmall,
                    ),
                    subtitle: Text(
                      '${b.typeLabel} • ${b.publicLocationSummary}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectBusiness(b);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatusTag extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _MiniStatusTag({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _CompactActionButtonContent extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactActionButtonContent({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
