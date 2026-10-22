import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/verified_tick.dart';

/// Turkish-aware uppercase: Dart's toUpperCase() maps 'i' to 'I', which is
/// wrong in Turkish ("Hizmetler" -> "HIZMETLER" instead of "HİZMETLER").
String trUpper(String value) =>
    value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// True Web-Identical Brand Logo Component
class WebBrandLogo extends StatelessWidget {
  final bool isDark;
  final double iconSize;

  const WebBrandLogo({
    super.key,
    this.isDark = false,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    // Official Tarak wordmark — one image, so the ".app" is never cropped and
    // the aspect ratio is never distorted.
    return TarakLogo(
      height: iconSize * 0.82,
      onDarkSurface: isDark,
    );
  }
}

/// Web-Identical Mobile Navbar
class WebNavbarMobile extends StatelessWidget {
  final VoidCallback onLoginClick;
  final VoidCallback onRegisterClick;

  const WebNavbarMobile({
    super.key,
    required this.onLoginClick,
    required this.onRegisterClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      child: Row(
        children: [
          // The wordmark yields the last pixels on 360px phones instead of overflowing.
          const Expanded(child: Align(alignment: Alignment.centerLeft, child: WebBrandLogo())),
          // Giriş Yap
          TextButton(
            onPressed: onLoginClick,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1F2937),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Giriş Yap',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Kayıt Ol (Mini pill)
          ElevatedButton(
            onPressed: onRegisterClick,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Kayıt Ol',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home hero: a plain, editorial block (eyebrow, headline, short copy, two ordinary buttons, the photo and four
/// facts). Same copy as the web hero (`landing.hero` in the site config); no stickers, no tinted tiles.
class WebHeroSection extends StatelessWidget {
  final VoidCallback onInstantCall;
  /// "Hizmet Veren Olarak Katıl"; no second button when null (a signed-in provider looking at the customer view).
  final VoidCallback? onProviderCall;
  // Site-config overrides (site-config `landing.hero`) — default to the approved copy so the
  // behaviour/tests are unaffected when an admin hasn't customised the homepage yet.
  final String badge;
  final String titlePrefix;
  final String titleHighlight;
  final String description;
  final String ctaPrimary;
  final String ctaSecondary;

  const WebHeroSection({
    super.key,
    required this.onInstantCall,
    this.onProviderCall,
    this.badge = 'Berber ve kuaför platformu',
    this.titlePrefix = 'Doğrulanmış berber ve kuaförler,',
    this.titleHighlight = 'adresinizde.',
    this.description = 'Belgeleri ve kimliği kontrol edilmiş uzmanları karşılaştırın; fiyatı, süreyi ve gerçek müşteri değerlendirmelerini önceden görün, randevunuzu dakikalar içinde oluşturun.',
    this.ctaPrimary = 'Randevu Oluştur',
    this.ctaSecondary = 'Hizmet Veren Olarak Katıl',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow: a thin brand rule and quiet capitals (no pill).
          Row(
            children: [
              Container(width: 24, height: 1.5, color: AppTheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  trUpper(badge),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate500,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate900,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              children: [
                TextSpan(text: '$titlePrefix '),
                TextSpan(text: titleHighlight, style: const TextStyle(color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            description,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.slate600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),

          // Two ordinary buttons: the primary one carries the brand colour.
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onInstantCall,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(ctaPrimary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          if (onProviderCall != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onProviderCall,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.slate900,
                  side: const BorderSide(color: AppTheme.slate300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(ctaSecondary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          const SizedBox(height: 22),

          // The photo, nothing laid on top of it.
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.asset(
                'assets/hero-barber.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.slate800,
                  child: const Center(child: Icon(Icons.person_outline, size: 48, color: Colors.white54)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Four plain facts, no coloured tiles.
          const Divider(height: 1, color: AppTheme.slate200),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final itemWidth = (box.maxWidth - 12) / 2;
              const items = [
                _HeroTrustItem(icon: Icons.verified_outlined, text: 'Belge ve kimlik kontrolü'),
                _HeroTrustItem(icon: Icons.star_outline_rounded, text: 'Şeffaf Tarak Puanı', tarak: true),
                _HeroTrustItem(icon: Icons.location_on_outlined, text: 'Konum gizliliği'),
                _HeroTrustItem(icon: Icons.shield_outlined, text: 'Güvenli ödeme'),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final item in items) SizedBox(width: itemWidth, child: item)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroTrustItem extends StatelessWidget {
  final IconData icon;
  final String text;

  /// Draws the Tarak mark instead of [icon] (rating-related items).
  final bool tarak;

  const _HeroTrustItem({required this.icon, required this.text, this.tarak = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: tarak ? const Center(child: TarakMark(size: 17, muted: true)) : Icon(icon, size: 17, color: AppTheme.slate400),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small section label used above the home section titles: quiet capitals, no pill.
class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: AppTheme.slate500,
        letterSpacing: 1.3,
      ),
    );
  }
}

/// Marketing stats — driven by the admin-managed `landing.stats` list (same
/// values, visibility and order the web homepage renders). Icons stay in code
/// as a design concern and cycle through the palette below.
class WebStatsSection extends StatelessWidget {
  /// Already filtered/sorted by `landingStatsProvider`.
  final List<Map<String, dynamic>> stats;

  const WebStatsSection({super.key, this.stats = const []});

  static const _visuals = [
    (icon: Icons.star_rounded, bg: Color(0xFFF1F5F9), color: Color(0xFF334155), tarak: true),
    (icon: Icons.shield_outlined, bg: Color(0xFFF1F5F9), color: Color(0xFF334155), tarak: false),
    (icon: Icons.location_on_outlined, bg: Color(0xFFF1F5F9), color: Color(0xFF334155), tarak: false),
    (icon: Icons.bolt_rounded, bg: Color(0xFFF1F5F9), color: Color(0xFF334155), tarak: false),
  ];

  @override
  Widget build(BuildContext context) {
    final source = stats.where((s) => !RegExp(r'[0-9]').hasMatch("${s['value'] ?? ''} ${s['desc'] ?? ''}")).toList();

    final statsList = List.generate(source.length, (i) {
      final v = _visuals[i % _visuals.length];
      return _StatData(
        icon: v.icon,
        tarak: v.tarak,
        iconBg: v.bg,
        iconColor: v.color,
        value: (source[i]['value'] ?? '').toString(),
        label: (source[i]['label'] ?? '').toString(),
        desc: (source[i]['desc'] ?? '').toString(),
      );
    });

    if (statsList.isEmpty) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var idx = 0; idx < statsList.length; idx++) ...[
              if (idx > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statsList[idx].iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: statsList[idx].tarak
                          ? const Center(child: TarakMark(size: 22))
                          : Icon(statsList[idx].icon, size: 19, color: statsList[idx].iconColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      statsList[idx].value,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statsList[idx].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (statsList[idx].desc.isNotEmpty)
                            Text(
                              statsList[idx].desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final bool tarak;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final String desc;

  const _StatData({
    required this.icon,
    this.tarak = false,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.desc,
  });
}

/// Web How It Works Section (Exact copy of HowItWorksSection.tsx)
class WebHowItWorksSection extends StatelessWidget {
  /// `home.how_it_works` from site-config — identical copy to the web homepage.
  final Map<String, dynamic> content;

  const WebHowItWorksSection({super.key, this.content = const {}});

  static const _icons = [
    Icons.search_rounded,
    Icons.calendar_today_rounded,
    Icons.person_pin_circle_rounded,
    Icons.shield_rounded,
  ];

  static const _defaultSteps = [
    {'title': 'Hizmetini Seç', 'desc': 'Berber veya kuaför hizmetleri arasından ihtiyacını seç.'},
    {'title': 'Zamanını Belirle', 'desc': 'Uygun tarih ve saati seç, adresini (güvenli şekilde) paylaş.'},
    {'title': 'Doğrulanmış Uzman Gelsin', 'desc': 'Sana en yakın, doğrulanmış uzman belirtilen saatte kapında olsun.'},
    {'title': 'Güvenle Hizmet Al', 'desc': 'Rahatına bak, profesyonel hizmetin keyfini çıkar. Sonrasında değerlendir.'},
  ];

  @override
  Widget build(BuildContext context) {
    final raw = content['steps'];
    final source = (raw is List && raw.isNotEmpty)
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : _defaultSteps.map((e) => Map<String, dynamic>.from(e)).toList();

    final steps = List.generate(source.length, (i) => _StepData(
          num: '${i + 1}',
          title: (source[i]['title'] ?? '').toString(),
          desc: (source[i]['desc'] ?? '').toString(),
          icon: _icons[i % _icons.length],
        ));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          _Eyebrow(trUpper((content['eyebrow'] ?? 'Sadece 4 Adımda').toString())),
          const SizedBox(height: 8),
          Text(
            (content['title'] ?? 'Nasıl Çalışır?').toString(),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (content['subtitle'] ?? 'Tarak ile profesyonel bakım hizmetine ulaşmak çok kolay.').toString(),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 18),

          // 4 Steps Vertical
          ...steps.map((step) => _buildStepItem(step)),
        ],
      ),
    );
  }

  Widget _buildStepItem(_StepData step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  step.num,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(step.icon, size: 20, color: const Color(0xFF334155)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.desc,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                      height: 1.35,
                    ),
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

class _StepData {
  final String num;
  final String title;
  final String desc;
  final IconData icon;

  const _StepData({
    required this.num,
    required this.title,
    required this.desc,
    required this.icon,
  });
}

/// Service categories — CANONICAL domain records from /api/service-categories
/// (identical dataset to the web homepage). Only the heading copy and the
/// visible count come from site-config; category records are never in the CMS.
class WebCategoriesSection extends StatelessWidget {
  final VoidCallback onSelectCategory;
  /// Domain categories: [{id, name, provider_type}, ...]
  final List<Map<String, dynamic>> categories;
  /// `home.categories` copy block from site-config.
  final Map<String, dynamic> content;

  const WebCategoriesSection({
    super.key,
    required this.onSelectCategory,
    this.categories = const [],
    this.content = const {},
  });

  /// Visuals keyed by the domain provider_type, not by category name.
  static ({String image, IconData icon, Color iconBg, String tags}) _visual(String? providerType) {
    return switch (providerType) {
      'coiffeur' => (
          image: 'assets/category-women.jpg',
          icon: Icons.auto_awesome_rounded,
          iconBg: const Color(0xFFDB2777),
          tags: 'Kesim • Fön • Renklendirme',
        ),
      _ => (
          image: 'assets/category-men.jpg',
          icon: Icons.content_cut_rounded,
          iconBg: const Color(0xFF2563EB),
          tags: 'Saç Kesimi • Sakal • Bakım',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final limit = ((content['limit'] as num?) ?? 4).toInt();
    // The section heading always renders (it is a fixed part of the homepage);
    // only the cards depend on the domain data being available.
    final visible = categories.take(limit).toList();

    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(trUpper((content['eyebrow'] ?? 'Popüler Hizmetler').toString())),
          const SizedBox(height: 8),
          Text(
            (content['title'] ?? 'Hizmet Kategorileri').toString(),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (content['subtitle'] ?? 'İhtiyacına en uygun hizmeti seç, doğrulanmış profesyoneller kapına gelsin.').toString(),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),

          // Real category records
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Builder(builder: (_) {
              final v = _visual(visible[i]['provider_type'] as String?);
              return _buildCategoryCard(
                title: '${visible[i]['name'] ?? 'Hizmet'} Hizmetleri',
                tags: v.tags,
                imagePath: v.image,
                icon: v.icon,
                iconBg: v.iconBg,
                onTap: onSelectCategory,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String tags,
    required String imagePath,
    required IconData icon,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1E293B)),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            tags,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Hizmetleri İncele',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF111827)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web Security Section (Exact copy of SecuritySection.tsx)
class WebSecuritySection extends StatelessWidget {
  const WebSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    final verificationCards = [
      const _VerifData(
        icon: Icons.school_outlined,
        iconBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF334155),
        title: 'Diploma Kontrolü',
        desc: 'Mesleki diploma ve uzmanlık belgeleri doğrulanır.',
      ),
      const _VerifData(
        icon: Icons.military_tech_outlined,
        iconBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF334155),
        title: 'Kalfalık / Ustalık Belgesi',
        desc: 'Resmi MEB veya mesleki oda belgeleri incelenir.',
      ),
      const _VerifData(
        icon: Icons.person_search_outlined,
        iconBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF334155),
        title: 'Kimlik Doğrulama',
        desc: 'Nüfus ve kimlik bilgileri güvenlik amacıyla teyit edilir.',
      ),
      const _VerifData(
        icon: Icons.admin_panel_settings_outlined,
        iconBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF334155),
        title: 'Admin İncelemesi',
        desc: 'Her başvuru yetkili ekibimizce birebir onaylanır.',
      ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Light Blue Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Eyebrow('GÜVENCE'),
                const SizedBox(height: 8),
                const Text(
                  'Doğrulanmış ve Güvenilir Uzmanlar',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sadece yetkin, belgeli ve deneyimli profesyoneller platformumuzda yer alır. Tüm hizmet verenlerimiz titizlikle incelenir ve onaylanır.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // 4 Mini Verification Cards
                ...verificationCards.map((card) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: card.iconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(card.icon, size: 18, color: card.iconColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.title,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  card.desc,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Location Privacy Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF334155), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GİZLİLİĞİNİZ ÖNCELİĞİMİZ',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'Konum Kontrolü Sende',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tam adresini hemen paylaşmak zorunda değilsin. Hizmet öncesinde yalnızca ilçe veya yaklaşık konum paylaşılır; tam adres yalnızca randevu onaylandığında seçtiğin uzmana açılır.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const _PrivacyBullet(text: 'Tam adres yerine yaklaşık konum paylaşımı'),
                const SizedBox(height: 4),
                const _PrivacyBullet(text: 'Yalnızca onaylanan randevuda uzman adresi görür'),
                const SizedBox(height: 4),
                const _PrivacyBullet(text: 'Hizmet tamamlanana kadar konum gizliliği korunur'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  final String text;

  const _PrivacyBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFFF5722)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String desc;

  const _VerifData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.desc,
  });
}

/// Web Provider Recruitment CTA Section (Exact copy of provider-cta)
class WebProviderCtaSection extends StatelessWidget {
  final VoidCallback onApply;
  // Site-config overrides (`home.provider_cta`) — default to approved copy.
  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaLabel;

  const WebProviderCtaSection({
    super.key,
    required this.onApply,
    this.eyebrow = 'UZMAN MISIN?',
    this.title = 'Berber veya Kuaför olarak Aramıza Katıl',
    this.subtitle = 'Esnek çalışma saatleri, kendi müşterilerin ve ek gelir fırsatı seni bekliyor. Binlerce kişinin bakımına dokun, güvenilir bir platformda yer al.',
    this.ctaLabel = 'Hemen Başvur',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.4)),
            ),
            child: Text(
              trUpper(eyebrow),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFAB91),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFFCBD5E1),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // 4 Checklist Items
          _buildCheckItem('Sana uygun bölgelerde iş fırsatları'),
          _buildCheckItem('Güvenilir ve doğrulanmış platform'),
          _buildCheckItem('Kolay randevu yönetimi'),
          _buildCheckItem('Düzenli gelir ve şeffaf ödeme'),
          const SizedBox(height: 18),

          // Hemen Başvur Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                ctaLabel,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFFFFAB91)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Verified/featured providers — real data only (same `/providers/featured`
/// source as web's ProviderCarousel fallback). Never shows placeholder names;
/// an empty result quietly hides the section (handled by the caller).
class WebProvidersSection extends StatelessWidget {
  final List<Map<String, dynamic>> providers;
  final VoidCallback onViewAll;
  /// Opens the REAL public provider profile — never a dead tap.
  final void Function(int providerUserId, String name)? onProviderTap;

  const WebProvidersSection({
    super.key,
    required this.providers,
    required this.onViewAll,
    this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ÖNE ÇIKAN UZMANLAR',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF5722),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Doğrulanmış Hizmet Verenler',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          if (providers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
              ),
              child: const Text(
                'İlk doğrulanmış hizmet verenlerimiz onaylandıkça burada listelenecek.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, color: Color(0xFF6B7280)),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: providers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = providers[i];
                  final name = (p['business_name'] ?? p['name'] ?? 'Hizmet Veren').toString();
                  final type = p['provider_type'] == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';
                  final rating = (p['rating'] as num?)?.toDouble();
                  final reviewCount = (p['review_count'] as num?)?.toInt() ?? 0;
                  final userId = (p['user_id'] is num)
                      ? (p['user_id'] as num).toInt()
                      : int.tryParse('${p['user_id']}');
                  return GestureDetector(
                    onTap: (userId == null || onProviderTap == null)
                        ? null
                        : () => onProviderTap!(userId, name),
                    child: Container(
                    width: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ),
                            if (isVerifiedMap(p)) ...[const SizedBox(width: 4), const VerifiedTick(size: 15)],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(type, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: Color(0xFF6B7280))),
                        const Spacer(),
                        reviewCount > 0
                            ? TarakRatingLabel(
                                value: rating!,
                                count: reviewCount,
                                size: 13,
                                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                              )
                            : const Text(
                                'Henüz değerlendirme yok',
                                style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                              ),
                      ],
                    ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5722),
                side: const BorderSide(color: Color(0xFFFF5722)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Tüm Hizmet Verenleri Gör',
                  style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}


/// Web Footer Section
class WebFooterSection extends StatelessWidget {
  const WebFooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0F17),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        children: [
          const WebBrandLogo(isDark: true),
          const SizedBox(height: 12),
          const Text(
            "Tarak, berber ve kuaför hizmetlerini güvenli, kolay ve erişilebilir hale getiren Türkiye'nin öncü platformudur.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} Tarak. Tüm hakları saklıdır.',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

