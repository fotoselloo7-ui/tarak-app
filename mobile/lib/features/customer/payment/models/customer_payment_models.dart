class PaytrSessionResponse {
  final bool success;
  final String token;
  final String iframeUrl;
  final int paymentId;
  final String? merchantOid;

  const PaytrSessionResponse({
    required this.success,
    required this.token,
    required this.iframeUrl,
    required this.paymentId,
    this.merchantOid,
  });

  factory PaytrSessionResponse.fromJson(Map<String, dynamic> json) {
    return PaytrSessionResponse(
      success: json['success'] == true,
      token: json['token']?.toString() ?? '',
      iframeUrl: json['iframe_url']?.toString() ?? '',
      paymentId: json['payment_id'] is int
          ? json['payment_id'] as int
          : int.tryParse(json['payment_id']?.toString() ?? '') ?? 0,
      merchantOid: json['merchant_oid']?.toString(),
    );
  }
}

class PaymentGatewayAttemptModel {
  final String? merchantOid;
  final String? status;
  final String? failureMessage;

  const PaymentGatewayAttemptModel({
    this.merchantOid,
    this.status,
    this.failureMessage,
  });

  factory PaymentGatewayAttemptModel.fromJson(Map<String, dynamic> json) {
    return PaymentGatewayAttemptModel(
      merchantOid: json['merchant_oid']?.toString(),
      status: json['status']?.toString(),
      failureMessage: json['failure_message']?.toString(),
    );
  }
}

class CustomerPaymentStatusModel {
  final int id;
  final String? resourceType;
  final int? resourceId;
  final String paymentMethod;
  final double grossAmount;
  final String status;
  final String statusLabel;
  final String? gateway;
  final DateTime? heldAt;
  final DateTime? transferPendingAt;
  final DateTime? settledAt;
  final PaymentGatewayAttemptModel? latestAttempt;
  final CustomerRefundSummaryModel? refundSummary;

  const CustomerPaymentStatusModel({
    required this.id,
    this.resourceType,
    this.resourceId,
    required this.paymentMethod,
    required this.grossAmount,
    required this.status,
    required this.statusLabel,
    this.gateway,
    this.heldAt,
    this.transferPendingAt,
    this.settledAt,
    this.latestAttempt,
    this.refundSummary,
  });

  bool get isHeld => status == 'HELD';
  bool get isPending => status == 'PENDING';
  bool get isTransferPending => status == 'TRANSFER_PENDING';
  bool get isSettled => status == 'SETTLED';
  bool get isDisputed => status == 'DISPUTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get hasRefund => refundSummary?.hasRefund ?? false;

  bool get isFailedAttempt => latestAttempt?.status == 'FAILED';

  factory CustomerPaymentStatusModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return CustomerPaymentStatusModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      resourceType: json['resource_type']?.toString(),
      resourceId: json['resource_id'] is int
          ? json['resource_id'] as int
          : int.tryParse(json['resource_id']?.toString() ?? ''),
      paymentMethod: json['payment_method']?.toString() ?? 'ONLINE',
      grossAmount: parseNum(json['gross_amount'])?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'PENDING',
      statusLabel: json['status_label']?.toString() ?? 'Online ödeme bekleniyor',
      gateway: json['gateway']?.toString(),
      heldAt: parseDate(json['held_at']),
      transferPendingAt: parseDate(json['transfer_pending_at']),
      settledAt: parseDate(json['settled_at']),
      latestAttempt: json['latest_attempt'] is Map<String, dynamic>
          ? PaymentGatewayAttemptModel.fromJson(json['latest_attempt'])
          : null,
      refundSummary: json['refund_summary'] is Map<String, dynamic>
          ? CustomerRefundSummaryModel.fromJson(json['refund_summary'])
          : null,
    );
  }
}

class CustomerRefundSummaryModel {
  final bool hasRefund;
  final String refundStatus;
  final String? refundStatusLabel;
  final double totalRefundedAmount;
  final double remainingRefundableAmount;
  final bool isPartial;

  const CustomerRefundSummaryModel({
    required this.hasRefund,
    required this.refundStatus,
    this.refundStatusLabel,
    required this.totalRefundedAmount,
    required this.remainingRefundableAmount,
    required this.isPartial,
  });

  bool get isPending => refundStatus == 'PENDING' || refundStatus == 'REFUND_REQUIRED';
  bool get isProcessing => refundStatus == 'REQUESTED' || refundStatus == 'REFUNDING';
  bool get isCompleted => refundStatus == 'COMPLETED' || refundStatus == 'REFUNDED';
  bool get isFailed => refundStatus == 'FAILED';
  bool get isManualReview => refundStatus == 'MANUAL_REVIEW';

  String get displayStatusText {
    if (refundStatusLabel != null && refundStatusLabel!.isNotEmpty) {
      return refundStatusLabel!;
    }
    switch (refundStatus) {
      case 'PENDING':
      case 'REFUND_REQUIRED':
        return 'İade bekleniyor';
      case 'REQUESTED':
      case 'REFUNDING':
        return 'İade işleminiz devam ediyor';
      case 'COMPLETED':
      case 'REFUNDED':
        return isPartial && totalRefundedAmount > 0
            ? 'Kısmi iadeniz tamamlandı (${totalRefundedAmount.toStringAsFixed(2)} TL)'
            : 'İadeniz tamamlandı';
      case 'PARTIALLY_REFUNDED':
        return 'Kısmi iadeniz tamamlandı (${totalRefundedAmount.toStringAsFixed(2)} TL)';
      case 'FAILED':
        return 'İade işlemi tamamlanamadı. Destek ekibimiz inceleyecek.';
      case 'MANUAL_REVIEW':
        return 'İade işleminiz inceleme altında.';
      default:
        return 'İade işlemi';
    }
  }

  factory CustomerRefundSummaryModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    final totalRefunded = parseNum(json['total_refunded_amount'])?.toDouble() ?? 0.0;
    final remaining = parseNum(json['remaining_refundable_amount'])?.toDouble() ?? 0.0;
    final isPartial = json['is_partial'] == true || json['refund_status'] == 'PARTIALLY_REFUNDED';

    return CustomerRefundSummaryModel(
      hasRefund: json['has_refund'] == true || (json['refund_status'] != null && json['refund_status'] != 'NONE'),
      refundStatus: json['refund_status']?.toString() ?? 'NONE',
      refundStatusLabel: json['refund_status_label']?.toString(),
      totalRefundedAmount: totalRefunded,
      remainingRefundableAmount: remaining,
      isPartial: isPartial,
    );
  }
}
