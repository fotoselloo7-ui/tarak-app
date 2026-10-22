import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/customer_payment_providers.dart';

class PaytrPaymentScreen extends ConsumerStatefulWidget {
  final int paymentId;
  final double grossAmount;
  final String? resourceTitle;
  final VoidCallback? onPaymentSuccess;

  const PaytrPaymentScreen({
    super.key,
    required this.paymentId,
    required this.grossAmount,
    this.resourceTitle,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<PaytrPaymentScreen> createState() => _PaytrPaymentScreenState();
}

class _PaytrPaymentScreenState extends ConsumerState<PaytrPaymentScreen>
    with WidgetsBindingObserver {
  WebViewController? _webViewController;
  String? _loadedToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize payment session on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(customerPaymentNotifierProvider(widget.paymentId).notifier)
          .initPayment();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final notifier =
        ref.read(customerPaymentNotifierProvider(widget.paymentId).notifier);

    if (state == AppLifecycleState.paused) {
      notifier.stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      notifier.checkStatusNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webViewController = null;
    super.dispose();
  }

  void _initWebViewController(String iframeUrl) {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              final uri = Uri.tryParse(request.url);
              if (uri == null) {
                return NavigationDecision.prevent;
              }

              final scheme = uri.scheme.toLowerCase();
              // Block dangerous, non-HTTPS, or external application schemes
              if (scheme != 'https') {
                return NavigationDecision.prevent;
              }

              // Allow natural PayTR and 3D Secure bank redirects over HTTPS
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(iframeUrl));

      if (mounted) {
        setState(() {
          _webViewController = controller;
        });
      }
    } catch (_) {
      // Gracefully handle environments without native platform webview implementation (e.g. tests)
    }
  }

  Future<bool> _handleWillPop(CustomerPaymentState paymentState) async {
    if (paymentState.isSuccess) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödemeden Çıkılsın mı?'),
        content: const Text(
          'Ödeme ekranından çıkmak istiyor musunuz?\n\n'
          'Ödemeniz bankanız tarafından onaylandıysa, durum birkaç saniye içinde güncellenecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam Et'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Çık'),
          ),
        ],
      ),
    );

    if (shouldPop == true) {
      // Reconcile status once more before popping
      await ref
          .read(customerPaymentNotifierProvider(widget.paymentId).notifier)
          .checkStatusNow();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(
      customerPaymentNotifierProvider(widget.paymentId),
    );
    final notifier = ref.read(
      customerPaymentNotifierProvider(widget.paymentId).notifier,
    );

    // Initialize controller when token response arrives
    if (paymentState.tokenResponse != null &&
        _loadedToken != paymentState.tokenResponse!.token) {
      _loadedToken = paymentState.tokenResponse!.token;
      _initWebViewController(paymentState.tokenResponse!.iframeUrl);
    }

    // Trigger success callback once when HELD is confirmed
    if (paymentState.isSuccess && widget.onPaymentSuccess != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPaymentSuccess?.call();
      });
    }

    return WillPopScope(
      onWillPop: () => _handleWillPop(paymentState),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
            onPressed: () async {
              if (await _handleWillPop(paymentState)) {
                if (context.mounted) {
                  Navigator.pop(context, paymentState.isSuccess);
                }
              }
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PayTR Güvenli Ödeme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${widget.resourceTitle ?? "Hizmet Bedeli"} • ₺${widget.grossAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: Color(0xFF059669), size: 12),
                    SizedBox(width: 4),
                    Text(
                      '256-Bit SSL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _buildBody(paymentState, notifier),
              ),
              _buildBottomStatus(paymentState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    CustomerPaymentState state,
    CustomerPaymentNotifier notifier,
  ) {
    if (state.isSuccess) {
      return _buildSuccessView();
    }

    if (state.isLoadingToken) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text(
              'PayTR Güvenli Ödeme Oturumu Hazırlanıyor...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Lütfen bekleyiniz, şifreli bağlantı kuruluyor.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ödeme Başlatılamadı',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    key: const Key('paytr_retry_btn'),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Tekrar Dene'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => notifier.retry(),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_webViewController != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFEFF6FF),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kart bilgileriniz doğrudan PayTR güvenli sunucularında işlenir.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: WebViewWidget(controller: _webViewController!),
          ),
        ],
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF059669),
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ödeme Başarıyla Alındı!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ödemeniz platform havuzunda güvenle ayrıldı (HELD).\n'
              'Hizmet veren randevunuza veya talebinize başlayabilir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('payment_success_done_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Tamamla ve Kapat',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStatus(CustomerPaymentState state) {
    final statusLabel = state.paymentStatus?.statusLabel ??
        (state.isSuccess
            ? 'Ödeme alındı'
            : 'Online ödeme bekleniyor');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state.isSuccess
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Durum: $statusLabel',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const Text(
            'Tarak Güvenli Ödeme',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
