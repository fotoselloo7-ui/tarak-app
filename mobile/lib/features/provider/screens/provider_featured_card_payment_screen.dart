import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// PayTR card payment for an "öne çıkarma" package (or, with [notification], a "bildirim reklamı"; [orderId] is then
/// the ad id). Pops with `true` once PayTR confirmed the payment (the period has started / the notification goes out),
/// otherwise `false`.
class ProviderFeaturedCardPaymentScreen extends ConsumerStatefulWidget {
  final int orderId;
  final String iframeUrl;
  final double amount;
  final String packageName;
  final bool notification;

  const ProviderFeaturedCardPaymentScreen({
    super.key,
    required this.orderId,
    required this.iframeUrl,
    required this.amount,
    required this.packageName,
    this.notification = false,
  });

  @override
  ConsumerState<ProviderFeaturedCardPaymentScreen> createState() => _ProviderFeaturedCardPaymentScreenState();
}

class _ProviderFeaturedCardPaymentScreenState extends ConsumerState<ProviderFeaturedCardPaymentScreen> with WidgetsBindingObserver {
  static const _pollEvery = Duration(seconds: 3);
  static const _maxPolls = 80;

  WebViewController? _web;
  Timer? _timer;
  int _polls = 0;
  bool _paid = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebView();
    _startPolling();
  }

  void _initWebView() {
    try {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            // Only HTTPS pages (PayTR and the 3D Secure bank redirects) may open inside the payment view.
            onNavigationRequest: (request) {
              final scheme = Uri.tryParse(request.url)?.scheme.toLowerCase();
              return scheme == 'https' ? NavigationDecision.navigate : NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.iframeUrl));
    } catch (_) {
      // Environments without a native webview (tests) simply show no form.
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) => _check());
  }

  Future<void> _check() async {
    if (_paid || _failure != null) return;
    if (++_polls > _maxPolls) {
      _timer?.cancel();
      return;
    }
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.get(widget.notification ? '/provider/notification-ads/${widget.orderId}' : '/provider/featured/orders/${widget.orderId}');
      final data = res.data is Map ? res.data['data'] : null;
      final status = data is Map ? data['status']?.toString() : null;
      if (!mounted) return;
      if (status == 'PAID' || status == 'QUEUED' || status == 'SENT') {
        _timer?.cancel();
        setState(() => _paid = true);
      } else if (status == 'FAILED') {
        _timer?.cancel();
        setState(() => _failure = (data['failure_message'] ?? 'Ödeme tamamlanamadı. Lütfen tekrar deneyin.').toString());
      }
    } catch (_) {
      // A temporary network error is retried on the next tick.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && !_paid && _failure == null) {
      _check();
      _startPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_paid || _failure != null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödemeden çıkılsın mı?'),
        content: Text(widget.notification
            ? 'Ödemeniz bankanız tarafından onaylandıysa bildiriminiz birkaç saniye içinde otomatik gönderilir.'
            : 'Ödemeniz bankanız tarafından onaylandıysa paketiniz birkaç saniye içinde otomatik aktif olur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Devam et')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çık')),
        ],
      ),
    );
    if (leave == true) await _check();

    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paid || _failure != null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context, _paid);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: () async {
              if (await _confirmLeave() && context.mounted) Navigator.pop(context, _paid);
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kartla Güvenli Ödeme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              Text('${widget.packageName} · ₺${widget.amount.toStringAsFixed(widget.amount % 1 == 0 ? 0 : 2)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        body: _paid
            ? _result(
                Icons.check_circle_rounded,
                const Color(0xFF059669),
                'Ödeme alındı',
                widget.notification ? 'Bildirimin gönderiliyor; indirim fiyatlarına uygulanmaya başladı.' : 'Öne çıkarma paketin aktif. Profilin vitrinde görünmeye başladı.',
              )
            : _failure != null
                ? _result(Icons.error_outline_rounded, const Color(0xFFDC2626), 'Ödeme tamamlanamadı', _failure!)
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFFEFF6FF),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Expanded(child: Text('Kart bilgilerin doğrudan PayTR güvenli sunucularında işlenir.', style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)))),
                          ],
                        ),
                      ),
                      Expanded(child: _web == null ? const Center(child: CircularProgressIndicator()) : WebViewWidget(controller: _web!)),
                    ],
                  ),
      ),
    );
  }

  Widget _result(IconData icon, Color color, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context, _paid), child: const Text('Tamam')),
          ],
        ),
      ),
    );
  }
}
