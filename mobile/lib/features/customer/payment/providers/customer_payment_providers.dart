import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/customer_payment_models.dart';
import '../repositories/customer_payment_repository.dart';

/// Can the platform take online (card) payments right now? `GET /customer/payment-capabilities`
/// is true only while PayTR is configured. The customer UI disables "Online Ödeme" otherwise, so a
/// customer is never sent into a failing checkout; cash stays available either way.
final onlinePaymentAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/customer/payment-capabilities');
    final data = res.data is Map ? res.data['data'] : null;
    return data is Map && data['online_payment'] == true;
  } catch (_) {
    return false;
  }
});

const onlinePaymentUnavailableHint = 'Online ödeme şu anda kullanılamıyor. Nakit ödeme ile devam edebilirsiniz.';

class CustomerPaymentState {
  final bool isLoadingToken;
  final PaytrSessionResponse? tokenResponse;
  final CustomerPaymentStatusModel? paymentStatus;
  final bool isSuccess;
  final String? errorMessage;
  final bool isPolling;
  final int pollCount;

  const CustomerPaymentState({
    this.isLoadingToken = false,
    this.tokenResponse,
    this.paymentStatus,
    this.isSuccess = false,
    this.errorMessage,
    this.isPolling = false,
    this.pollCount = 0,
  });

  CustomerPaymentState copyWith({
    bool? isLoadingToken,
    PaytrSessionResponse? tokenResponse,
    CustomerPaymentStatusModel? paymentStatus,
    bool? isSuccess,
    String? errorMessage,
    bool? isPolling,
    int? pollCount,
    bool clearError = false,
    bool clearToken = false,
  }) {
    return CustomerPaymentState(
      isLoadingToken: isLoadingToken ?? this.isLoadingToken,
      tokenResponse: clearToken ? null : (tokenResponse ?? this.tokenResponse),
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPolling: isPolling ?? this.isPolling,
      pollCount: pollCount ?? this.pollCount,
    );
  }
}

final customerPaymentNotifierProvider = NotifierProvider.family<
    CustomerPaymentNotifier, CustomerPaymentState, int>(
  CustomerPaymentNotifier.new,
);

class CustomerPaymentNotifier
    extends Notifier<CustomerPaymentState> {
  final int paymentId;
  Timer? _pollTimer;

  CustomerPaymentNotifier(this.paymentId);

  static bool enableAutoPolling = true;

  @override
  CustomerPaymentState build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _pollTimer = null;
    });

    return const CustomerPaymentState();
  }

  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;

  Future<void> initPayment() async {
    if (state.isLoadingToken) return;

    state = state.copyWith(
      isLoadingToken: true,
      clearError: true,
      clearToken: true,
      isSuccess: false,
    );

    final repo = ref.read(customerPaymentRepositoryProvider);
    try {
      final session = await repo.getPaytrToken(paymentId);
      state = state.copyWith(
        isLoadingToken: false,
        tokenResponse: session,
      );

      if (enableAutoPolling) {
        startPolling();
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingToken: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void startPolling() {
    stopPolling();
    state = state.copyWith(isPolling: true, pollCount: 0);

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollStep();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (state.isPolling) {
      state = state.copyWith(isPolling: false);
    }
  }

  Future<void> _pollStep() async {
    final newCount = state.pollCount + 1;
    if (newCount > 40) {
      stopPolling();
      return;
    }

    state = state.copyWith(pollCount: newCount);
    await checkStatusNow();
  }

  Future<void> checkStatusNow() async {
    final repo = ref.read(customerPaymentRepositoryProvider);
    try {
      final status = await repo.getPaymentStatus(paymentId);
      final isHeld = status.isHeld;

      if (isHeld) {
        stopPolling();
        state = state.copyWith(
          paymentStatus: status,
          isSuccess: true,
        );
      } else if (status.isFailedAttempt) {
        // Failed attempt from gateway
        final failMsg = status.latestAttempt?.failureMessage ??
            'Ödeme tamamlanamadı. Lütfen tekrar deneyin.';
        state = state.copyWith(
          paymentStatus: status,
          errorMessage: failMsg,
        );
      } else {
        state = state.copyWith(
          paymentStatus: status,
        );
      }
    } catch (_) {
      // Suppress transient poll network errors to avoid breaking session
    }
  }

  Future<void> retry() async {
    stopPolling();
    await initPayment();
  }
}
