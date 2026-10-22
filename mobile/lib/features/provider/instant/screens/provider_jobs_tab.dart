import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/models/service_offer.dart';
import '../../../customer/models/service_request_model.dart';
import '../../../offerings/models/offering_models.dart';
import '../providers/provider_instant_providers.dart';
import 'provider_job_detail_screen.dart';
import 'provider_request_detail_screen.dart';

class ProviderJobsTab extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const ProviderJobsTab({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<ProviderJobsTab> createState() => _ProviderJobsTabState();
}

class _ProviderJobsTabState extends ConsumerState<ProviderJobsTab> {
  late int _selectedFilterIndex;
  Timer? _marketplacePollingTimer;

  @override
  void initState() {
    super.initState();
    _selectedFilterIndex = widget.initialTabIndex;
    _startMarketplacePolling();
  }

  void _startMarketplacePolling() {
    _marketplacePollingTimer?.cancel();
    _marketplacePollingTimer =
        Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted) return;
      final profile =
          ref.read(providerProfileNotifierProvider).value;
      if (profile != null && profile.isOnline && _selectedFilterIndex == 0) {
        ref.invalidate(providerMarketplaceRequestsProvider);
      }
    });
  }

  @override
  void dispose() {
    _marketplacePollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(providerProfileNotifierProvider);
    final isOnline = profileAsync.value?.isOnline ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'İşler ve Talepler',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.slate900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(0, 'Uygun Talepler'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Tekliflerim'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Aktif İş'),
                const SizedBox(width: 8),
                _buildFilterChip(3, 'Geçmiş'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(isOnline),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.slate100,
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.slate200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: isSelected ? Colors.white : AppTheme.slate700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      onSelected: (sel) {
        if (sel) setState(() => _selectedFilterIndex = index);
      },
    );
  }

  Widget _buildBody(bool isOnline) {
    switch (_selectedFilterIndex) {
      case 0:
        return _buildMarketplaceSection(isOnline);
      case 1:
        return _buildMyOffersSection();
      case 2:
        return _buildActiveJobSection();
      case 3:
        return _buildHistorySection();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── 0. Marketplace Requests (Uygun Talepler) ─────────────────────────────
  Widget _buildMarketplaceSection(bool isOnline) {
    if (!isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.power_settings_new, size: 40, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Şu Anda Çevrimdışısınız',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni marketplace taleplerini görebilmek ve teklif verebilmek için çevrimiçi olmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final notifier = ref.read(providerProfileNotifierProvider.notifier);
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await notifier.setOnline(true);
                  if (!ok) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          notifier.lastOnlineError ?? 'Hizmet durumu güncellenemedi.',
                        ),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.flash_on),
                label: const Text('Çevrimiçi Ol'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final requestsAsync = ref.watch(providerMarketplaceRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text('Talepler yüklenemedi: $err', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.refresh(providerMarketplaceRequestsProvider),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(providerMarketplaceRequestsProvider),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text(
                        'Şu anda bölgenizde uygun talep bulunmuyor.',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Yeni talep geldiğinde burada listelenecektir.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(providerMarketplaceRequestsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return _buildMarketplaceCard(req);
            },
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(ServiceRequestModel req) {
    // Approximate area only
    final approxArea = [
      req.approxNeighborhood,
      req.approxDistrict,
      req.approxProvince,
    ].where((String? s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: req.isDirect ? const Color(0xFFFF5722) : const Color(0xFFE2E8F0),
          width: req.isDirect ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: req.isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req.isOnline ? 'Online Ödeme' : 'Nakit Ödeme',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: req.isOnline ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                  ),
                ),
              ),
              if (req.isDirect) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFF5722), borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'Size Özel',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
              const Spacer(),
              if (req.distanceKm != null)
                Text(
                  '~${req.distanceKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            req.offering != null
                ? '${req.offering!.title} • ${formatTry(req.offering!.price)} • ${req.offering!.durationMinutes} dk'
                : req.services.map((s) => s.name).join(', '),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  approxArea.isNotEmpty ? approxArea : (req.locationText ?? 'Bölge Belirtilmedi'),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          if (req.customerNote != null && req.customerNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Not: "${req.customerNote!}"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderRequestDetailScreen(requestId: req.id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(req.isDirect ? 'İncele ve Yanıtla' : 'İncele ve Teklif Ver', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. My Offers (Tekliflerim) ────────────────────────────────────────────
  Widget _buildMyOffersSection() {
    final offersAsync = ref.watch(providerMyOffersProvider);

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text('Teklifler yüklenemedi: $err', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(providerMyOffersProvider.notifier).refresh(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
      data: (offers) {
        if (offers.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.read(providerMyOffersProvider.notifier).refresh(),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.local_offer_outlined, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text(
                        'Henüz verdiğiniz bir teklif bulunmuyor.',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.read(providerMyOffersProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return _buildOfferCard(offer);
            },
          ),
        );
      },
    );
  }

  Widget _buildOfferCard(ServiceOffer offer) {
    Color statusBg;
    Color statusFg;
    String statusLabel;

    if (offer.status == 'ACCEPTED') {
      statusBg = const Color(0xFFF0FDF4);
      statusFg = const Color(0xFF16A34A);
      statusLabel = 'Kabul Edildi';
    } else if (offer.status == 'REJECTED') {
      statusBg = const Color(0xFFFEF2F2);
      statusFg = const Color(0xFFDC2626);
      statusLabel = 'Reddedildi';
    } else {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF2563EB);
      statusLabel = 'Bekliyor';
    }

    final serviceText = offer.serviceRequest != null
        ? offer.serviceRequest!.services.map((s) => s.name).join(', ')
        : 'Talep #${offer.serviceRequestId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Talep #${offer.serviceRequestId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            serviceText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₺${offer.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5722),
                ),
              ),
              if (offer.estimatedArrivalMin != null) ...[
                const SizedBox(width: 12),
                Text(
                  'Varış: ${offer.estimatedArrivalMin} dk',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
          if (offer.isAccepted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProviderJobDetailScreen(requestId: offer.serviceRequestId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('İş Detayını Görüntüle', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 2. Active Job (Aktif İş) ──────────────────────────────────────────────
  Widget _buildActiveJobSection() {
    final assignedAsync = ref.watch(providerAssignedRequestsProvider);

    return assignedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Yüklenemedi: $err'),
      ),
      data: (jobs) {
        final activeJobs = jobs
            .where((j) => j.isAssigned || j.isInProgress || j.isAwaitingConfirmation)
            .toList();

        if (activeJobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.read(providerAssignedRequestsProvider.notifier).refresh(),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text(
                        'Şu anda devam eden aktif bir işiniz bulunmuyor.',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.read(providerAssignedRequestsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeJobs.length,
            itemBuilder: (context, index) {
              final job = activeJobs[index];
              return _buildActiveJobCard(job);
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveJobCard(ServiceRequestModel job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'İş #${job.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.statusLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.services.map((s) => s.name).join(', '),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (job.locationText != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(job.locationText!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderJobDetailScreen(requestId: job.id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yönet ve Detayları Gör', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. History (Geçmiş) ───────────────────────────────────────────────────
  Widget _buildHistorySection() {
    final assignedAsync = ref.watch(providerAssignedRequestsProvider);

    return assignedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Yüklenemedi: $err')),
      data: (jobs) {
        final pastJobs = jobs
            .where((j) => j.isCompleted || j.isDisputed || j.isCancelled)
            .toList();

        if (pastJobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.read(providerAssignedRequestsProvider.notifier).refresh(),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text(
                        'Geçmiş bir iş kaydınız bulunmuyor.',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.read(providerAssignedRequestsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pastJobs.length,
            itemBuilder: (context, index) {
              final job = pastJobs[index];
              return _buildHistoryCard(job);
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(ServiceRequestModel job) {
    Color badgeBg;
    Color badgeFg;
    if (job.isCompleted) {
      badgeBg = const Color(0xFFF0FDF4);
      badgeFg = const Color(0xFF16A34A);
    } else if (job.isDisputed) {
      badgeBg = const Color(0xFFFEF2F2);
      badgeFg = const Color(0xFFDC2626);
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeFg = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('İş #${job.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.services.map((s) => s.name).join(', '),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          if (job.completedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Tamamlanma: ${job.completedAt!.day}.${job.completedAt!.month}.${job.completedAt!.year}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderJobDetailScreen(requestId: job.id),
                  ),
                );
              },
              child: const Text('Detayları Gör'),
            ),
          ),
        ],
      ),
    );
  }
}
