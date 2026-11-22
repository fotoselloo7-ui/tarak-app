import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/app_store_buttons.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../notifications/screens/notification_center_screen.dart';
import '../appointments/models/customer_appointment_model.dart';
import '../appointments/providers/customer_appointment_providers.dart';
import '../appointments/screens/create_appointment_screen.dart';
import '../appointments/screens/customer_appointment_detail_screen.dart';
import '../models/service_request_model.dart';
import '../providers/instant_request_provider.dart';
import '../providers/home_content_providers.dart';
import '../../map_directory/screens/tarak_map_screen.dart';
import 'request_tracking_screen.dart';
import 'service_selection_screen.dart';
import 'home_sections.dart';
import 'home_promoted_sections.dart';
import '../../../core/widgets/verified_tick.dart';

/// Customer home tab — shows greeting, Hemen Çağır CTA, Planlı Randevu, active jobs & trust banner.
class CustomerHomeTab extends ConsumerWidget {
  const CustomerHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final siteConfig =
        ref.watch(siteConfigDataProvider).asData?.value ??
        const <String, dynamic>{};
    final requestsAsync = ref.watch(myServiceRequestsProvider);
    final appointmentsAsync = ref.watch(customerAppointmentsProvider);
    final featuredAsync = ref.watch(featuredProvidersProvider);
    final verificationAsync = ref.watch(homeVerificationProvider);
    final sections =
        ref.watch(homeSectionsProvider).asData?.value ??
        const <Map<String, dynamic>>[];
    final servicesAsync = ref.watch(homeServicesProvider);
    // Same canonical sources the web homepage uses — real /api/service-categories data.
    final categories =
        ref.watch(homeCategoriesProvider).asData?.value ??
        const <Map<String, dynamic>>[];
    final categoriesCopy =
        ref.watch(homeGroupProvider('categories')).asData?.value ??
        const <String, dynamic>{};
    final howItWorks =
        ref.watch(homeGroupProvider('how_it_works')).asData?.value ??
        const <String, dynamic>{};
    bool sectionOn(String key) => isHomeSectionActive(sections, key);

