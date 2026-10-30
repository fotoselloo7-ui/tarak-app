import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../models/provider_appointment_model.dart';
import '../providers/provider_appointment_providers.dart';
import 'provider_appointment_detail_screen.dart';
import 'provider_schedule_screen.dart';

class ProviderAppointmentsTab extends ConsumerStatefulWidget {
  const ProviderAppointmentsTab({super.key});

  @override
  ConsumerState<ProviderAppointmentsTab> createState() =>
      _ProviderAppointmentsTabState();
}

class _ProviderAppointmentsTabState
    extends ConsumerState<ProviderAppointmentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = ref.watch(providerPendingAppointmentsProvider);
    final upcomingList = ref.watch(providerUpcomingAppointmentsProvider);
    final historyList = ref.watch(providerHistoryAppointmentsProvider);
    final allAsync = ref.watch(providerAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Randevularım',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.slate500,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('Gelen Talepler'),
                  if (pendingList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Aktif'),
            const Tab(text: 'Geçmiş'),
            const Tab(text: 'Çalışma Takvimi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentList(
            list: pendingList,
            isLoading: allAsync.isLoading,
            emptyMessage: 'Bekleyen randevu talebi bulunmuyor.',
            onRefresh: () =>
                ref.read(providerAppointmentsProvider.notifier).refresh(),
          ),
          _buildAppointmentList(
            list: upcomingList,
            isLoading: allAsync.isLoading,
            emptyMessage: 'Onaylı veya devam eden randevunuz bulunmuyor.',
            onRefresh: () =>
                ref.read(providerAppointmentsProvider.notifier).refresh(),
          ),
          _buildAppointmentList(
            list: historyList,
            isLoading: allAsync.isLoading,
            emptyMessage: 'Geçmiş randevu kaydı bulunmuyor.',
            onRefresh: () =>
                ref.read(providerAppointmentsProvider.notifier).refresh(),
          ),
          const ProviderScheduleScreen(),
        ],
      ),
    );
  }

  Widget _buildAppointmentList({
    required List<ProviderAppointmentModel> list,
    required bool isLoading,
    required String emptyMessage,
    required Future<void> Function() onRefresh,
  }) {
    if (isLoading && list.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5722)),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_note, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        emptyMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final appt = list[index];
                return _buildAppointmentCard(appt);
              },
            ),
    );
  }

  Widget _buildAppointmentCard(ProviderAppointmentModel appt) {
    return Card(
      key: Key('appointment_card_${appt.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProviderAppointmentDetailScreen(appointmentId: appt.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Public ID + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    appt.publicId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: appt.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      appt.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: appt.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Customer name & approx location (NO phone, email, exact address)
              Row(
                children: [
                  AppAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFE2E8F0),
                    imageUrl: appt.customer?.avatarUrl,
                    name: appt.customer?.name ?? 'Müşteri',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.customer?.name ?? 'Müşteri',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (appt.approxLocation != null &&
                            appt.approxLocation!.isNotEmpty)
                          Text(
                            appt.approxLocation!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '₺${appt.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5722),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Date, Time & Payment
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${appt.appointmentDate}  ${appt.startTime}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: appt.isCash
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      appt.isCash ? 'Nakit' : 'Online',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: appt.isCash
                            ? const Color(0xFF059669)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
