import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../models/service_request_model.dart';
import '../payment/models/customer_payment_models.dart';
import '../providers/instant_request_provider.dart';
import 'completion_screen.dart';
import 'offers_screen.dart';
import 'start_code_screen.dart';
import '../payment/screens/paytr_payment_screen.dart';
import '../../chat/providers/chat_providers.dart';
import '../../chat/screens/chat_screen.dart';
import '../../shared/widgets/account_sheets.dart';
import '../../../core/widgets/verified_tick.dart';

/// Main tracking screen for an active Hemen Çağır request.
/// Polls status every 12 seconds only while screen is active and request is mutable.
class RequestTrackingScreen extends ConsumerStatefulWidget {
  final int requestId;

  const RequestTrackingScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestTrackingScreen> createState() =>
      _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends ConsumerState<RequestTrackingScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeRequestProvider(widget.requestId).notifier).load();
      ref.read(locationShareProvider(widget.requestId).notifier).load();
      _startPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final req = ref.read(activeRequestProvider(widget.requestId)).request;
      if (req != null && req.isActive) {
        ref.read(activeRequestProvider(widget.requestId).notifier).refresh();
        ref.read(locationShareProvider(widget.requestId).notifier).load();
        _startPolling();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) {
        _stopPolling();
        return;
      }
      final req =
          ref.read(activeRequestProvider(widget.requestId)).request;
      if (req != null && req.isActive) {
        ref.read(activeRequestProvider(widget.requestId).notifier).refresh();
        if (req.isAssigned) {
          ref.read(locationShareProvider(widget.requestId).notifier).load();
        }
      } else {
        // Stop polling when terminal (COMPLETED, CANCELLED, DISPUTED)
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Talebi İptal Et'),
        content: const Text(
            'Bu talebi iptal etmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İptal Et',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(activeRequestProvider(widget.requestId).notifier)
          .cancel();
      _stopPolling();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep iptal edildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('İptal başarısız: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeRequestProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Talep Takibi',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(activeRequestProvider(widget.requestId).notifier)
                  .refresh();
              ref
                  .read(locationShareProvider(widget.requestId).notifier)
                  .load();
            },
          ),
        ],
      ),
      body: () {
        if (state.isLoading && state.request == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.request == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(activeRequestProvider(widget.requestId)
                            .notifier)
                        .load(),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          );
        }
        final req = state.request;
        if (req == null) return const SizedBox.shrink();
        return _TrackingBody(
          request: req,
          requestId: widget.requestId,
          onCancel: req.isOpen ? _cancelRequest : null,
        );
      }(),
    );
  }
}

class _TrackingBody extends ConsumerWidget {
  final ServiceRequestModel request;
  final int requestId;
  final VoidCallback? onCancel;

  const _TrackingBody({
    required this.request,
    required this.requestId,
    required this.onCancel,
  });