    Future<void> openAppointment() async {
      ref.read(appointmentWizardProvider.notifier).reset();
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const CreateAppointmentScreen()),
      );
      if (!context.mounted) return;
      // The appointment flow may have resolved an older address's coordinates.
      ref.invalidate(customerAddressesProvider);
      ref.invalidate(nearbyHomeProvidersProvider);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(siteConfigDataProvider);
          ref.invalidate(homeServicesProvider);
          ref.invalidate(homeCategoriesProvider);
          ref.invalidate(featuredProvidersProvider);
          ref.invalidate(spotlightProvidersProvider);
          ref.invalidate(newestProvidersProvider);
          ref.invalidate(customerAddressesProvider);
          ref.invalidate(nearbyHomeProvidersProvider);
          ref.invalidate(homeStatsProvider);
          await Future.wait([
            ref.read(myServiceRequestsProvider.notifier).refresh(),
            ref.read(customerAppointmentsProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // Premium Header with User Greeting
            SliverAppBar(
              backgroundColor: AppTheme.darkNavy,
              expandedHeight: 150,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              // The official wordmark lives in the pinned toolbar: it stays put while the page scrolls.
              title: const TarakLogo(height: 24, onDarkSurface: true),
              centerTitle: false,
              titleSpacing: 20,
              actions: const [NotificationCenterButton(color: Colors.white)],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppTheme.darkNavy,
                  child: SafeArea(
                    child: Padding(
                      // Below the toolbar row (logo + bell).
                      padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 4, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Merhaba, ${user?.firstName ?? user?.name ?? 'Müşteri'}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Berberi kapına çağır, zaman kaybetme.',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppAvatar(name: user?.name ?? 'Müşteri', imageUrl: user?.avatarUrl, radius: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Action Row: 3 cards side-by-side in 1 row (Hemen Çağır, Planlı Randevu, Haritada Gör)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 340;
                        final gap = isCompact ? 6.0 : 8.0;
                        final cardPad = EdgeInsets.symmetric(
                          horizontal: isCompact ? 6 : 8,
                          vertical: isCompact ? 8 : 10,
                        );
                        final iconBoxSize = isCompact ? 22.0 : 24.0;
                        final iconSize = isCompact ? 13.0 : 14.0;
                        final iconTextGap = isCompact ? 4.5 : 5.5;
                        final titleSize = isCompact ? 10.5 : 11.5;
                        final subtitleSize = isCompact ? 9.2 : 10.0;

                        return IntrinsicHeight(
                          key: const Key('home_primary_actions_row'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Primary CTA: Hemen Çağır
                              Expanded(
                                child: FadeSlideIn(
                                  child: _HomeQuickActionCard(
                                    key: const Key('home_instant_call_cta'),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ServiceSelectionScreen(),
                                      ),
                                    ),
                                    padding: cardPad,
                                    backgroundColor: AppTheme.primary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withAlpha(50),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                    icon: Icons.flash_on_rounded,
                                    iconColor: AppTheme.primary,
                                    iconBgColor: Colors.white,
                                    iconBgCircle: true,
                                    iconBoxSize: iconBoxSize,
                                    iconSize: iconSize,
                                    iconTextGap: iconTextGap,
                                    title: 'Hemen Çağır',
                                    titleColor: Colors.white,
                                    titleSize: titleSize,
                                    subtitle:
                                        'En yakın uzman anında kapında',
                                    subtitleColor: const Color(0xFFFFCCBC),
                                    subtitleSize: subtitleSize,
                                  ),
                                ),
                              ),

                              SizedBox(width: gap),

                              // 2. Secondary CTA: Planlı Randevu
                              Expanded(
                                child: FadeSlideIn(
                                  delay: const Duration(milliseconds: 60),
                                  child: _HomeQuickActionCard(
                                    key: const Key(
                                      'home_scheduled_appointment_cta',
                                    ),
                                    onTap: openAppointment,
                                    padding: cardPad,
                                    backgroundColor: Colors.white,
                                    border: Border.all(color: AppTheme.slate200),
                                    boxShadow: AppTheme.cardShadow,
                                    icon: Icons.calendar_month_rounded,
                                    iconColor: AppTheme.darkNavy,
                                    iconBgColor: AppTheme.slate100,
                                    iconBgCircle: true,
                                    iconBoxSize: iconBoxSize,
                                    iconSize: iconSize,
                                    iconTextGap: iconTextGap,
                                    title: 'Planlı Randevu',
                                    titleColor: AppTheme.textPrimary,
                                    titleSize: titleSize,
                                    subtitle:
                                        'İstediğin gün ve saatte oluştur',
                                    subtitleColor: AppTheme.textSecondary,
                                    subtitleSize: subtitleSize,
                                  ),
                                ),
                              ),

                              SizedBox(width: gap),

                              // 3. Tertiary CTA: Haritada Gör
                              Expanded(
                                child: FadeSlideIn(
                                  delay: const Duration(milliseconds: 120),
                                  child: _HomeQuickActionCard(
                                    key: const Key('home_tarak_map_cta'),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const TarakMapScreen(),
                                      ),
                                    ),
                                    padding: cardPad,
                                    backgroundColor: AppTheme.darkNavy,
                                    boxShadow: AppTheme.cardShadow,
                                    icon: Icons.map_rounded,
                                    iconColor: Colors.white,
                                    iconBgColor: AppTheme.primary,
                                    iconBgCircle: false,
                                    iconBoxSize: iconBoxSize,
                                    iconSize: iconSize,
                                    iconTextGap: iconTextGap,
                                    title: 'Haritada Gör',
                                    titleColor: Colors.white,
                                    titleSize: titleSize,
                                    subtitle:
                                        'Yakındaki hizmetverenleri keşfet',
                                    subtitleColor: AppTheme.slate300,
                                    subtitleSize: subtitleSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Hizmet kategorileri — canonical /api/service-categories data
                    if (sectionOn('categories'))
                      HomeCategoriesSection(
                        categories: categories
                            .take(
                              ((categoriesCopy['limit'] as num?) ?? 4).toInt(),
                            )
                            .toList(),
                        title:
                            (categoriesCopy['title'] ?? 'Hizmet Kategorileri')
                                .toString(),
                      ),

                    // "Öne Çıkan Profesyoneller" (paid placement) right under the categories.
                    if (sectionOn('spotlight')) const HomeSpotlightSection(),

                    if (sectionOn('services'))
                      servicesAsync.when(
                        data: (services) =>
                            HomeServicesSection(services: services),
                        loading: () => const HomeServicesSection(loading: true),
                        error: (_, _) => HomeServicesSection(
                          onRetry: () => ref.invalidate(homeServicesProvider),
                        ),
                      ),

                    // Verified providers (real data — same source as web)
                    if (sectionOn('providers'))
                      featuredAsync.when(
                        data: (providers) {
                          if (providers.isEmpty) return const SizedBox.shrink();
                          return VerifiedProvidersSection(providers: providers);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                    const HomeNearbyProvidersSection(),

                    // Yeni katılan profesyoneller (most recently approved).
                    if (sectionOn('newest')) const HomeNewestSection(),

                    // Platform statistics for customers (real or admin-typed).
                    if (sectionOn('stats')) const HomeStatsSection(audience: 'customer'),

                    // Nasıl çalışır? — site-config copy, shared with web
                    if (sectionOn('how_it_works'))
                      HomeHowItWorksSection(content: howItWorks),

                    // Verification / trust section (site-config, shared with web)
                    if (sectionOn('verification')) ...[
                      VerificationSection(
                        verification:
                            verificationAsync.asData?.value ?? const {},
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (sectionOn('provider_cta'))
                      HomeFinalCta(
                        onSelect: openAppointment,
                      ),
                    const SizedBox(height: 24),
                    if (sectionOn('app_download')) ...[
                      AppDownloadSection(siteConfig: siteConfig),
                      const SizedBox(height: 24),
                    ],
                    // Quick stats summary
                    requestsAsync.when(
                      data: (requests) {
                        final active = requests.where((r) => r.isActive).length;
                        final total = requests.length;
                        return Row(
                          children: [
                            _StatCard(
                              label: 'Aktif Talep',
                              value: '$active',
                              color: active > 0
                                  ? AppTheme.primary
                                  : AppTheme.slate500,
                              icon: Icons.flash_on_rounded,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'Toplam Talep',
                              value: '$total',
                              color: AppTheme.slate600,
                              icon: Icons.history_rounded,
                            ),
                          ],
                        );
                      },
                      loading: () => const LoadingState(height: 68),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // Active instant request banner
                    requestsAsync.when(
                      data: (requests) {
                        final active = requests
                            .where((r) => r.isActive)
                            .toList();
                        if (active.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Aktif Talepler'),
                            const SizedBox(height: 4),
                            ...active.map(
                              (r) => _ActiveRequestBanner(request: r),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    // Upcoming appointment card if any
                    appointmentsAsync.when(
                      data: (appointments) {
                        final upcoming =
                            appointments
                                .where(
                                  (a) =>
                                      a.isConfirmed || a.isAlternativeProposed,
                                )
                                .where(
                                  (a) =>
                                      DateTime.tryParse(
                                        '${a.appointmentDate.split('T').first}T${a.startTime}+03:00',
                                      )?.isAfter(DateTime.now()) ??
                                      false,
                                )
                                .toList()
                              ..sort(
                                (a, b) => '${a.appointmentDate} ${a.startTime}'
                                    .compareTo(
                                      '${b.appointmentDate} ${b.startTime}',
                                    ),
                              );
                        if (upcoming.isEmpty) return const SizedBox.shrink();
                        final nextAppt = upcoming.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Yaklaşan Randevu'),
                            const SizedBox(height: 4),
                            _UpcomingAppointmentCard(appointment: nextAppt),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusMedium,
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRequestBanner extends StatelessWidget {
  final ServiceRequestModel request;

  const _ActiveRequestBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestTrackingScreen(requestId: request.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusMedium,
          border: Border.all(color: AppTheme.primaryBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                request.services.isNotEmpty
                    ? request.services.map((s) => s.name).join(', ')
                    : 'Talep #${request.id}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            StatusBadge(status: request.status, isSmall: true),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.slate400,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointmentCard extends StatelessWidget {
  final CustomerAppointmentModel appointment;

  const _UpcomingAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CustomerAppointmentDetailScreen(appointmentId: appointment.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusMedium,
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.infoLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.info,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProviderNameRow(
                    name: appointment.provider?.displayName ??
                        'Randevu #${appointment.id}',
                    verified: appointment.provider?.isVerified == true,
                    tickSize: 15,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${appointment.appointmentDate} • ${appointment.startTime}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: appointment.status, isSmall: true),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.slate400,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickActionCard extends StatelessWidget {
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool iconBgCircle;
  final double iconBoxSize;
  final double iconSize;
  final double iconTextGap;
  final String title;
  final Color titleColor;
  final double titleSize;
  final String subtitle;
  final Color subtitleColor;
  final double subtitleSize;

  const _HomeQuickActionCard({
    super.key,
    required this.onTap,
    required this.padding,
    required this.backgroundColor,
    this.border,
    this.boxShadow,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBgCircle,
    required this.iconBoxSize,
    required this.iconSize,
    required this.iconTextGap,
    required this.title,
    required this.titleColor,
    required this.titleSize,
    required this.subtitle,
    required this.subtitleColor,
    required this.subtitleSize,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: iconBgCircle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius:
                        iconBgCircle ? null : BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: iconTextGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: titleColor,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: subtitleColor,
                fontSize: subtitleSize,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
