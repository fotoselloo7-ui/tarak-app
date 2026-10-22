import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/report_sheet.dart';
import '../../shared/widgets/provider_gallery.dart';
import '../../auth/providers/auth_provider.dart';
import '../appointments/screens/create_appointment_screen.dart';
import '../appointments/providers/customer_appointment_providers.dart';
import 'service_selection_screen.dart';
import '../../../core/widgets/verified_tick.dart';

/// Native customer-facing provider detail. Reuses the real offerings endpoint
/// (`/customer/providers/{id}/offerings`) + real reviews + favourites — no fake data.
class ProviderDetailScreen extends ConsumerStatefulWidget {
  final int providerUserId;
  final String? fallbackName;
  const ProviderDetailScreen({super.key, required this.providerUserId, this.fallbackName});

  @override
  ConsumerState<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  Map<String, dynamic>? _provider;
  List<dynamic> _services = [];
  List<dynamic> _packages = [];
  double _ratingAvg = 0;
  int _ratingCount = 0;
  List<dynamic> _reviews = [];
  bool _loading = true;
  bool _error = false;
  bool _isFav = false;
  bool _favBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = false; });
    final ApiClient api = ref.read(apiClientProvider);
    try {
      final offerings = await api.get('/customer/providers/${widget.providerUserId}/offerings');
      final data = offerings.data is Map ? offerings.data['data'] : null;
      if (data is Map) {
        _provider = data['provider'] is Map ? Map<String, dynamic>.from(data['provider'] as Map) : null;
        _services = data['services'] is List ? data['services'] as List : [];
        _packages = data['packages'] is List ? data['packages'] as List : [];
      }
      // Real reviews (best-effort).
      try {
        final rev = await api.get('/providers/${widget.providerUserId}/reviews');
        final rd = rev.data is Map ? rev.data['data'] : null;
        if (rd is Map) {
          _ratingAvg = (rd['average'] as num?)?.toDouble() ?? 0;
          _ratingCount = (rd['count'] as num?)?.toInt() ?? 0;
          _reviews = rd['reviews'] is List ? rd['reviews'] as List : [];
        }
      } catch (_) {/* ignore */}
      // Favourite state (best-effort).
      try {
        final favs = await api.get('/customer/favorites');
        final fd = favs.data is Map ? favs.data['data'] : null;
        if (fd is List) {
          _isFav = fd.any((f) => (f['provider_user_id'] as num?)?.toInt() == widget.providerUserId);
        }
      } catch (_) {/* ignore */}
    } catch (_) {
      _error = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFav() async {
    if (_favBusy) return;
    setState(() => _favBusy = true);
    final ApiClient api = ref.read(apiClientProvider);
    try {
      if (_isFav) {
        await api.delete('/customer/favorites/${widget.providerUserId}');
        _isFav = false;
      } else {
        await api.post('/customer/favorites', data: {'provider_user_id': widget.providerUserId});
        _isFav = true;
      }
    } catch (_) {/* ignore */} finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  String _tl(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return '₺${d.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final name = _provider?['business_name'] ?? _provider?['name'] ?? widget.fallbackName ?? 'Hizmet Veren';
    final type = _provider?['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';
    final location = [_provider?['district'], _provider?['city']].where((e) => e != null && '$e'.isNotEmpty).join(', ');
    final isVerified = _provider?['is_verified'] == true;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hizmet Veren'),
        actions: [
          IconButton(
            icon: Icon(_isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFav ? AppTheme.error : null),
            onPressed: _favBusy ? null : _toggleFav,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? ErrorState(message: 'Hizmet veren yüklenemedi.', onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if ((_provider?['cover_url'] ?? '').toString().startsWith('http')) ...[
                      ProviderCover(url: _provider!['cover_url'].toString()),
                      const SizedBox(height: 14),
                    ],
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.primaryLight,
                          backgroundImage: (_provider?['avatar_url'] != null && '${_provider?['avatar_url']}'.isNotEmpty)
                              ? NetworkImage('${_provider?['avatar_url']}')
                              : null,
                          child: (_provider?['avatar_url'] == null || '${_provider?['avatar_url']}'.isEmpty)
                              ? Text(
                                  name.toString().isNotEmpty ? name.toString().substring(0, 1).toUpperCase() : '?',
                                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text('$name',
                                      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                                  if (isVerified) ...[
                                    const SizedBox(width: 6),
                                    const VerifiedTick(size: 18),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(type, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, color: AppTheme.textSecondary)),
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.slate400),
                                  const SizedBox(width: 3),
                                  Text(location, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.textSecondary)),
                                ]),
                              ],
                              const SizedBox(height: 6),
                              _ratingCount > 0
                                  ? TarakRatingLabel(
                                      value: _ratingAvg,
                                      count: _ratingCount,
                                      countSuffix: ' değerlendirme',
                                      size: 14,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Henüz değerlendirme yok',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w600,
                                        color: AppTheme.slate400,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_provider?['bio'] != null && '${_provider?['bio']}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('${_provider?['bio']}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, height: 1.5, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((_provider?['experience_years'] as num?) != null && (_provider!['experience_years'] as num) > 0)
                          _factChip(Icons.workspace_premium_outlined, '${(_provider!['experience_years'] as num).toInt()} yıl deneyim'),
                        if (_services.isNotEmpty) _factChip(Icons.content_cut_rounded, '${_services.length} hizmet'),
                        if (_provider?['is_online'] == true)
                          _factChip(Icons.circle, 'Şu an müsait', color: AppTheme.success, bg: AppTheme.successLight),
                      ],
                    ),
                    const SizedBox(height: 20),

                    ProviderGallerySection(urls: providerGalleryUrls(_provider?['gallery'])),
                    if (providerGalleryUrls(_provider?['gallery']).isNotEmpty) const SizedBox(height: 20),

                    if (_services.isNotEmpty) ...[
                      const Text('Hizmetler', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ..._services.map((s) => _offeringTile(
                            s['name']?.toString() ?? s['service']?['name']?.toString() ?? 'Hizmet',
                            s['description']?.toString(),
                            s['price'],
                            s['duration_minutes'],
                          )),
                      const SizedBox(height: 16),
                    ],

                    if (_packages.isNotEmpty) ...[
                      const Text('Paketler', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ..._packages.map((p) => _offeringTile(
                            p['title']?.toString() ?? 'Paket',
                            p['description']?.toString(),
                            p['price'],
                            p['duration_minutes'],
                          )),
                      const SizedBox(height: 16),
                    ],

                    if (_reviews.isNotEmpty) ...[
                      const Text('Değerlendirmeler', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ..._reviews.take(5).map((r) => _reviewTile(r)),
                      const SizedBox(height: 16),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(appointmentWizardProvider.notifier).reset();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAppointmentScreen()));
                        },
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: const Text('Randevu Al'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceSelectionScreen())),
                        icon: const Icon(Icons.flash_on_rounded, size: 18),
                        label: const Text('Hemen Çağır'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _factChip(IconData icon, String text, {Color color = AppTheme.slate600, Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? AppTheme.slate100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _offeringTile(String title, String? desc, dynamic price, dynamic duration) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
                Text(title, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.textSecondary)),
                ],
                if (duration != null) ...[
                  const SizedBox(height: 4),
                  Text('$duration dk', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate400)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(_tl(price), style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _reviewTile(dynamic r) {
    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    final reviewId = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${r['customer_name'] ?? 'Müşteri'}',
                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w600)),
              TarakRatingScale(value: rating, size: 14),
            ],
          ),
          if (r['comment'] != null && '${r['comment']}'.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${r['comment']}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (reviewId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('report_review_$reviewId'),
                onPressed: () => showReportSheet(
                  context,
                  contentType: 'REVIEW',
                  contentId: reviewId,
                  preview: r['comment']?.toString(),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.slate400,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.flag_outlined, size: 14),
                label: const Text('Bildir'),
              ),
            ),
        ],
      ),
    );
  }
}
