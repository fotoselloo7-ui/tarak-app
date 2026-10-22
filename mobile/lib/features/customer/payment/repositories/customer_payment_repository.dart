import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/customer_payment_models.dart';

final customerPaymentRepositoryProvider =
    Provider<CustomerPaymentRepository>((ref) {
  return CustomerPaymentRepository(ref.watch(apiClientProvider));
});

class CustomerPaymentRepository {
  final ApiClient _api;

  CustomerPaymentRepository(this._api);

  /// Request PayTR iFrame token for a pending online payment.
  /// POST /customer/service-payments/{paymentId}/paytr/token
  Future<PaytrSessionResponse> getPaytrToken(int paymentId) async {
    final response = await _api.post(
      '/customer/service-payments/$paymentId/paytr/token',
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final tokenData = data['data'];
      if (tokenData is Map<String, dynamic>) {
        final session = PaytrSessionResponse.fromJson(tokenData);

        // Enforce HTTPS security rule
        if (!session.iframeUrl.toLowerCase().startsWith('https://')) {
          throw const AppException(
            message: 'Güvenli olmayan ödeme bağlantısı (HTTPS zorunludur).',
          );
        }

        return session;
      }
    }

    throw const AppException(message: 'PayTR ödeme oturumu başlatılamadı.');
  }

  /// Get canonical payment status and latest gateway attempt from backend.
  /// GET /customer/service-payments/{paymentId}/status
  Future<CustomerPaymentStatusModel> getPaymentStatus(int paymentId) async {
    final response = await _api.get(
      '/customer/service-payments/$paymentId/status',
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final paymentData = data['data'];
      if (paymentData is Map<String, dynamic>) {
        return CustomerPaymentStatusModel.fromJson(paymentData);
      }
    }

    throw const AppException(message: 'Ödeme durumu alınamadı.');
  }
}
