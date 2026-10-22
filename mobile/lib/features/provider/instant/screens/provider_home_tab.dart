import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../customer/models/service_request_model.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/view_mode_switch.dart';
import '../../../notifications/screens/notification_center_screen.dart';
import '../../../customer/screens/home_promoted_sections.dart';
import '../../screens/provider_customer_view_screen.dart';
import '../../screens/provider_featured_screen.dart';
import '../models/provider_profile_model.dart';
import '../providers/provider_instant_providers.dart';
import 'provider_job_detail_screen.dart';

class ProviderHomeTab extends ConsumerWidget {
  final VoidCallback? onNavigateToJobs;

  const ProviderHomeTab({
    super.key,
    this.onNavigateToJobs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(providerProfileNotifierProvider);
    final marketplaceAsync = ref.watch(providerMarketplaceRequestsProvider);
    final assignedAsync = ref.watch(providerAssignedRequestsProvider);
    final offersAsync = ref.watch(providerMyOffersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        // Official Tarak wordmark; the role is a small secondary label so the
        // brand itself is never rendered as text.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            TarakLogo(height: 26),
            SizedBox(width: 8),
            Text(
              'Usta',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.slate500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          const NotificationCenterButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(providerProfileNotifierProvider.notifier).refresh();
              ref.invalidate(providerMarketplaceRequestsProvider);
              ref.read(providerAssignedRequestsProvider.notifier).refresh();
              ref.read(providerMyOffersProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await ref.read(providerProfileNotifierProvider.notifier).refresh();
          ref.invalidate(providerMarketplaceRequestsProvider);
          await ref.read(providerAssignedRequestsProvider.notifier).refresh();
          await ref.read(providerMyOffersProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Same account, two views: the panel (this screen) and the platform the way a customer sees it.
            Align(
              alignment: Alignment.centerLeft,
              child: ProviderViewModeSwitch(
                customer: false,
                onChanged: (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProviderCustomerViewScreen())),
              ),
            ),
            const SizedBox(height: 14),

            // ── 1. Online / Offline Status Toggle Card ───────────────────
            profileAsync.when(
              loading: () => const LoadingState(height: 100),
              error: (err, _) => ErrorState(
                message: 'Profil bilgisi yüklenemedi.',
                onRetry: () =>
                    ref.read(providerProfileNotifierProvider.notifier).refresh(),
              ),
              data: (profile) => _OnlineStatusCard(profile: profile),
            ),

            const SizedBox(height: 16),

            // ── 2. Active Job Alert Card (If any active assigned job) ────
            assignedAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
              data: (jobs) {
                final activeJob = jobs.cast<ServiceRequestModel?>().firstWhere(
                      (j) =>
                          j != null &&
                          (j.isAssigned || j.isInProgress || j.isAwaitingConfirmation),
                      orElse: () => null,
                    );

                if (activeJob == null) return const SizedBox.shrink();

                return Column(
                  children: [
                    _ActiveJobBanner(
                      job: activeJob,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProviderJobDetailScreen(requestId: activeJob.id),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // ── 3. Real Backend Metrics Summary (NO FAKE KPIS) ───────────
            const SectionHeader(title: 'Güncel Durum'),
            const SizedBox(height: 4),

            Row(
              children: [
                // Available Marketplace Requests
                Expanded(
                  child: _MetricCard(
                    title: 'Uygun Talepler',
                    value: marketplaceAsync.when(
                      data: (list) => '${list.length}',
                      loading: () => '...',
                      error: (err, stack) => '0',
                    ),
                    subtitle: profileAsync.value?.isOnline == false
                        ? 'Çevrimdışısınız'
                        : 'Hemen Çağır',
                    icon: Icons.flash_on_rounded,
                    iconColor: AppTheme.primary,
                    onTap: onNavigateToJobs,
                  ),
                ),
                const SizedBox(width: 12),
                // Pending Offers Count
                Expanded(
                  child: _MetricCard(
                    title: 'Tekliflerim',
                    value: offersAsync.when(
                      data: (list) => '${list.where((o) => o.isPending).length}',
                      loading: () => '...',
                      error: (err, stack) => '0',
                    ),
                    subtitle: 'Bekleyen Teklif',
                    icon: Icons.local_offer_rounded,
                    iconColor: AppTheme.info,
                    onTap: onNavigateToJobs,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── 4. Quick Navigation Card ────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.radiusCard,
                border: Border.all(color: AppTheme.slate200),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: AppTheme.radiusCard,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.work_outline_rounded, color: AppTheme.primary, size: 22),
                  ),
                  title: const Text(
                    'İşler ve Talepler',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Marketplace talepleri, teklifler ve devam eden işler',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
                  onTap: onNavigateToJobs,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 5. Öne çıkar (paid placement) ───────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFFBEB), Color(0xFFFFF1E6)]),
                borderRadius: AppTheme.radiusCard,
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: AppTheme.radiusCard,
                child: ListTile(
                  key: const Key('provider_featured_entry'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  ),
                  title: const Text(
                    'Profilini öne çıkar',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Ana sayfa vitrinine ve hizmet veren listelerinin en üstüne reklam ver; daha fazla müşteri görsün.',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProviderFeaturedScreen())),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Platform statistics for providers (real or admin-typed)
            const HomeStatsSection(audience: 'provider'),
          ],
        ),
      ),
    );
  }
}

class _OnlineStatusCard extends ConsumerStatefulWidget {
  final ProviderProfileModel profile;

  const _OnlineStatusCard({required this.profile});

  @override
  ConsumerState<_OnlineStatusCard> createState() => _OnlineStatusCardState();
}

class _OnlineStatusCardState extends ConsumerState<_OnlineStatusCard> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.profile.isOnline;
    final isApproved = widget.profile.canWork;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.successLight : Colors.white,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(
          color: isOnline ? const Color(0xFF86EFAC) : AppTheme.slate200,
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppTheme.success : AppTheme.slate400,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Şu Anda Çevrimiçi' : 'Şu Anda Çevrimdışı',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isOnline ? const Color(0xFF15803D) : AppTheme.slate700,
                ),
              ),
              const Spacer(),
              if (_isSwitching)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                )
              else
                Switch(
                  value: isOnline,
                  activeTrackColor: AppTheme.success,
                  activeThumbColor: Colors.white,
                  onChanged: !isApproved
                      ? null
                      : (val) async {
                          setState(() => _isSwitching = true);
                          final notifier = ref.read(
                            providerProfileNotifierProvider.notifier,
                          );
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await notifier.setOnline(val);
                          if (mounted) {
                            setState(() => _isSwitching = false);
                          }
                          if (!ok) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  notifier.lastOnlineError ??
                                      'Hizmet durumu güncellenemedi.',
                                ),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            !isApproved
                ? 'Hesabınız henüz onaylanmadığı için çevrimiçi olamazsınız.'
                : isOnline
                    ? 'Yeni Hemen Çağır talepleri için hazırsınız.'
                    : 'Çevrimdışıyken yeni marketplace taleplerini alamazsınız.',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: AppTheme.slate600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveJobBanner extends StatelessWidget {
  final ServiceRequestModel job;
  final VoidCallback onTap;

  const _ActiveJobBanner({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radiusCard,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(color: AppTheme.info, width: 1.2),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: AppTheme.info, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Aktif İşiniz Var',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.info,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                StatusBadge(status: job.status, isSmall: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.services.map((s) => s.name).join(', '),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            if (job.locationText != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.slate400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.locationText!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppTheme.slate500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'İş Detayına Git',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.info,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.info),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radiusCard,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Icon(icon, size: 18, color: iconColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: AppTheme.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
