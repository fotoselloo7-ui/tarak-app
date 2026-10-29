import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../models/provider_appointment_model.dart';
import '../providers/provider_appointment_providers.dart';
import '../repositories/provider_appointment_repository.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../../chat/screens/chat_screen.dart';

class ProviderAppointmentDetailScreen extends ConsumerStatefulWidget {
  final int appointmentId;

  const ProviderAppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<ProviderAppointmentDetailScreen> createState() =>
      _ProviderAppointmentDetailScreenState();
}

class _ProviderAppointmentDetailScreenState
    extends ConsumerState<ProviderAppointmentDetailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _startCodeController = TextEditingController();
  late final ProviderAppointmentDetailNotifier _detailNotifier;

  @override
  void initState() {
    super.initState();
    _detailNotifier = ref.read(
      providerAppointmentDetailNotifierProvider(widget.appointmentId).notifier,
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
    _startCodeController.dispose();
    _detailNotifier.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      final notifier = ref.read(
        providerAppointmentDetailNotifierProvider(widget.appointmentId)
            .notifier,
      );
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        notifier.stopPolling();
      } else if (state == AppLifecycleState.resumed) {
        final appt = ref
            .read(
              providerAppointmentDetailNotifierProvider(widget.appointmentId),
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
      providerAppointmentDetailNotifierProvider(widget.appointmentId),
    );
    final notifier = ref.read(
      providerAppointmentDetailNotifierProvider(widget.appointmentId).notifier,
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
          : state.appointment == null
          ? Center(
              child: Text(
                state.errorMessage ?? 'Randevu bulunamadı.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => notifier.loadDetail(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Status Banner ──────────────────────────────────────────
                  _buildStatusBanner(state.appointment!),
                  const SizedBox(height: 16),

                  // ── Customer Safe Card ─────────────────────────────────────
                  _buildCustomerCard(state.appointment!),
                  const SizedBox(height: 16),

                  // ── Services & Price Card ──────────────────────────────────
                  _buildServicesCard(state.appointment!),
                  const SizedBox(height: 16),

                  // ── Location & Address Card ────────────────────────────────
                  _buildLocationCard(state.appointment!, state.sharedLocation),
                  const SizedBox(height: 16),

                  // ── Lifecycle Actions & Start Code ─────────────────────────
                  _buildLifecycleActionCard(state.appointment!, state),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner(ProviderAppointmentModel appt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appt.statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appt.statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appt.statusColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.statusLabel,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: appt.statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${appt.appointmentDate}   ${appt.startTime} - ${appt.endTime}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ödeme: ${appt.paymentMethod == "CASH" ? "Nakit" : "Online"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(ProviderAppointmentModel appt) {
    final customer = appt.customer;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Müşteri Bilgileri',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                AppAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE2E8F0),
                  imageUrl: customer?.avatarUrl,
                  name: customer?.name ?? 'Müşteri',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.name ?? 'Müşteri',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (appt.approxLocation != null &&
                          appt.approxLocation!.isNotEmpty)
                        Text(
                          appt.approxLocation!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (appt.customerNote != null && appt.customerNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appt.customerNote!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (appt.isConfirmed ||
                appt.isInProgress ||
                appt.isAwaitingConfirmation) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('provider_appointment_chat_btn'),
                  onPressed: () async {
                    try {
                      final repo = ref.read(chatRepositoryProvider);
                      final convId = await repo
                          .getConversationForProviderAppointment(
                            widget.appointmentId,
                          );
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: convId,
                            otherPartyName: customer?.name ?? 'Müşteri',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
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
                    'Müşteriye Mesaj Gönder',
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
          ],
        ),
      ),
    );
  }

  Widget _buildServicesCard(ProviderAppointmentModel appt) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  appt.offering?.isPackage == true
                      ? 'Paket & Tutar'
                      : 'Hizmetler & Tutar',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (appt.offering?.isPackage == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PAKET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 20),
            if (appt.offering?.isPackage == true) ...[
              Text(
                appt.offering!.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (appt.offering!.description != null &&
                  appt.offering!.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    appt.offering!.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: appt.offering!.items
                    .map(
                      (n) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          n,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ] else
              ...appt.services.map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '₺${s.priceSnapshot.toStringAsFixed(0)} (${s.durationMinutesSnapshot} dk)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toplam (${appt.totalDurationMinutes} dk)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '₺${appt.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
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

  Widget _buildLocationCard(
    ProviderAppointmentModel appt,
    ProviderSharedLocation? sharedLocation,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Konum & Adres',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sharedLocation != null
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sharedLocation != null
                        ? 'Tam Adres Paylaşıldı'
                        : 'Yaklaşık Bölge',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: sharedLocation != null
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (sharedLocation != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sharedLocation.fullAddressText,
                          key: const Key('exact_address_text'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (sharedLocation.directions != null &&
                            sharedLocation.directions!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tarif: ${sharedLocation.directions}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(
                    Icons.location_city,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.approxLocation ?? 'Bölge belirtilmedi',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appt.isFinal
                              ? 'Randevu aktif olmadığı için tam adres gösterilmez.'
                              : 'Tam adres henüz paylaşılmadı.',
                          key: const Key('location_not_shared_text'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
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

  Widget _buildLifecycleActionCard(
    ProviderAppointmentModel appt,
    ProviderAppointmentDetailState state,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Randevu Durumu & Aksiyonlar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const Divider(height: 20),

            // ── PENDING Actions ──────────────────────────────────────────────
            if (appt.isPending) ...[
              const Text(
                'Bu randevu onayınızı bekliyor. Randevuyu onaylayabilir, reddedebilir veya uygun değilseniz alternatif saatler önerebilirsiniz.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('provider_confirm_btn'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Onayla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: state.isActionLoading
                          ? null
                          : _confirmAppointment,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('provider_reject_btn'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reddet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: state.isActionLoading
                          ? null
                          : _showRejectDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const Key('provider_propose_alternatives_btn'),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Alternatif Saat Öner'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: state.isActionLoading
                      ? null
                      : () => _showProposeAlternativesSheet(appt),
                ),
              ),
            ],

            // ── ALTERNATIVE_PROPOSED ─────────────────────────────────────────
            if (appt.isAlternativeProposed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Alternatif saat teklifleri müşteriye iletildi. Müşteri onayı bekleniyor.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B21A8),
                  ),
                ),
              ),
              if (appt.alternativeSlots.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Önerilen Alternatifler:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                ...appt.alternativeSlots.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${slot.date}   ${slot.startTime} - ${slot.endTime}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          slot.status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            // ── CONFIRMED ────────────────────────────────────────────────────
            if (appt.isConfirmed) ...[
              const Text(
                'Randevu onaylandı. Müşterinin yanına ulaştığınızda müşteriden 4 haneli başlangıç kodunu sözlü alarak girin.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('start_code_input'),
                controller: _startCodeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: '4 Haneli Başlangıç Kodu',
                  hintText: 'Örn: 1234',
                  counterText: '',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Color(0xFFFF5722),
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('verify_start_code_btn'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Hizmeti Başlat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: state.isActionLoading ? null : _verifyStartCode,
                ),
              ),
            ],

            // ── IN_PROGRESS ──────────────────────────────────────────────────
            if (appt.isInProgress) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.autorenew, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hizmet devam ediyor. İşi bitirdiğinizde aşağıdaki butona tıklayarak müşteri onayına gönderin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('provider_finish_btn'),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('İşi Bitir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: state.isActionLoading ? null : _finishAppointment,
                ),
              ),
            ],

            // ── AWAITING_CUSTOMER_CONFIRMATION ───────────────────────────────
            if (appt.isAwaitingConfirmation) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.hourglass_top, color: Color(0xFF0891B2)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hizmeti tamamlandı olarak bildirdiniz. Müşterinin onayı bekleniyor.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF155E75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── COMPLETED ────────────────────────────────────────────────────
            if (appt.isCompleted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu randevu başarıyla tamamlandı.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── REJECTED ─────────────────────────────────────────────────────
            if (appt.isRejected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Randevu talebi reddedildi.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    if (appt.rejectionReason != null &&
                        appt.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Gerekçe: ${appt.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── DISPUTED ─────────────────────────────────────────────────────
            if (appt.isDisputed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Müşteri sorun bildirdi (Uyuşmazlık Açıldı).',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBE123C),
                      ),
                    ),
                    if (appt.disputeSummary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Durum: ${appt.disputeSummary!.statusLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9F1239),
                        ),
                      ),
                      if (appt.disputeSummary!.resolution != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sonuç: ${appt.disputeSummary!.resolution}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9F1239),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAppointment() async {
    try {
      await ref
          .read(
            providerAppointmentDetailNotifierProvider(widget.appointmentId)
                .notifier,
          )
          .confirmAppointment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Randevu onaylandı.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('409')
            ? 'Bu saat artık müsait değil.'
            : 'Onaylanamadı: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Randevuyu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lütfen müşteriye iletilecek geçerli bir ret gerekçesi belirtin.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reject_reason_input'),
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ret Gerekçesi (En az 3 karakter)',
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
            key: const Key('confirm_reject_submit_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.length < 3) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(
                      providerAppointmentDetailNotifierProvider(
                        widget.appointmentId,
                      ).notifier,
                    )
                    .rejectAppointment(reason);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Randevu reddedildi.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reddedilemedi: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            },
            child: const Text('Reddet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProposeAlternativesSheet(ProviderAppointmentModel appt) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    List<String> availableSlots = [];
    List<String> selectedSlots = [];
    bool isLoadingAvailability = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> fetchSlotsForDate(DateTime d) async {
            setSheetState(() => isLoadingAvailability = true);
            final dateStr =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            final repo = ref.read(providerAppointmentRepositoryProvider);
            try {
              final res = await repo.fetchAvailability(
                providerId: appt.providerUserId,
                date: dateStr,
                serviceIds: appt.services.map((s) => s.id).toList(),
              );
              setSheetState(() {
                availableSlots = res.availableSlots;
                isLoadingAvailability = false;
              });
            } catch (_) {
              setSheetState(() {
                availableSlots = [];
                isLoadingAvailability = false;
              });
            }
          }

          return Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alternatif Saat Öner (1 - 5 Slot)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tarih Seçin'),
                    subtitle: Text(
                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF7C3AED),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                        await fetchSlotsForDate(picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (availableSlots.isEmpty && !isLoadingAvailability)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Müsait Saatleri Yükle'),
                        onPressed: () => fetchSlotsForDate(selectedDate),
                      ),
                    ),
                  if (isLoadingAvailability)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    )
                  else if (availableSlots.isNotEmpty) ...[
                    const Text(
                      'Uygun Saatler (1 ile 5 arasında seçin):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((slot) {
                        final isSelected = selectedSlots.contains(slot);
                        return FilterChip(
                          key: Key('slot_chip_$slot'),
                          label: Text(slot),
                          selected: isSelected,
                          selectedColor: const Color(0xFFF3E8FF),
                          checkmarkColor: const Color(0xFF7C3AED),
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                if (selectedSlots.length < 5) {
                                  selectedSlots.add(slot);
                                }
                              } else {
                                selectedSlots.remove(slot);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('submit_alternatives_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed:
                          selectedSlots.isEmpty || selectedSlots.length > 5
                          ? null
                          : () async {
                              final dateStr =
                                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                              final payload = selectedSlots
                                  .map((s) => {'date': dateStr, 'time': s})
                                  .toList();
                              Navigator.pop(sheetCtx);
                              try {
                                await ref
                                    .read(
                                      providerAppointmentDetailNotifierProvider(
                                        widget.appointmentId,
                                      ).notifier,
                                    )
                                    .proposeAlternatives(payload);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Alternatif saat teklifleri müşteriye iletildi.',
                                      ),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Teklif gönderilemedi: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(
                        'Teklif Gönder (${selectedSlots.length} Saat)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _verifyStartCode() async {
    final code = _startCodeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 4 haneli kodu eksiksiz girin.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    try {
      await ref
          .read(
            providerAppointmentDetailNotifierProvider(widget.appointmentId)
                .notifier,
          )
          .verifyStartCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kod doğrulandı, hizmet başladı!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Doğrulama başarısız: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _finishAppointment() async {
    try {
      await ref
          .read(
            providerAppointmentDetailNotifierProvider(widget.appointmentId)
                .notifier,
          )
          .finishAppointment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hizmet tamamlandı olarak işaretlendi.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tamamlanamadı: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}
