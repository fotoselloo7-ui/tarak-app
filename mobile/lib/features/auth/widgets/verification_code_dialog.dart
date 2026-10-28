import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';

class VerificationCodeDialog extends StatefulWidget {
  final String channel;
  final String destination;
  final DateTime resendAt;
  final Future<void> Function(String code) onConfirm;
  final Future<DateTime> Function() onResend;

  const VerificationCodeDialog({
    super.key,
    required this.channel,
    required this.destination,
    required this.resendAt,
    required this.onConfirm,
    required this.onResend,
  });

  @override
  State<VerificationCodeDialog> createState() => _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<VerificationCodeDialog> {
  final _code = TextEditingController();
  late DateTime _resendAt;
  Timer? _timer;
  String? _error;
  bool _busy = false;

  int get _seconds =>
      _resendAt.difference(DateTime.now()).inSeconds.clamp(0, 600);

  @override
  void initState() {
    super.initState();
    _resendAt = widget.resendAt;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      setState(() => _error = 'Altı haneli doğrulama kodunu girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_code.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kod doğrulanamadı. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _seconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deadline = await widget.onResend();
      if (mounted) {
        setState(() {
          _resendAt = deadline;
          _code.clear();
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kod gönderilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.channel == 'email';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          email ? 'E-posta doğrulama' : 'Telefon doğrulama',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.destination} ${email ? 'adresine gönderilen' : 'numarasına SMS ile gönderilen'} 6 haneli kodu girin.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  autofocus: true,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onSubmitted: (_) => _confirm(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '6 haneli kod',
                    hintStyle: const TextStyle(fontSize: 14, letterSpacing: 0),
                    errorText: _error,
                    errorMaxLines: 3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _busy || _seconds > 0 ? null : _resend,
                  child: Text(
                    _seconds > 0
                        ? 'Yeniden gönder ($_seconds sn)'
                        : 'Kodu yeniden gönder',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Doğrula'),
          ),
        ],
      ),
    );
  }
}
