import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../../core/widgets/service_icon.dart';
import '../../../core/content/home_copy.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../auth/widgets/web_landing_widgets.dart' show trUpper;
import '../providers/home_content_providers.dart';
import 'service_selection_screen.dart';
import 'all_providers_screen.dart';
import 'provider_detail_screen.dart';
import '../../../core/widgets/verified_tick.dart';

// ── Service categories (native equivalent of web CategoriesSection) ─────────
/// Renders the CANONICAL `/api/service-categories` dataset — identical to the
/// web homepage. Only the section heading comes from site-config.
class HomeCategoriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String title;
  final VoidCallback? onSelect;

  const HomeCategoriesSection({
    super.key,
    required this.categories,
    this.title = 'Hizmet Kategorileri',
    this.onSelect,
  });

  /// Visuals are keyed by the domain `provider_type`, never hardcoded names.
  static ({IconData icon, Color accent, String image}) _visual(String? providerType) {
    return switch (providerType) {
      'coiffeur' => (icon: Icons.auto_awesome_rounded, accent: const Color(0xFFF9A8D4), image: 'assets/category-women.jpg'),
      _ => (icon: Icons.content_cut_rounded, accent: const Color(0xFF7DD3FC), image: 'assets/category-men.jpg'),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(eyebrow: 'Bakım sana göre', title: title),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final cardWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: categories.map((c) {
                final visual = _visual(c['provider_type'] as String?);
                return SizedBox(
                  width: cardWidth,
                  child: _CategoryCard(
                    title: '${c['name'] ?? 'Hizmet'}',
                    onSelect: onSelect,
                    icon: visual.icon,
                    color: AppTheme.darkNavy,
                    accent: visual.accent,
                    image: visual.image,
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color accent;
  final String image;
  final VoidCallback? onSelect;
  const _CategoryCard({required this.title, required this.icon, required this.color, required this.accent, required this.image, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceSelectionScreen())),
      // Same card language as the web: navy card, cover photo on the right, "Hizmetleri keşfet".
      child: Container(
        height: 116,
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppTheme.radiusCard,
          image: DecorationImage(
            image: AssetImage(image),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            opacity: 0.6,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppTheme.radiusCard,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.72), color.withValues(alpha: 0.05)],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const Spacer(),
              Text(title,
                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Flexible(
                    child: Text('Hizmetleri keşfet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFFED7AA))),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFFFED7AA)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "Nasıl Çalışır?" (native equivalent of web HowItWorksSection) ───────────
class HomeHowItWorksSection extends StatelessWidget {
  /// Step copy from site-config (`home.how_it_works`) — same wording as web.
  final Map<String, dynamic> content;

  const HomeHowItWorksSection({super.key, this.content = const {}});

  static const _icons = [
    Icons.search_rounded,
    Icons.calendar_month_rounded,
    Icons.person_pin_circle_outlined,
    Icons.verified_outlined,
  ];

  static const _defaultSteps = [
    {'title': 'Hizmetini Seç', 'desc': 'İhtiyacın olan hizmeti kolayca seç.'},
    {'title': 'Zamanını Belirle', 'desc': 'Sana uygun gün ve saati belirle.'},
    {'title': 'Doğrulanmış Uzman Gelsin', 'desc': 'Onaylı hizmet veren adresine gelsin.'},
    {'title': 'Güvenle Hizmet Al', 'desc': 'Süreci takip et, hizmetini tamamla ve değerlendir.'},
  ];

  @override
  Widget build(BuildContext context) {
    final raw = content['steps'];
    final steps = (raw is List && raw.isNotEmpty)
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : _defaultSteps.map((e) => Map<String, dynamic>.from(e)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: homeCopy(content['eyebrow'], 'Sadece 4 Adımda'),
          title: homeCopy(content['title'], 'Nasıl Çalışır?'),
          subtitle: homeCopy(content['subtitle'], 'Tarak ile profesyonel bakım hizmetine ulaşmak çok kolay.'),
        ),
        const SizedBox(height: 6),
        HomeEqualGrid(
          extent: 160,
          children: [
            for (var i = 0; i < steps.length; i++)
              _StepCard(
                number: i + 1,
                icon: _icons[i % _icons.length],
                title: homeCopy(steps[i]['title'], ''),
                desc: homeCopy(steps[i]['desc'], ''),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── "Hizmet Veren Ol" recruitment banner (site-config driven) ───────────────
class HomeProviderCtaSection extends StatelessWidget {
  final Map<String, dynamic> cta;
  /// Same recruitment CTA as the web "Uzman mısın?" block.
  final VoidCallback? onApply;
  const HomeProviderCtaSection({super.key, required this.cta, this.onApply});

  @override
  Widget build(BuildContext context) {
    final eyebrow = (cta['eyebrow'] ?? 'Uzman mısın?').toString();
    final title = (cta['title'] ?? 'Berber veya Kuaför olarak Aramıza Katıl').toString();
    final subtitle = (cta['subtitle'] ??
            'Esnek çalışma saatleri, kendi müşterilerin ve ek gelir fırsatı seni bekliyor.')
        .toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: AppTheme.darkNavy, borderRadius: AppTheme.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUpper(eyebrow),
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFFF8A5B), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4)),
          if (onApply != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onApply,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text((cta['cta_label'] ?? 'Hemen Başvur').toString()),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Verified providers section (real data via /providers/featured) ──────────
class VerifiedProvidersSection extends ConsumerStatefulWidget {
  /// The unfiltered top list (ranked by Tarak puanı by the server).
  final List<Map<String, dynamic>> providers;
  final VoidCallback? onViewAll;
  final void Function(int, String)? onProviderTap;
  const VerifiedProvidersSection({super.key, required this.providers, this.onViewAll, this.onProviderTap});

  @override
  ConsumerState<VerifiedProvidersSection> createState() => _VerifiedProvidersSectionState();
}

class _VerifiedProvidersSectionState extends ConsumerState<VerifiedProvidersSection> {
  /// all | coiffeur (women) | barber (men)
  String _type = 'all';

  static const _chips = [('all', 'Tümü'), ('coiffeur', 'Kadın Kuaför'), ('barber', 'Erkek Berber')];

  @override
  Widget build(BuildContext context) {
    final onViewAll = widget.onViewAll;
    final onProviderTap = widget.onProviderTap;
    final filtered = _type == 'all' ? null : ref.watch(verifiedProvidersByTypeProvider(_type));
    final providers = filtered == null ? widget.providers : (filtered.asData?.value ?? const <Map<String, dynamic>>[]);
    final loading = filtered != null && filtered.isLoading;
    final copy = ref.watch(homeGroupProvider('providers')).asData?.value ?? const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                eyebrow: (copy['eyebrow'] ?? 'Öne Çıkan Uzmanlar').toString(),
                title: (copy['title'] ?? 'Doğrulanmış Hizmet Verenler').toString(),
              ),
            ),
            TextButton(
              // "Tüm Uzmanları Gör": the full, filterable provider list (not the service picker).
              onPressed: onViewAll ?? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AllProvidersScreen(onProviderTap: onProviderTap)),
              ),
              child: const Text('Tüm Uzmanları Gör',
                  style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          key: const Key('verified_type_filter'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in _chips)
              GestureDetector(
                onTap: () => setState(() => _type = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _type == value ? AppTheme.darkNavy : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _type == value ? AppTheme.darkNavy : AppTheme.slate200),
                  ),
                  child: Text(label,
                      style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: _type == value ? Colors.white : AppTheme.slate600)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 156,
          child: loading
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))
              : providers.isEmpty
                  ? const Center(child: Text('Bu filtrede hizmet veren bulunamadı.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate400)))
                  : providers.length == 1
                      ? HomeProviderCard(provider: providers.first, width: double.infinity, onTap: onProviderTap)
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          itemCount: providers.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => HomeProviderCard(provider: providers[i], onTap: onProviderTap),
                        ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class HomeProviderCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final double width;
  final void Function(int, String)? onTap;
  const HomeProviderCard({required this.provider, this.width = 252, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (provider['business_name'] ?? provider['name'] ?? 'Hizmet Veren').toString();
    final type = provider['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';
    final location = [provider['district'], provider['city']].where((e) => e != null && '$e'.isNotEmpty).join(', ');
    final ratingCount = (provider['review_count'] as num?)?.toInt() ?? 0;
    final ratingAvg = (provider['rating'] as num?)?.toDouble();
    final serviceCount = (provider['service_count'] as num?)?.toInt() ?? 0;
    final avatar = provider['avatar_url']?.toString();
    final userId = (provider['user_id'] is num)
        ? (provider['user_id'] as num).toInt()
        : int.tryParse('${provider['user_id']}');

    return GestureDetector(
      onTap: userId == null
          ? null
          : () { if (onTap != null) { onTap!(userId, name); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderDetailScreen(providerUserId: userId, fallbackName: name))); } },
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          // Centered: the card keeps a fixed height for large font scales, which used to leave a blank band at the bottom.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryLight,
              backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
              child: (avatar == null || avatar.isEmpty)
                  ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                      if (isVerifiedMap(provider)) ...[const SizedBox(width: 4), const VerifiedTick(size: 15)],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(type, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  ratingCount > 0 && ratingAvg != null
                      ? TarakRatingLabel(
                          value: ratingAvg,
                          count: ratingCount,
                          size: 13,
                          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                        )
                      : const Text('Henüz değerlendirme yok',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppTheme.slate400)),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.slate400),
                      const SizedBox(width: 2),
                      Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textSecondary))),
                    ]),
                  ],
                  if (serviceCount > 0) ...[
                    const SizedBox(height: 4),
                    Text('$serviceCount hizmet',
                        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate400)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verification / trust section (site-config, shared with web) ─────────────
class VerificationSection extends StatelessWidget {
  final Map<String, dynamic> verification;
  const VerificationSection({super.key, required this.verification});

  static const _defaultCards = [
    {'icon': 'diploma', 'title': 'Diploma Kontrolü', 'desc': 'Mesleki diploma ve sertifikalar doğrulanır.'},
    {'icon': 'certificate', 'title': 'Kalfalık / Ustalık Belgesi', 'desc': 'Resmî mesleki belgeler kontrol edilir.'},
    {'icon': 'identity', 'title': 'Kimlik Doğrulama', 'desc': 'Kimlik bilgileri güvenli şekilde doğrulanır.'},
    {'icon': 'team', 'title': 'Uzman Ekibimiz İnceler', 'desc': 'Başvurular ekibimiz tarafından manuel olarak değerlendirilir.'},
  ];

  /// Same icon + tone per slug as the web SecuritySection.
  static HomeIconBox _iconBox(String? slug) {
    return switch (slug) {
      'diploma' => const HomeIconBox(icon: Icons.fact_check_outlined, background: Color(0xFFECFDF5), foreground: Color(0xFF059669)),
      'certificate' => const HomeIconBox(icon: Icons.workspace_premium_outlined, background: Color(0xFFECFDF5), foreground: Color(0xFF059669)),
      'identity' => const HomeIconBox(icon: Icons.badge_outlined),
      'team' => const HomeIconBox(icon: Icons.groups_outlined, background: Color(0xFFEFF6FF), foreground: Color(0xFF2563EB)),
      _ => const HomeIconBox(icon: Icons.verified_outlined),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cardsRaw = verification['cards'] is List && (verification['cards'] as List).isNotEmpty
        ? (verification['cards'] as List)
        : _defaultCards;
    final cards = cardsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FE),
        borderRadius: AppTheme.radiusCard,
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(homeLabel(homeCopy(verification['eyebrow'], 'Güven, Bizim Standartımız')),
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(homeCopy(verification['title'], 'Doğrulanmış ve Güvenilir Hizmet Verenler'),
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.25)),
          const SizedBox(height: 6),
          Text(homeCopy(verification['subtitle'], 'Sadece yetkin, belgeli ve denetimli profesyoneller platformumuzda yer alır.'),
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45)),
          const SizedBox(height: 12),
          HomeEqualGrid(
            extent: 156,
            children: [
              for (final c in cards)
                _TrustCard(
                  iconBox: _iconBox(c['icon'] as String?),
                  title: homeCopy(c['title'], ''),
                  desc: homeCopy(c['desc'], ''),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Mirrors the real location-grant behaviour: exact address only on consent, at the right stage.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeIconBox(icon: Icons.location_on_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Konum Kontrolü Sende',
                          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.25)),
                      SizedBox(height: 3),
                      Text('Tam adresiniz yalnızca siz izin verdiğinizde ve uygun hizmet aşamasında hizmet verenle paylaşılır.',
                          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
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

class HomeServicesSection extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final VoidCallback? onSelect;
  /// Loading and error states render inside the section, under its own heading.
  final bool loading;
  final VoidCallback? onRetry;
  const HomeServicesSection({super.key, this.services = const [], this.onSelect, this.loading = false, this.onRetry});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SectionHeader(eyebrow: 'Popüler Hizmetler', title: 'Mevcut Hizmetler'),
    const SizedBox(height: 6),
    if (loading)
      const _HomeInlineStatus(text: 'Hizmetler yükleniyor…')
    else if (onRetry != null)
      _HomeInlineError(text: 'Hizmetler yüklenemedi.', onRetry: onRetry!)
    else if (services.isEmpty)
      const _HomeInlineStatus(text: 'Henüz aktif hizmet bulunmuyor.')
    else LayoutBuilder(builder: (context, box) => Wrap(spacing: 10, runSpacing: 10, children: services.take(8).map((service) => SizedBox(width: (box.maxWidth - 10) / 2, child: InkWell(
      borderRadius: AppTheme.radiusMedium,
      onTap: onSelect ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceSelectionScreen())),
      child: Container(padding: const EdgeInsets.all(12), constraints: const BoxConstraints(minHeight: 64), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.slate200), borderRadius: AppTheme.radiusMedium), child: Row(children: [
        ServiceIconBox(iconClass: service['icon_class']?.toString(), name: (service['name'] ?? service['title'])?.toString(), size: 36, iconSize: 18, radius: 10),
        const SizedBox(width: 10), Expanded(child: Text('${service['name'] ?? service['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w600))),
      ])),
    ))).toList())),
    const SizedBox(height: 20),
  ]);
}

class HomeFinalCta extends StatelessWidget {
  final VoidCallback onSelect;
  final VoidCallback? onProvider;
  const HomeFinalCta({super.key, required this.onSelect, this.onProvider});

  static final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  static const _label = TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton(
      onPressed: onSelect,
      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44), shape: _shape, textStyle: _label),
      child: const Text('Randevu Oluştur', maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppTheme.darkNavy, borderRadius: AppTheme.radiusCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TARAK', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 1.3)),
        const SizedBox(height: 10),
        const Text('Randevunuzu şimdi oluşturun.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
        const SizedBox(height: 6),
        const Text('Doğrulanmış uzmanlar arasından seçin; fiyatı ve süreyi önceden görün.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, color: Color(0xFFCBD5E1), height: 1.4)),
        const SizedBox(height: 16),
        if (onProvider == null)
          SizedBox(width: double.infinity, child: primary)
        else
          Row(children: [
            Expanded(child: primary),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onProvider,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.35)), minimumSize: const Size.fromHeight(44), shape: _shape, textStyle: _label),
                child: const Text('Hizmet Veren Olun', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
      ]),
    );
  }
}

// ── Shared home building blocks (same tokens as the web sections) ───────────

/// Two-column grid whose cells all share one height (grows with text scale).
class HomeEqualGrid extends StatelessWidget {
  final double extent;
  final List<Widget> children;
  const HomeEqualGrid({super.key, required this.extent, required this.children});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: extent * scale,
      ),
      children: children,
    );
  }
}

/// Rounded icon tile used by every home card (web: 40px, rounded-xl).
class HomeIconBox extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;
  const HomeIconBox({
    super.key,
    required this.icon,
    this.background = AppTheme.primaryLight,
    this.foreground = AppTheme.primary,
    this.size = 40,
    this.iconSize = 21,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: iconSize, color: foreground),
      );
}

class _StepCard extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String desc;
  const _StepCard({required this.number, required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.slate200),
          boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              HomeIconBox(icon: icon),
              const Spacer(),
              Text(number.toString().padLeft(2, '0'),
                  style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary.withValues(alpha: 0.4))),
            ]),
            const SizedBox(height: 10),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.2)),
            const SizedBox(height: 4),
            Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35)),
          ],
        ),
      );
}

class _TrustCard extends StatelessWidget {
  final HomeIconBox iconBox;
  final String title;
  final String desc;
  const _TrustCard({required this.iconBox, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            iconBox,
            const SizedBox(height: 10),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.2)),
            const SizedBox(height: 3),
            Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textSecondary, height: 1.35)),
          ],
        ),
      );
}

class _HomeInlineStatus extends StatelessWidget {
  final String text;
  const _HomeInlineStatus({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.slate200)),
        child: Text(text, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, color: AppTheme.textSecondary)),
      );
}

class _HomeInlineError extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _HomeInlineError({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFECACA))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)))),
          TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ]),
      );
}
