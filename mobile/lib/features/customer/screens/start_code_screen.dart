import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/instant_request_provider.dart';

/// Shows the 4-digit service start code to the customer.
/// Customer gives this to the provider to begin the service.
class StartCodeScreen extends ConsumerStatefulWidget {
  final int requestId;

  const StartCodeScreen({super.key, required this.requestId});

  @override
  ConsumerState<StartCodeScreen> createState() => _StartCodeScreenState();
}

class _StartCodeScreenState extends ConsumerState<StartCodeScreen> {
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(startCodeProvider(widget.requestId).notifier).load();
    });
  }

  void _startCountdown(String? expiresAt) {
    _countdownTimer?.cancel();
    if (expiresAt == null) return;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return;
    _secondsLeft = expiry.difference(DateTime.now()).inSeconds;
    if (_secondsLeft <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 99999));
      if (_secondsLeft <= 0) _countdownTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatCountdown() {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final codeState = ref.watch(startCodeProvider(widget.requestId));

    // Start countdown when code is loaded
    ref.listen<StartCodeState>(startCodeProvider(widget.requestId), (prev, next) {
      if (next.code != null && prev?.expiresAt != next.expiresAt) {
        _startCountdown(next.expiresAt);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Başlangıç Kodu'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: () {
            if (codeState.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (codeState.error != null) {
              return ErrorState(
                message: codeState.error!,
                onRetry: () =>
                    ref.read(startCodeProvider(widget.requestId).notifier).load(),
              );
            }
            return _CodeContent(
              code: codeState.code ?? '----',
              expiresAt: codeState.expiresAt,
              secondsLeft: _secondsLeft,
              formattedCountdown: _formatCountdown(),
              onRegenerate: () async {
                await ref
                    .read(startCodeProvider(widget.requestId).notifier)
                    .regenerate();
                final newState = ref.read(startCodeProvider(widget.requestId));
                _startCountdown(newState.expiresAt);
              },
            );
          }(),
        ),
      ),
    );
  }
}

class _CodeContent extends StatelessWidget {
  final String code;
  final String? expiresAt;
  final int secondsLeft;
  final String formattedCountdown;
  final Future<void> Function() onRegenerate;

  const _CodeContent({
    required this.code,
    required this.expiresAt,
    required this.secondsLeft,
    required this.formattedCountdown,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = secondsLeft <= 0 && expiresAt != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryBorder),
          ),
          child: const Icon(
            Icons.lock_rounded,
            size: 34,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Hizmet Başlangıç Kodu',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bu kodu berbere göstererek hizmetin başlamasını onaylayın.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // 4 Digit Code display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppTheme.radiusCard,
            border: Border.all(
              color: isExpired ? const Color(0xFFFCA5A5) : AppTheme.primary,
              width: 1.5,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 14,
              color: isExpired ? AppTheme.error : AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Security notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.slate100,
            borderRadius: AppTheme.radiusMedium,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: AppTheme.slate600),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Kodu yalnızca hizmet veren geldiğinde paylaşın.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Countdown
        if (expiresAt != null && !isExpired) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppTheme.slate500),
              const SizedBox(width: 6),
              Text(
                'Geçerlilik: $formattedCountdown',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.slate600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        if (isExpired) ...[
          const Text(
            'Kodun süresi doldu.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
        ],

        OutlinedButton.icon(
          onPressed: onRegenerate,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Yeni Kod Oluştur'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primaryBorder),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
          ),
        ),
      ],
    );
  }
}