  Color _statusColor() {
    switch (request.status) {
      case ServiceRequestModel.statusOpen:
        return AppTheme.info;
      case ServiceRequestModel.statusAssigned:
        return AppTheme.warning;
      case ServiceRequestModel.statusInProgress:
        return AppTheme.primary;
      case ServiceRequestModel.statusAwaitingConfirmation:
        return const Color(0xFF9333EA);
      case ServiceRequestModel.statusCompleted:
        return AppTheme.success;
      case ServiceRequestModel.statusCancelled:
        return AppTheme.slate500;
      case ServiceRequestModel.statusDisputed:
        return AppTheme.error;
      default:
        return AppTheme.slate500;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor();
    final refreshError = ref.watch(activeRequestProvider(requestId)).error;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await ref
            .read(activeRequestProvider(requestId).notifier)
            .refresh();
        await ref
            .read(locationShareProvider(requestId).notifier)
            .load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (refreshError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(20),
                borderRadius: AppTheme.radiusCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Talep güncellenemedi. Gösterilen bilgiler son başarılı yüklemeden alınmıştır.\n$refreshError'),
                  TextButton(
                    onPressed: () => ref.read(activeRequestProvider(requestId).notifier).refresh(),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Status card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: AppTheme.radiusCard,
              border: Border.all(color: statusColor.withAlpha(60)),
            ),
            child: Column(
              children: [
                Icon(_statusIcon(), color: statusColor, size: 40),
                const SizedBox(height: 8),
                Text(
                  request.statusLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Talep #${request.id} • ${request.isOnline ? "Online Ödeme" : "Nakit Ödeme"}',
                  style: const TextStyle(
                    color: AppTheme.slate500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Safe Customer Refund Summary Card
          if (request.hasRefund || (request.isDisputed && request.isOnline && request.paymentSummary?.refundSummary != null)) ...[
            _RefundSummaryCard(refundSummary: request.paymentSummary!.refundSummary!),
            const SizedBox(height: 14),
          ],

          // ONLINE PAYMENT PENDING Banner (Requirement 3)
          if (request.isOnlinePending) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: AppTheme.radiusCard,
                border: Border.all(color: const Color(0xFFFDE68A)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          color: AppTheme.warning, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Online ödeme bekleniyor',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Başlangıç kodu ve konum paylaşımı ödeme onaylandıktan sonra aktifleşecektir.',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Color(0xFFB45309),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (request.paymentSummary?.id != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('complete_payment_btn'),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Ödemeyi Tamamla'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusButton,
                          ),
                        ),
                        onPressed: () async {
                          final paymentId = request.paymentSummary!.id!;
                          final grossAmount =
                              request.paymentSummary?.grossAmount ?? 0.0;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaytrPaymentScreen(
                                paymentId: paymentId,
                                grossAmount: grossAmount,
                                resourceTitle: 'Hemen Çağır Talebi #${request.id}',
                                onPaymentSuccess: () {
                                  ref
                                      .read(activeRequestProvider(requestId).notifier)
                                      .load();
                                },
                              ),
                            ),
                          );
                          ref
                              .read(activeRequestProvider(requestId).notifier)
                              .load();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Location Share Card for ASSIGNED requests (Requirements 1 & 2)
          if (request.isAssigned) ...[
            _LocationShareCard(
              requestId: requestId,
              request: request,
            ),
            const SizedBox(height: 14),
          ],

          // Services
          _SectionCard(
            title: 'Seçilen Hizmetler',
            child: Column(
              children: request.services
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.content_cut,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(s.name,
                                    style: const TextStyle(fontSize: 14))),
                            if (s.durationMinutes != null)
                              Text('~${s.durationMinutes} dk',
                                  style: const TextStyle(
                                      color: AppTheme.slate500,
                                      fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Location summary
          if (request.locationText != null || request.approxDistrict != null)
            _SectionCard(
              title: 'Hizmet Adresi',
              child: Text(
                request.locationText ??
                    '${request.approxDistrict}, ${request.approxProvince}',
                style: const TextStyle(
                    color: AppTheme.slate500, fontSize: 14),
              ),
            ),
          const SizedBox(height: 12),

          // Provider info (when assigned)
          if (request.assignedProvider != null)
            _SectionCard(
              title: 'Atanan Berber',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.assignedProvider!.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (request.assignedProvider!.isVerified)
                        const VerifiedTick(size: 18),
                    ],
                  ),
                  if (request.assignedProvider!.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      request.assignedProvider!.phone!,
                      style: const TextStyle(
                          color: AppTheme.slate500, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('instant_chat_btn'),
                      onPressed: () async {
                        try {
                          final repo = ref.read(chatRepositoryProvider);
                          final convId = await repo.getConversationForCustomerServiceRequest(requestId);
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: convId,
                                otherPartyName: request.assignedProvider?.displayName ?? 'Berber',
                                otherPartyVerified: request.assignedProvider?.isVerified == true,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFFFF5722)),
                      label: const Text(
                        'Berbere Mesaj Gönder',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF5722)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Note
          if (request.customerNote != null &&
              request.customerNote!.isNotEmpty)
            _SectionCard(
              title: 'Notunuz',
              child: Text(
                request.customerNote!,
                style: const TextStyle(
                    color: AppTheme.slate500, fontSize: 14),
              ),
            ),
          const SizedBox(height: 20),

          // Action buttons based on status
          ..._buildActions(context, ref),
        ],
      ),
    );
  }

  IconData _statusIcon() {
    switch (request.status) {
      case ServiceRequestModel.statusOpen:
        return Icons.hourglass_top_rounded;
      case ServiceRequestModel.statusAssigned:
        return Icons.check_circle_outline;
      case ServiceRequestModel.statusInProgress:
        return Icons.build_circle_outlined;
      case ServiceRequestModel.statusAwaitingConfirmation:
        return Icons.thumb_up_alt_outlined;
      case ServiceRequestModel.statusCompleted:
        return Icons.task_alt;
      case ServiceRequestModel.statusCancelled:
        return Icons.cancel_outlined;
      case ServiceRequestModel.statusDisputed:
        return Icons.report_problem_outlined;
      default:
        return Icons.info_outline;
    }
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[];

    if (request.isOpen) {
      // View offers button when offers available
      if (request.offersCount > 0) {
        actions.add(
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => OffersScreen(requestId: requestId)),
            ),
            icon: const Icon(Icons.local_offer_outlined),
            label: Text('Teklifleri Gör (${request.offersCount})'),
          ),
        );
        actions.add(const SizedBox(height: 10));
      } else {
        actions.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  request.isDirect ? 'Seçtiğiniz uzmanın yanıtı bekleniyor…' : 'Uzmanlardan teklif bekleniyor…',
                  style: const TextStyle(color: AppTheme.slate500),
                ),
              ],
            ),
          ),
        );
        actions.add(const SizedBox(height: 10));
      }

