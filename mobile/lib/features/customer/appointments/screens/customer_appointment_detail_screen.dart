import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/tarak_rating.dart';

import '../models/customer_appointment_model.dart';
import '../providers/customer_appointment_providers.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../../chat/screens/chat_screen.dart';
import '../../payment/screens/paytr_payment_screen.dart';
import '../../../shared/widgets/account_sheets.dart';
import '../../../../core/widgets/verified_tick.dart';

class CustomerAppointmentDetailScreen extends ConsumerStatefulWidget {
  final int appointmentId;

  const CustomerAppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<CustomerAppointmentDetailScreen> createState() =>
      _CustomerAppointmentDetailScreenState();
}

class _CustomerAppointmentDetailScreenState
    extends ConsumerState<CustomerAppointmentDetailScreen>
    with WidgetsBindingObserver {
  int? _selectedAlternativeSlotId;
  late final CustomerAppointmentDetailNotifier _detailNotifier;

  @override
  void initState() {
    super.initState();
    _detailNotifier = ref.read(
      customerAppointmentDetailNotifierProvider(widget.appointmentId).notifier,
    );
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        _detailNotifier.startPolling();
        _detailNotifier.loadDetail();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detailNotifier.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      final notifier = ref.read(
        customerAppointmentDetailNotifierProvider(widget.appointmentId)
            .notifier,
      );
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        notifier.stopPolling();
      } else if (state == AppLifecycleState.resumed) {
        final appt = ref
            .read(
              customerAppointmentDetailNotifierProvider(widget.appointmentId),
            )
            .appointment;
        if (appt != null && !appt.isFinal) {
          notifier.startPolling();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      customerAppointmentDetailNotifierProvider(widget.appointmentId),
    );
    final notifier = ref.read(
      customerAppointmentDetailNotifierProvider(widget.appointmentId).notifier,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          state.appointment != null
              ? state.appointment!.publicId
              : 'Randevu Detayı',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: () => notifier.loadDetail(),
          ),
        ],
      ),
      body: state.isLoading && state.appointment == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5722)),
            )
          : state.errorMessage != null && state.appointment == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Randevu bilgileri alınamadı:\n${state.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => notifier.loadDetail(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                      ),
                      child: const Text(
                        'Tekrar Dene',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : state.appointment == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              color: const Color(0xFFFF5722),
              onRefresh: () => notifier.loadDetail(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildStatusBanner(state.appointment!),
                    const SizedBox(height: 16),
                    _buildProviderCard(context, state.appointment!),
                    const SizedBox(height: 16),
                    _buildDateTimeAndAddressCard(state.appointment!),
                    const SizedBox(height: 16),
                    _buildServicesCard(state.appointment!),
                    const SizedBox(height: 16),
                    // Status-dependent contextual cards
                    if (state.appointment!.isAlternativeProposed)
                      _buildAlternativesSection(
                        state.appointment!,
                        notifier,
                        state,
                      ),
                    if (state.appointment!.isOnlinePending)
                      _buildOnlinePaymentPendingCard(
                        state.appointment!,
                        notifier,
                      ),
                    // New shares and the start code belong to CONFIRMED; once IN_PROGRESS the
                    // code is consumed and an active share can only be stopped.
                    if (state.appointment!.isFinanciallyReady &&
                        (state.appointment!.isConfirmed ||
                            (state.appointment!.isInProgress &&
                                state.locationStatus?.isShared == true))) ...[
                      _buildLocationShareCard(
                        state,
                        notifier,
                        state.appointment!,
                      ),
                    ],
                    if (state.appointment!.isFinanciallyReady &&
                        state.appointment!.isConfirmed) ...[
                      const SizedBox(height: 16),
                      _buildStartCodeCard(state, notifier),
                    ],
                    if (state.appointment!.isAwaitingConfirmation)
                      _buildAwaitingConfirmationCard(notifier, state),
                    if (state.appointment!.isDisputed)
                      _buildDisputeSummaryCard(state.appointment!),
                    if (state.appointment!.hasRefund ||
                        (state.appointment!.isDisputed &&
                            state.appointment!.isOnline &&
                            state.appointment!.paymentSummary?.refundSummary !=
                                null)) ...[
                      const SizedBox(height: 16),
                      _buildRefundSummaryCard(state.appointment!),
                    ],
                    const SizedBox(height: 24),
                    _buildCancelButtonIfEligible(
                      state.appointment!,
                      notifier,
                      state,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Status Banner ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner(CustomerAppointmentModel appointment) {
    Color bg;
    Color fg;
    IconData icon;
    String title = appointment.statusLabel;
    String subtitle;

    switch (appointment.status) {
      case 'PENDING':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFC2410C);
        icon = Icons.hourglass_top;
        subtitle = 'Randevu talebiniz hizmet verenin onayını bekliyor.';
        break;
      case 'CONFIRMED':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF15803D);
        icon = Icons.check_circle_outline;
        subtitle =
            appointment.paymentMethod == 'ONLINE' &&
                appointment.paymentSummary?.status == 'PENDING'
            ? 'Randevunuz onaylandı, online ödeme bekleniyor.'
            : 'Randevunuz onaylandı. Belirlenen saatte hazır olunuz.';
        break;
      case 'ALTERNATIVE_PROPOSED':
        bg = const Color(0xFFFAF5FF);
        fg = const Color(0xFF7E22CE);
        icon = Icons.schedule;
        subtitle =
            'Hizmet veren yeni saatler önerdi. Lütfen birini seçip onaylayın.';
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        icon = Icons.handshake_outlined;
        subtitle = 'Hizmet şu anda verilmektedir.';
        break;
      case 'AWAITING_CUSTOMER_CONFIRMATION':
        bg = const Color(0xFFF0FDFA);
        fg = const Color(0xFF0F766E);
        icon = Icons.task_alt;
        subtitle = 'Hizmet veren işlemi tamamladı. Lütfen onaylayın veya sorun bildirin.';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF166534);
        icon = Icons.verified;
        subtitle = 'Randevu başarıyla tamamlandı.';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_outlined;
        subtitle = appointment.rejectionReason != null
            ? 'Gerekçe: ${appointment.rejectionReason}'
            : 'Hizmet veren randevuyu uygun olmadığı için kabul edemedi.';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.block;
        subtitle = 'Bu randevu iptal edildi.';
        break;
      case 'DISPUTED':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        icon = Icons.report_problem_outlined;
        subtitle = appointment.disputeReason != null
            ? 'Şikayet nedeni: ${appointment.disputeReason}'
            : 'Randevu için inceleme süreci başlatıldı.';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.info_outline;
        subtitle = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: fg.withOpacity(0.85)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Provider Card ──────────────────────────────────────────────────────────

  Widget _buildProviderCard(
    BuildContext context,
    CustomerAppointmentModel appointment,
  ) {
    final provider = appointment.provider;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFFFECE5),
                  backgroundImage: provider?.avatarUrl != null
                      ? NetworkImage(provider!.avatarUrl!)
                      : null,
                  child: provider?.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFFFF5722),
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
                          Flexible(
                            child: Text(
                              provider?.displayName ?? 'Hizmet Veren',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (provider?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            const VerifiedTick(size: 16),
                          ],
                        ],
                      ),
                      if (provider?.district != null ||
                          provider?.city != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            provider?.district,
                            provider?.city,
                          ].where((s) => s != null && s.isNotEmpty).join(', '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Chat button if confirmed/in progress
            if (appointment.isConfirmed || appointment.isInProgress) ...[
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('appointment_chat_btn'),
                  onPressed: () async {
                    try {
                      final repo = ref.read(chatRepositoryProvider);
                      final convId = await repo
                          .getConversationForCustomerAppointment(
                            widget.appointmentId,
                          );
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: convId,
                            otherPartyName:
                                appointment.provider?.businessName ??
                                appointment.provider?.name ??
                                'Uzman',
                            otherPartyVerified: appointment.provider?.isVerified == true,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: Color(0xFFFF5722),
                  ),
                  label: const Text(
                    'Mesaj Gönder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5722),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF5722)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            // Leave a review after a completed appointment
            if (appointment.status == 'COMPLETED' && appointment.hasReview) ...[
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              const Text(
                'Bu randevuyu değerlendirdiniz. Teşekkürler!',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF047857)),
              ),
            ],
            if (appointment.status == 'COMPLETED' && !appointment.hasReview) ...[
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final reviewed = await showLeaveReviewSheet(
                      context,
                      appointmentId: widget.appointmentId,
                      providerName:
                          appointment.provider?.businessName ??
                          appointment.provider?.name,
                    );
                    // Reload so the server-side has_review flag swaps the CTA.
                    if (reviewed == true && mounted) _detailNotifier.loadDetail();
                  },
                  icon: const TarakMark(size: 22),
                  label: const Text(
                    'Değerlendir',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── DateTime & Address Card ────────────────────────────────────────────────

  Widget _buildDateTimeAndAddressCard(CustomerAppointmentModel appointment) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: Color(0xFFFF5722), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tarih & Saat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '${appointment.appointmentDate}   ${appointment.startTime} - ${appointment.endTime}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFFFF5722),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adres Bilgisi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        appointment.formattedAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (appointment.customerNote != null &&
                appointment.customerNote!.isNotEmpty) ...[
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Müşteri Notu',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          appointment.customerNote!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Services Card ──────────────────────────────────────────────────────────

  Widget _buildServicesCard(CustomerAppointmentModel appointment) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hizmetler & Ödeme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            if (appointment.offering?.isPackage == true) ...[
              Text(
                appointment.offering!.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (appointment.offering!.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(appointment.offering!.description!),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: appointment.offering!.items
                    .map((name) => Chip(label: Text(name)))
                    .toList(),
              ),
            ] else
              ...appointment.services.map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${s.name} (${s.durationMinutesSnapshot} dk)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        '₺${s.priceSnapshot.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplam Tutar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      appointment.paymentMethod == 'CASH'
                          ? 'Nakit Ödeme'
                          : 'Online Ödeme',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₺${appointment.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Alternative Slots Section ──────────────────────────────────────────────

  Widget _buildAlternativesSection(
    CustomerAppointmentModel appointment,
    CustomerAppointmentDetailNotifier notifier,
    AppointmentDetailState state,
  ) {
    final pendingAlternatives = appointment.pendingAlternativeSlots;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route, color: Color(0xFF7E22CE)),
              SizedBox(width: 8),
              Text(
                'Önerilen Alternatif Saatler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF581C87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Hizmet veren talep ettiğiniz saat yerine aşağıdaki alternatifleri önerdi. Birini seçerek randevunuzu onaylayabilirsiniz:',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B21A8)),
          ),
          const SizedBox(height: 12),
          if (pendingAlternatives.isEmpty)
            const Text('Aktif alternatif saat bulunmuyor.')
          else
            ...pendingAlternatives.map((slot) {
              final isSelected = _selectedAlternativeSlotId == slot.id;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7E22CE)
                        : const Color(0xFFD8B4FE),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: RadioListTile<int>(
                    key: Key('alternative_slot_${slot.id}'),
                    value: slot.id,
                    groupValue: _selectedAlternativeSlotId,
                    activeColor: const Color(0xFF7E22CE),
                    title: Text(
                      '${slot.date}   ${slot.startTime} - ${slot.endTime}',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: const Color(0xFF3B0764),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _selectedAlternativeSlotId = val);
                    },
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('reject_alternatives_btn'),
                  onPressed: state.isActionLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Alternatifleri Reddet'),
                              content: const Text(
                                'Önerilen saatleri reddederseniz randevu talebiniz iptal edilecektir. Emin misiniz?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Vazgeç'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Reddet ve İptal Et',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notifier.rejectAlternative();
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF9333EA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reddet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9333EA),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('accept_alternative_btn'),
                  onPressed:
                      state.isActionLoading ||
                          _selectedAlternativeSlotId == null
                      ? null
                      : () async {
                          try {
                            await notifier.acceptAlternative(
                              _selectedAlternativeSlotId!,
                            );
                          } catch (_) {}
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E22CE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: state.isActionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kabul Et',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Online Payment Pending Card ────────────────────────────────────────────

  Widget _buildOnlinePaymentPendingCard(
    CustomerAppointmentModel appointment,
    CustomerAppointmentDetailNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment, color: Color(0xFFD97706), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Online Ödeme Bekleniyor',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hizmet başlangıç kodu ve konum paylaşımı, online ödeme güvenceye alındıktan sonra aktif olacaktır.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appointment.paymentSummary?.id != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('complete_payment_btn'),
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Ödemeyi Tamamla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final paymentId = appointment.paymentSummary!.id;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaytrPaymentScreen(
                        paymentId: paymentId,
                        grossAmount: appointment.totalPrice,
                        resourceTitle: 'Randevu: ${appointment.publicId}',
                        onPaymentSuccess: () {
                          notifier.loadDetail();
                        },
                      ),
                    ),
                  );
                  notifier.loadDetail();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Location Share Card ────────────────────────────────────────────────────

  Widget _buildLocationShareCard(
    AppointmentDetailState state,
    CustomerAppointmentDetailNotifier notifier,
    CustomerAppointmentModel appointment,
  ) {
    final status = state.locationStatus;
    final isShared = status?.isShared == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.share_location,
                      color: Color(0xFFFF5722),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Konum Paylaşımı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isShared
                        ? Colors.green.shade50
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status?.displayStatus ?? 'Paylaşılmadı',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isShared
                          ? Colors.green.shade700
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isShared ? 'Kayıtlı açık adresiniz hizmet verenle paylaşıldı.' : 'Hizmet verenin adresinizi görebilmesi için randevu günü konumunuzu paylaşabilirsiniz.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            if (!isShared)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('share_location_btn'),
                  onPressed: state.isActionLoading
                      ? null
                      : () async {
                          // Explicit consent dialog
                          final consent = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Adres Paylaşımı Onayı'),
                              content: const Text(
                                'Bu randevu için kayıtlı tam adresiniz, yalnızca ilgili hizmet verenle sınırlı süre paylaşılacaktır.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Vazgeç'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5722),
                                  ),
                                  child: const Text(
                                    'Onayla ve Paylaş',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (consent == true &&
                              appointment.customerAddressId != null) {
                            await notifier.shareLocation(
                              appointment.customerAddressId!,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.location_on,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Adresimi Hizmet Verenle Paylaş',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('revoke_location_btn'),
                  onPressed: state.isActionLoading
                      ? null
                      : () async {
                          await notifier.revokeLocation();
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.location_off,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Paylaşımı Durdur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Start Code Card ────────────────────────────────────────────────────────

  Widget _buildStartCodeCard(
    AppointmentDetailState state,
    CustomerAppointmentDetailNotifier notifier,
  ) {
    final code = state.startCode;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.password, color: Color(0xFFFF5722), size: 22),
                SizedBox(width: 8),
                Text(
                  'Hizmet Başlangıç Kodu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Hizmet veren adresinize ulaştığında bu kodu kendisine söyleyerek hizmeti başlatmasını sağlayın.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            if (code != null && code.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFF5722).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  code,
                  key: const Key('start_code_text'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFFFF5722),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                key: const Key('regenerate_start_code_btn'),
                onPressed: state.isActionLoading
                    ? null
                    : () async {
                        await notifier.regenerateStartCode();
                      },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Kodu Yenile'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Kod yükleniyor...',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Awaiting Confirmation Card ─────────────────────────────────────────────

  Widget _buildAwaitingConfirmationCard(
    CustomerAppointmentDetailNotifier notifier,
    AppointmentDetailState state,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Hizmet Tamamlandı Onayı',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF134E4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Hizmet veren işlemi tamamladığını bildirdi. Hizmeti aldığınızı onaylayabilir veya bir problem yaşandıysa sorun bildirebilirsiniz.',
            style: TextStyle(fontSize: 13, color: Color(0xFF115E59)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('report_problem_btn'),
                  onPressed: state.isActionLoading
                      ? null
                      : () => _showDisputeDialog(notifier),
                  icon: const Icon(
                    Icons.report_problem_outlined,
                    size: 16,
                    color: Colors.deepOrange,
                  ),
                  label: const Text(
                    'Sorun Bildir',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.deepOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('complete_appointment_btn'),
                  onPressed: state.isActionLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hizmeti Onayla'),
                              content: const Text(
                                'Hizmetin başarıyla tamamlandığını onaylıyor musunuz?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Vazgeç'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                  ),
                                  child: const Text(
                                    'Onayla',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notifier.completeAppointment();
                          }
                        },
                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                  label: const Text(
                    'Hizmeti Onayla',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog(CustomerAppointmentDetailNotifier notifier) {
    final reasonController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sorun Bildir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lütfen yaşadığınız sorunu kısaca belirtin:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dispute_reason_input'),
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Sorun Başlığı *',
                hintText: 'Örn: Hizmet kalitesi yetersiz',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dispute_note_input'),
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açıklama (İsteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            key: const Key('submit_dispute_btn'),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              await notifier.reportProblem(
                reason,
                note: noteController.text.trim().isNotEmpty
                    ? noteController.text.trim()
                    : null,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Dispute Summary Card ───────────────────────────────────────────────────

  Widget _buildDisputeSummaryCard(CustomerAppointmentModel appointment) {
    final summary = appointment.disputeSummary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  summary?.statusLabel ?? 'İnceleme Sürecinde',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
            if (appointment.disputeReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Bildirilen Sorun: ${appointment.disputeReason}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
              ),
            ],
            if (summary?.resolution != null) ...[
              const SizedBox(height: 8),
              Text(
                'Çözüm Kararı: ${summary!.resolution}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Refund Summary Card ───────────────────────────────────────────────────

  Widget _buildRefundSummaryCard(CustomerAppointmentModel appointment) {
    final refund = appointment.paymentSummary?.refundSummary;
    if (refund == null) return const SizedBox.shrink();

    Color bg;
    Color border;
    Color iconColor;
    IconData icon;

    if (refund.isCompleted) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      iconColor = const Color(0xFF16A34A);
      icon = Icons.check_circle_outline;
    } else if (refund.isFailed) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.error_outline;
    } else if (refund.isManualReview) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      iconColor = const Color(0xFFD97706);
      icon = Icons.shield_outlined;
    } else {
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      iconColor = const Color(0xFF2563EB);
      icon = Icons.sync;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'İade Durumu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    refund.displayStatusText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
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

  // ── Cancel Button ──────────────────────────────────────────────────────────

  Widget _buildCancelButtonIfEligible(
    CustomerAppointmentModel appointment,
    CustomerAppointmentDetailNotifier notifier,
    AppointmentDetailState state,
  ) {
    // Cancellation is eligible when PENDING, CONFIRMED, or ALTERNATIVE_PROPOSED
    final canCancel =
        appointment.isPending ||
        appointment.isConfirmed ||
        appointment.isAlternativeProposed;

    if (!canCancel) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        key: const Key('cancel_appointment_btn'),
        onPressed: state.isActionLoading
            ? null
            : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Randevuyu İptal Et'),
                    content: const Text(
                      'Bu randevuyu iptal etmek istediğinizden emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Vazgeç'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'İptal Et',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.cancelAppointment();
                }
              },
        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
        label: const Text(
          'Randevuyu İptal Et',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ),
    );
  }
}
