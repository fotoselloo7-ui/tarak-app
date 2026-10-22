import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../../chat/screens/chat_screen.dart';
import '../../../customer/models/service_request_model.dart';
import '../models/provider_shared_location_model.dart';
import '../providers/provider_instant_providers.dart';

class ProviderJobDetailScreen extends ConsumerStatefulWidget {
  final int requestId;

  const ProviderJobDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<ProviderJobDetailScreen> createState() =>
      _ProviderJobDetailScreenState();
}

class _ProviderJobDetailScreenState extends ConsumerState<ProviderJobDetailScreen>
    with WidgetsBindingObserver {
  final _codeController = TextEditingController();
  bool _isVerifyingCode = false;
  String? _codeErrorMessage;

  bool _isFinishing = false;
  String? _finishErrorMessage;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPollingIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (state == AppLifecycleState.resumed) {
      ref.read(activeJobDetailNotifierProvider(widget.requestId).notifier).refresh();
      ref.read(transientSharedLocationProvider(widget.requestId).notifier).fetch();
      _startPollingIfNeeded();
    }
  }

  void _startPollingIfNeeded() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      final currentAsync =
          ref.read(activeJobDetailNotifierProvider(widget.requestId));
      final job = currentAsync.value;
      if (job != null && (job.isAssigned || job.isInProgress || job.isAwaitingConfirmation)) {
        ref.read(activeJobDetailNotifierProvider(widget.requestId).notifier).refresh();
        ref.read(transientSharedLocationProvider(widget.requestId).notifier).fetch();
      } else if (job != null) {
        _pollingTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 4) {
      setState(() => _codeErrorMessage = 'Lütfen 4 haneli sayısal kodu giriniz.');
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _codeErrorMessage = null;
    });

    try {
      final notifier =
          ref.read(activeJobDetailNotifierProvider(widget.requestId).notifier);
      await notifier.verifyStartCode(code);

      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
          _codeController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başlangıç kodu doğrulandı. Hizmet başladı!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingCode = false;
        _codeErrorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingCode = false;
        _codeErrorMessage = 'Kod doğrulanamadı: $e';
      });
    }
  }

  Future<void> _handleFinishService() async {
    setState(() {
      _isFinishing = true;
      _finishErrorMessage = null;
    });

    try {
      final notifier =
          ref.read(activeJobDetailNotifierProvider(widget.requestId).notifier);
      await notifier.finishService();

      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hizmet tamamlandı bildirimi yapıldı. Müşteri onayı bekleniyor.'),
            backgroundColor: Color(0xFF2563EB),
          ),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isFinishing = false;
        _finishErrorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFinishing = false;
        _finishErrorMessage = 'İşlem tamamlanamadı: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(activeJobDetailNotifierProvider(widget.requestId));
    final locationAsync = ref.watch(transientSharedLocationProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'İş Detayı #${widget.requestId}',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.slate900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(activeJobDetailNotifierProvider(widget.requestId).notifier).refresh();
              ref.read(transientSharedLocationProvider(widget.requestId).notifier).fetch();
            },
          ),
        ],
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref
                      .read(activeJobDetailNotifierProvider(widget.requestId).notifier)
                      .refresh(),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        data: (job) => RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(activeJobDetailNotifierProvider(widget.requestId).notifier)
                .refresh();
            await ref
                .read(transientSharedLocationProvider(widget.requestId).notifier)
                .fetch();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 1. Lifecycle Status Banner ──────────────────────────────
              _buildStatusHeader(job),

              const SizedBox(height: 16),

              // ── 2. Online Payment Gate (if ONLINE & PENDING) ────────────
              if (job.isOnlinePending) ...[
                _buildOnlinePendingWarningCard(),
                const SizedBox(height: 16),
              ] else if (job.isOnlineHeld) ...[
                _buildOnlineHeldSuccessCard(),
                const SizedBox(height: 16),
              ],

              // ── 3. Services and Job Details ─────────────────────────────
              _buildJobInfoCard(job),

              const SizedBox(height: 16),

              // ── 3.1 Chat Action ─────────────────────────────────────────
              if (job.isAssigned || job.isInProgress || job.isAwaitingConfirmation || job.isCompleted || job.isDisputed) ...[
                _buildChatButton(job),
                const SizedBox(height: 16),
              ],

              // ── 4. Exact Shared Location Card ───────────────────────────
              _buildLocationCard(job, locationAsync),

              const SizedBox(height: 16),

              // ── 5. Action Sections Based on Lifecycle Status ────────────
              if (job.isAssigned) ...[
                _buildStartCodeSection(job),
              ] else if (job.isInProgress) ...[
                _buildInProgressSection(job),
              ] else if (job.isAwaitingConfirmation) ...[
                _buildAwaitingConfirmationCard(),
              ] else if (job.isCompleted) ...[
                _buildCompletedCard(),
              ] else if (job.isDisputed) ...[
                _buildDisputedCard(job),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(ServiceRequestModel job) {
    Color bg;
    Color fg;
    IconData icon;

    if (job.isAssigned) {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
      icon = Icons.assignment_turned_in;
    } else if (job.isInProgress) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.hourglass_top;
    } else if (job.isAwaitingConfirmation) {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF9333EA);
      icon = Icons.mark_chat_unread;
    } else if (job.isCompleted) {
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF16A34A);
      icon = Icons.check_circle;
    } else if (job.isDisputed) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      icon = Icons.warning_amber_rounded;
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: fg,
                  ),
                ),
                Text(
                  _getStatusSubtitle(job),
                  style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusSubtitle(ServiceRequestModel job) {
    if (job.isAssigned) {
      return 'Müşteriyle buluşup 4 haneli başlangıç kodunu giriniz.';
    } else if (job.isInProgress) {
      return 'Hizmet devam ediyor. İşlem bitince "İşi Bitir" butonuna basınız.';
    } else if (job.isAwaitingConfirmation) {
      return 'İş bitti, müşterinin onay vermesi bekleniyor.';
    } else if (job.isCompleted) {
      return 'Hizmet başarıyla tamamlandı.';
    } else if (job.isDisputed) {
      return 'Bu hizmet hakkında bir uyuşmazlık bildirimi yapıldı.';
    }
    return '';
  }

  Widget _buildOnlinePendingWarningCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.credit_card_off, color: Color(0xFFD97706), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Online Ödeme Bekleniyor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Müşteri henüz online ödemeyi tamamlamadı. Ödeme güvenli havuza alınana kadar tam adres erişimi ve başlangıç kodu doğrulaması yapılamaz.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineHeldSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: const [
          Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ödeme güvence altında. Hizmet başlatılabilir.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard(ServiceRequestModel job) {
    return Container(
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
              const Text(
                'Hizmetler',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: job.isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.isOnline ? 'Online Ödeme' : 'Nakit Ödeme',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: job.isOnline ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...job.services.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Color(0xFFFF5722)),
                  const SizedBox(width: 8),
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (s.durationMinutes != null && s.durationMinutes! > 0) ...[
                    const Spacer(),
                    Text('~${s.durationMinutes} dk', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ],
              ),
            ),
          ),
          if (job.customerNote != null && job.customerNote!.isNotEmpty) ...[
            const Divider(height: 20),
            const Text(
              'Müşteri Notu',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              job.customerNote!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(
    ServiceRequestModel job,
    AsyncValue<ProviderSharedLocationModel?> locationAsync,
  ) {
    // Safe approximate fallback
    final approxArea = [
      job.approxNeighborhood,
      job.approxDistrict,
      job.approxProvince,
    ].where((String? s) => s != null && s.isNotEmpty).join(', ');

    return Container(
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
            children: const [
              Icon(Icons.location_on, color: Color(0xFFFF5722), size: 20),
              SizedBox(width: 8),
              Text(
                'Konum ve Adres',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Yaklaşık Bölge: ${approxArea.isNotEmpty ? approxArea : (job.locationText ?? "Belirtilmedi")}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const Divider(height: 20),

          // Exact location access
          locationAsync.when(
            loading: () => const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Konum paylaşım izni kontrol ediliyor...', style: TextStyle(fontSize: 12)),
              ],
            ),
            error: (err, stack) => _buildNoLocationWidget(job),
            data: (sharedLoc) {
              if (sharedLoc == null) {
                return _buildNoLocationWidget(job);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified, size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 6),
                      Text(
                        'Müşteri Tam Adresini Paylaştı',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sharedLoc.fullAddressText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (sharedLoc.directions != null && sharedLoc.directions!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tarif: ${sharedLoc.directions!}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationWidget(ServiceRequestModel job) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              job.isActive
                  ? 'Tam adres henüz paylaşılmadı.'
                  : 'İş aktif olmadığı için tam adres gösterilmez.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCodeSection(ServiceRequestModel job) {
    final isBlocked = job.isOnlinePending;

    return Container(
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
            children: const [
              Icon(Icons.key, color: Color(0xFFFF5722), size: 20),
              SizedBox(width: 8),
              Text(
                'Hizmet Başlangıç Kodu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Hizmete başlamak için müşteriden sözlü olarak aldığınız 4 haneli başlangıç kodunu giriniz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          if (_codeErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _codeErrorMessage!,
                      style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _codeController,
            enabled: !isBlocked && !_isVerifyingCode,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isBlocked || _isVerifyingCode ? null : _handleVerifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isVerifyingCode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Doğrula ve Başla',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressSection(ServiceRequestModel job) {
    return Container(
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
            children: const [
              Icon(Icons.content_cut, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Hizmet Devam Ediyor',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Hizmet başarıyla başlatıldı. İşlemleri tamamladığınızda "İşi Bitir" butonuna dokunarak müşteriye onay gönderiniz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          if (_finishErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _finishErrorMessage!,
                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isFinishing ? null : _handleFinishService,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isFinishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'İşi Bitir',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingConfirmationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        children: const [
          Icon(Icons.hourglass_bottom, color: Color(0xFF9333EA), size: 36),
          SizedBox(height: 8),
          Text(
            'Müşteri Onayı Bekleniyor',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B21A8),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Hizmet bitirme bildiriminiz iletildi. Müşteri onayladığında hizmet tamamlanmış olacaktır.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF7E22CE)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: const [
          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 40),
          SizedBox(height: 8),
          Text(
            'Hizmet Tamamlandı',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF15803D),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Müşteri hizmetin tamamlandığını onayladı.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputedCard(ServiceRequestModel job) {
    final dispute = job.disputeSummary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.report_problem, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 8),
              Text(
                'Uyuşmazlık Durumu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF991B1B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dispute?.statusLabel ?? 'Müşteri bir sorun bildirdi ve talep incelemeye alındı.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
          ),
          if (dispute?.resolution != null && dispute!.resolution!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'İnceleme Sonucu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dispute.resolution!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatButton(ServiceRequestModel job) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.chat_bubble_outline, color: Color(0xFF2563EB)),
              ),
              SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Müşteri ile İletişim',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Soru veya detaylar için mesaj gönderin',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key('provider_instant_chat_btn'),
            onPressed: () async {
              try {
                final convId = await ref
                    .read(chatRepositoryProvider)
                    .getConversationForProviderServiceRequest(job.id);
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(conversationId: convId),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sohbet açılamadı: $e')),
                );
              }
            },
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Mesaj'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
