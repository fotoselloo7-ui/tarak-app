import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_store_buttons.dart';
import '../../customer/providers/home_content_providers.dart';
import '../../customer/screens/home_promoted_sections.dart';
import '../../customer/screens/home_sections.dart';
import 'web_landing_widgets.dart';

/// The home sections (hero, stats, categories, spotlight, services, providers, newest, how it works, verification, CTA),
/// in the order and with the visibility/copy of the site config: the same page the web homepage shows.
/// Used by the signed-out welcome screen and by the provider's "Müşteri görünümü".
class PublicHomeBody extends ConsumerWidget {
  /// "Randevu Oluştur" (hero and closing card).
  final VoidCallback onBook;

  /// "Hizmet Veren Olarak Katıl" / "Hizmet Veren Olun"; without it neither button is shown and the app-download card is left out.
  final VoidCallback? onProviderSignUp;

  /// A category or service card was tapped.
  final VoidCallback onSelectService;

  /// "Tüm Uzmanları Gör".
  final VoidCallback onViewAllProviders;

  /// A provider card was tapped.
  final void Function(int id, String name) onProviderTap;

  const PublicHomeBody({
    super.key,
    required this.onBook,
    required this.onSelectService,
    required this.onViewAllProviders,
    required this.onProviderTap,
    this.onProviderSignUp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single source of truth, shared with the web homepage: same /api/site-config endpoint, same section
    // visibility/order, same copy.
    final siteConfig = ref.watch(siteConfigDataProvider).asData?.value ?? const <String, dynamic>{};
    final sections = ref.watch(homeSectionsProvider).asData?.value ?? const <Map<String, dynamic>>[];
    final featuredProviders = ref.watch(featuredProvidersProvider).asData?.value ?? const <Map<String, dynamic>>[];
    final howItWorks = ref.watch(homeGroupProvider('how_it_works')).asData?.value ?? const <String, dynamic>{};
    final servicesAsync = ref.watch(homeServicesProvider);
    final verification = ref.watch(homeVerificationProvider).asData?.value ?? const <String, dynamic>{};
    final categoriesCopy = ref.watch(homeGroupProvider('categories')).asData?.value ?? const <String, dynamic>{};
    // Canonical domain categories: the same /api/service-categories the web uses.
    final categories = ref.watch(homeCategoriesProvider).asData?.value ?? const <Map<String, dynamic>>[];
    bool sectionOn(String key) => isHomeSectionActive(sections, key);

    final landing = siteConfig['landing'] is Map ? siteConfig['landing'] as Map : const {};
    final hero = landing['hero'] is Map ? landing['hero'] as Map : const {};

    final sectionMap = <String, Widget>{
      'hero': WebHeroSection(
        key: const ValueKey('hero'),
        onInstantCall: onBook,
        onProviderCall: onProviderSignUp,
        badge: (hero['badge'] as String?)?.trim().isNotEmpty == true ? hero['badge'] : 'Berber ve kuaför platformu',
        titlePrefix: (hero['title_prefix'] as String?)?.trim().isNotEmpty == true ? hero['title_prefix'] : 'Doğrulanmış berber ve kuaförler,',
        titleHighlight: (hero['title_highlight'] as String?)?.trim().isNotEmpty == true ? hero['title_highlight'] : 'adresinizde.',
        description: (hero['description'] as String?)?.trim().isNotEmpty == true
            ? hero['description']
            : 'Belgeleri ve kimliği kontrol edilmiş uzmanları karşılaştırın; fiyatı, süreyi ve gerçek müşteri değerlendirmelerini önceden görün, randevunuzu dakikalar içinde oluşturun.',
        ctaPrimary: (hero['cta_primary'] as String?)?.trim().isNotEmpty == true ? hero['cta_primary'] : 'Randevu Oluştur',
        ctaSecondary: (hero['cta_secondary'] as String?)?.trim().isNotEmpty == true ? hero['cta_secondary'] : 'Hizmet Veren Olarak Katıl',
      ),
      'stats': const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 0), child: HomeStatsSection(audience: 'all')),
      'categories': Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: HomeCategoriesSection(categories: categories, title: (categoriesCopy['title'] ?? 'Hizmet Kategorileri').toString(), onSelect: onSelectService)),
      'spotlight': Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: HomeSpotlightSection(onProviderTap: onProviderTap)),
      'services': Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: servicesAsync.when(data: (services) => HomeServicesSection(services: services, onSelect: onSelectService), loading: () => const HomeServicesSection(loading: true), error: (_, _) => HomeServicesSection(onRetry: () => ref.invalidate(homeServicesProvider)))),
      'providers': Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: featuredProviders.isEmpty ? const SizedBox.shrink() : VerifiedProvidersSection(providers: featuredProviders, onViewAll: onViewAllProviders, onProviderTap: onProviderTap)),
      'newest': Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: HomeNewestSection(onProviderTap: onProviderTap)),
      'how_it_works': Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: HomeHowItWorksSection(content: howItWorks)),
      'verification': Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), child: VerificationSection(verification: verification)),
      // Same dark CTA as the web home: customer primary + provider secondary.
      'provider_cta': Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: HomeFinalCta(onSelect: onBook, onProvider: onProviderSignUp)),
      if (onProviderSignUp != null) 'app_download': Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), child: AppDownloadSection(siteConfig: siteConfig)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in homeProductSectionOrder)
          if (sectionOn(key) && sectionMap[key] != null) sectionMap[key]!,
      ],
    );
  }
}