      if (onCancel != null) {
        actions.add(
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Talebi İptal Et'),
          ),
        );
      }
    }

    if (request.isAssigned) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StartCodeScreen(requestId: requestId)),
          ),
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Başlangıç Kodunu Göster'),
        ),
      );
    }

    // The start code is consumed when the provider starts the job; IN_PROGRESS offers no code.

    if (request.isAwaitingConfirmation) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CompletionScreen(requestId: requestId)),
          ),
          icon: const Icon(Icons.check_circle),
          label: const Text('Hizmeti Onayla / Uyuşmazlık Bildir'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981)),
        ),
      );
    }

    if (request.isCompleted && request.hasReview) {
      actions.add(const Text(
        'Bu hizmeti değerlendirdiniz. Teşekkürler!',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF047857)),
      ));
      actions.add(const SizedBox(height: 12));
    }
    if (request.isCompleted && !request.hasReview) {
      actions.add(ElevatedButton.icon(
        onPressed: () async {
          final reviewed = await showLeaveReviewSheet(context,
            serviceRequestId: requestId,
            providerName: request.assignedProvider?.name,
          );
          if (reviewed == true) {
            ref.read(activeRequestProvider(requestId).notifier).refresh();
          }
        },
        icon: const TarakMark(size: 24),
        label: const Text('Değerlendir'),
      ));
      actions.add(const SizedBox(height: 12));
    }
    if (request.isCompleted || request.isCancelled || request.isDisputed) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Geri Dön'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return actions;
  }
}

class _LocationShareCard extends ConsumerWidget {
  final int requestId;
  final ServiceRequestModel request;

  const _LocationShareCard({
    required this.requestId,
    required this.request,
  });

  Future<void> _showConsentDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adres Paylaşımı Onayı'),
        content: const Text(
          'Bu hizmet için kayıtlı tam adresiniz, yalnızca atanan hizmet verenle sınırlı süre paylaşılacaktır.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla ve Paylaş'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(locationShareProvider(requestId).notifier)
          .shareSavedAddress(
            explicitConsent: true,
            customerAddressId: request.customerAddressId,
          );

      final state = ref.read(locationShareProvider(requestId));
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage ?? 'Adres paylaşıldı.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _revokeShare(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konum Paylaşımını Kapat'),
        content: const Text(
          'Hizmet verenle adres paylaşımını kapatmak istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kapat', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(locationShareProvider(requestId).notifier)
          .revoke();

      final state = ref.read(locationShareProvider(requestId));
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage ?? 'Konum paylaşımı kapatıldı.'),
            ),
          );
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shareState = ref.watch(locationShareProvider(requestId));
    final displayStatus = shareState.displayStatus;
    final isShared = shareState.isShared;

    Color badgeColor;
    if (isShared) {
      badgeColor = const Color(0xFF10B981);
    } else if (shareState.isRevoked) {
      badgeColor = Colors.redAccent;
    } else if (shareState.isExpired) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = AppTheme.slate500;
    }

    return Container(
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
              const Row(
                children: [
                  Icon(Icons.share_location, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Adres Paylaşımı',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isShared) ...[
            const Text(
              'Kayıtlı adresiniz atanan berber ile güvenli şekilde paylaşılmaktadır.',
              style: TextStyle(color: AppTheme.slate500, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: shareState.isLoading ? null : () => _revokeShare(context, ref),
              icon: shareState.isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_off_outlined, size: 18),
              label: const Text('Konum Paylaşımını Kapat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ] else ...[
            const Text(
              'Berberin adresinize ulaşabilmesi için kayıtlı adresinizi paylaşabilirsiniz.',
              style: TextStyle(color: AppTheme.slate500, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: shareState.isLoading ? null : () => _showConsentDialog(context, ref),
              icon: shareState.isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_location, size: 18),
              label: const Text('Adresimi Hizmet Verenle Paylaş'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RefundSummaryCard extends StatelessWidget {
  final CustomerRefundSummaryModel refundSummary;

  const _RefundSummaryCard({required this.refundSummary});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;

    if (refundSummary.isCompleted) {
      bg = AppTheme.successLight;
      border = const Color(0xFFBBF7D0);
      iconColor = AppTheme.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (refundSummary.isFailed) {
      bg = AppTheme.errorLight;
      border = const Color(0xFFFECACA);
      iconColor = AppTheme.error;
      icon = Icons.error_outline_rounded;
    } else if (refundSummary.isManualReview) {
      bg = AppTheme.warningLight;
      border = const Color(0xFFFDE68A);
      iconColor = AppTheme.warning;
      icon = Icons.shield_outlined;
    } else {
      bg = AppTheme.infoLight;
      border = const Color(0xFFBFDBFE);
      iconColor = AppTheme.info;
      icon = Icons.sync_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(color: border),
        boxShadow: AppTheme.cardShadow,
      ),
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
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  refundSummary.displayStatusText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
