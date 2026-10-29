import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../shared/widgets/provider_gallery.dart';
import '../../auth/providers/auth_provider.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import '../../../core/widgets/verified_tick.dart';

/// Public provider profile for visitors who are NOT signed in.
///
/// Uses the public `/providers/{id}` endpoint (real rating/review/service
/// counts, no pricing or availability) so a homepage card never leads to a
/// dead route. Booking stays behind the authenticated customer flow.
class PublicProviderScreen extends ConsumerStatefulWidget {
  final int providerUserId;
  final String? fallbackName;

  /// A signed-in provider looks at the profile the way a customer sees it ("Müşteri görünümü"): no sign-up prompt.
  final bool viewOnly;

  const PublicProviderScreen({super.key, required this.providerUserId, this.fallbackName, this.viewOnly = false});

  @override
  ConsumerState<PublicProviderScreen> createState() => _PublicProviderScreenState();
}

class _PublicProviderScreenState extends ConsumerState<PublicProviderScreen> {
  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _reviews;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ApiClient api = ref.read(apiClientProvider);
    try {
      final res = await api.get('/providers/${widget.providerUserId}');
      final data = res.data is Map ? res.data['data'] : null;
      if (!mounted) return;
      setState(() {
        _provider = data is Map ? Map<String, dynamic>.from(data) : null;
        _error = _provider == null ? 'Hizmet veren bulunamadı.' : null;
      });

      final rev = await api.get('/providers/${widget.providerUserId}/reviews');
      final revData = rev.data is Map ? rev.data['data'] : null;
      if (mounted && revData is Map) {
        setState(() => _reviews = Map<String, dynamic>.from(revData));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Profil yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goRegister() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen(initialRole: 'CUSTOMER')),
      );

  void _goLogin() => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));

  @override
  Widget build(BuildContext context) {
    final name = (_provider?['business_name'] ?? _provider?['name'] ?? widget.fallbackName ?? 'Hizmet Veren').toString();
    final type = _provider?['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';
    final location = [_provider?['district'], _provider?['city']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(', ');
    final avatar = _provider?['avatar_url']?.toString();
    final reviewCount = (_reviews?['count'] as num?)?.toInt() ?? 0;
    final rating = (_reviews?['average'] as num?)?.toDouble();
    final serviceCount = (_provider?['service_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Hizmet Veren',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if ((_provider?['cover_url'] ?? '').toString().startsWith('http')) ...[
                      ProviderCover(url: _provider!['cover_url'].toString()),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppTheme.radiusCard,
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: ClipOval(
                              child: (avatar != null && avatar.isNotEmpty)
                                  ? Image.network(
                                      avatar,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: AppTheme.primaryLight,
                                        alignment: Alignment.center,
                                        child: Text(
                                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppTheme.primaryLight,
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(name,
                                          maxLines: 2,
                                          style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary)),
                                    ),
                                    if (isVerifiedMap(_provider)) ...[const SizedBox(width: 4), const VerifiedTick(size: 18)],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(type,
                                    style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily, fontSize: 12.5, color: AppTheme.textSecondary)),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.slate400),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(location,
                                          style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 12,
                                              color: AppTheme.textSecondary)),
                                    ),
                                  ]),
                                ],
                                const SizedBox(height: 8),
                                reviewCount > 0
                                    ? TarakRatingLabel(
                                        value: rating!,
                                        count: reviewCount,
                                        countSuffix: ' değerlendirme',
                                        size: 15,
                                        style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary),
                                      )
                                    : const Text(
                                        'Henüz değerlendirme yok',
                                        style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.slate400),
                                      ),
                                if (serviceCount > 0) ...[
                                  const SizedBox(height: 3),
                                  Text('$serviceCount hizmet',
                                      style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate400)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if ((_provider?['bio'] ?? '').toString().trim().isNotEmpty) ...[
                      Text(_provider!['bio'].toString(),
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily, fontSize: 13, height: 1.5, color: AppTheme.textSecondary)),
                      const SizedBox(height: 20),
                    ],
                    ProviderGallerySection(urls: providerGalleryUrls(_provider?['gallery'])),
                    if (providerGalleryUrls(_provider?['gallery']).isNotEmpty) const SizedBox(height: 20),
                    if (widget.viewOnly)
                      const _ViewOnlyNote()
                    else
                      Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppTheme.radiusCard,
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hizmetleri ve fiyatları görmek için giriş yapın',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          const Text(
                            'Fiyatlar, süreler ve adresinize göre uygunluk bilgisi müşteri hesabıyla görüntülenir.',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                color: AppTheme.textSecondary,
                                height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _goRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: const Text('Hemen Kayıt Ol',
                                      style: TextStyle(
                                          fontFamily: AppTheme.fontFamily, fontSize: 13.5, fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _goLogin,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    side: const BorderSide(color: AppTheme.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text('Giriş Yap',
                                      style: TextStyle(
                                          fontFamily: AppTheme.fontFamily, fontSize: 13.5, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ViewOnlyNote extends StatelessWidget {
  const _ViewOnlyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('public_provider_view_only'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(color: AppTheme.slate200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: AppTheme.slate500),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Müşteri görünümündesin: hizmetler, fiyatlar ve randevu seçenekleri müşteri hesabıyla görüntülenir. Hesabında hiçbir işlem yapılmaz.',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, height: 1.4, color: AppTheme.slate600),
            ),
          ),
        ],
      ),
    );
  }
}
