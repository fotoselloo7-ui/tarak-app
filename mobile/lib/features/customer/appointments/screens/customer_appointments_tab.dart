import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../models/customer_appointment_model.dart';
import '../providers/customer_appointment_providers.dart';
import 'create_appointment_screen.dart';
import 'customer_appointment_detail_screen.dart';
import '../../../../core/widgets/verified_tick.dart';

class CustomerAppointmentsTab extends ConsumerStatefulWidget {
  const CustomerAppointmentsTab({super.key});

  @override
  ConsumerState<CustomerAppointmentsTab> createState() =>
      _CustomerAppointmentsTabState();
}

class _CustomerAppointmentsTabState
    extends ConsumerState<CustomerAppointmentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(customerAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Randevularım'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.slate200)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.slate500,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Aktif Randevular'),
                Tab(text: 'Geçmiş'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new_appointment_fab'),
        onPressed: () {
          ref.read(appointmentWizardProvider.notifier).reset();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateAppointmentScreen()),
          ).then((_) {
            ref.read(customerAppointmentsProvider.notifier).refresh();
          });
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Yeni Randevu',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (err, _) => ErrorState(
          message: 'Randevular yüklenemedi: $err',
          onRetry: () => ref.read(customerAppointmentsProvider.notifier).refresh(),
        ),
        data: (appointments) {
          final activeAppointments = appointments.where((a) => !a.isFinal).toList();
          final pastAppointments = appointments.where((a) => a.isFinal).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(context, activeAppointments, isActive: true),
              _buildList(context, pastAppointments, isActive: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<CustomerAppointmentModel> list, {
    required bool isActive,
  }) {
    if (list.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await ref.read(customerAppointmentsProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.calendar_today_outlined : Icons.history_rounded,
                        size: 32,
                        color: AppTheme.slate400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isActive
                          ? 'Aktif planlı randevunuz bulunmuyor.'
                          : 'Geçmiş randevunuz bulunmuyor.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        key: const Key('empty_state_new_appointment_btn'),
                        onPressed: () {
                          ref.read(appointmentWizardProvider.notifier).reset();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAppointmentScreen(),
                            ),
                          ).then((_) {
                            ref.read(customerAppointmentsProvider.notifier).refresh();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusButton,
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Randevu Al',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await ref.read(customerAppointmentsProvider.notifier).refresh();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final appt = list[index];
          return _AppointmentCard(
            key: Key('appointment_card_${appt.id}'),
            appointment: appt,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerAppointmentDetailScreen(appointmentId: appt.id),
                ),
              ).then((_) {
                ref.read(customerAppointmentsProvider.notifier).refresh();
              });
            },
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final CustomerAppointmentModel appointment;
  final VoidCallback onTap;

  const _AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusCard,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        AppAvatar(
                          name: appointment.provider?.displayName ?? 'Hizmet Veren',
                          imageUrl: appointment.provider?.avatarUrl,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProviderNameRow(
                                name: appointment.provider?.displayName ?? 'Hizmet Veren',
                                verified: appointment.provider?.isVerified == true,
                                tickSize: 16,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                appointment.publicId,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    status: appointment.status,
                    customLabel: appointment.statusLabel,
                    isSmall: true,
                  ),
                ],
              ),
              const Divider(height: 20, color: AppTheme.slate100),
              Row(
                children: [
                  const Icon(Icons.content_cut_rounded, size: 15, color: AppTheme.slate500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appointment.servicesSummary,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₺${appointment.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_rounded, size: 15, color: AppTheme.slate500),
                  const SizedBox(width: 6),
                  Text(
                    '${appointment.appointmentDate} ${appointment.startTime} - ${appointment.endTime}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.slate500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      appointment.paymentMethod == 'CASH' ? 'Nakit' : 'Online',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate600,
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
