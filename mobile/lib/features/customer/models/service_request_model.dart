import '../../offerings/models/offering_models.dart';
import '../payment/models/customer_payment_models.dart';

class AssignedProvider {
  final int id;
  final String name;
  final String? businessName;
  final String? providerType;
  final String? phone;
  final bool isVerified;

  const AssignedProvider({
    required this.id,
    required this.name,
    this.businessName,
    this.providerType,
    this.phone,
    this.isVerified = false,
  });

  String get displayName => businessName ?? name;

  factory AssignedProvider.fromJson(Map<String, dynamic> json) {
    return AssignedProvider(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      businessName: json['business_name']?.toString(),
      providerType: json['provider_type']?.toString(),
      phone: json['phone']?.toString(),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

class DisputeSummary {
  final int caseId;
  final String status;
  final String? statusLabel;
  final String? resolution;
  final DateTime? openedAt;
  final DateTime? resolvedAt;

  const DisputeSummary({
    required this.caseId,
    required this.status,
    this.statusLabel,
    this.resolution,
    this.openedAt,
    this.resolvedAt,
  });

  factory DisputeSummary.fromJson(Map<String, dynamic> json) {
    return DisputeSummary(
      caseId: json['case_id'] is int
          ? json['case_id'] as int
          : int.tryParse(json['case_id'].toString()) ?? 0,
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString(),
      resolution: json['resolution']?.toString(),
      openedAt: json['opened_at'] != null
          ? DateTime.tryParse(json['opened_at'].toString())
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
    );
  }
}

class PaymentSummary {
  final int? id;
  final String status;
  final double? grossAmount;
  final DateTime? heldAt;
  final DateTime? transferPendingAt;
  final CustomerRefundSummaryModel? refundSummary;

  const PaymentSummary({
    this.id,
    required this.status,
    this.grossAmount,
    this.heldAt,
    this.transferPendingAt,
    this.refundSummary,
  });

  bool get isPending => status == 'PENDING';
  bool get isHeld => status == 'HELD';
  bool get isSettled => status == 'SETTLED';
  bool get hasRefund => refundSummary?.hasRefund ?? false;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'PENDING',
      grossAmount: (json['gross_amount'] as num?)?.toDouble(),
      heldAt: json['held_at'] != null
          ? DateTime.tryParse(json['held_at'].toString())
          : null,
      transferPendingAt: json['transfer_pending_at'] != null
          ? DateTime.tryParse(json['transfer_pending_at'].toString())
          : null,
      refundSummary: json['refund_summary'] is Map<String, dynamic>
          ? CustomerRefundSummaryModel.fromJson(json['refund_summary'])
          : null,
    );
  }
}

class ServiceRequestModel {
  final int id;
  final String status;
  final String? mode;
  final String paymentMethod;
  final String? locationText;
  final int? customerAddressId;
  final String? approxProvince;
  final String? approxDistrict;
  final String? approxNeighborhood;
  final String? customerNote;
  final String? urgency;
  final List<RequestService> services;
  final int? assignedProviderUserId;
  final AssignedProvider? assignedProvider;
  final int? acceptedOfferId;
  final int offersCount;
  final DateTime? assignedAt;
  final DateTime? cancelledAt;
  final DateTime? serviceStartedAt;
  final DateTime? providerCompletedAt;
  final DateTime? completedAt;
  final DateTime? disputedAt;
  final String? disputeReason;
  final DisputeSummary? disputeSummary;
  final PaymentSummary? paymentSummary;
  final double? distanceKm;
  final bool isApproximateMatch;
  final bool isDirect;
  /// True once this customer reviewed the completed job (server flag).
  final bool hasReview;
  final OfferingSnapshot? offering;
  final String? targetProviderName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceRequestModel({
    required this.id,
    required this.status,
    this.mode,
    required this.paymentMethod,
    this.locationText,
    this.customerAddressId,
    this.approxProvince,
    this.approxDistrict,
    this.approxNeighborhood,
    this.customerNote,
    this.urgency,
    required this.services,
    this.assignedProviderUserId,
    this.assignedProvider,
    this.acceptedOfferId,
    this.offersCount = 0,
    this.assignedAt,
    this.cancelledAt,
    this.serviceStartedAt,
    this.providerCompletedAt,
    this.completedAt,
    this.disputedAt,
    this.disputeReason,
    this.disputeSummary,
    this.paymentSummary,
    this.distanceKm,
    this.isApproximateMatch = false,
    this.isDirect = false,
    this.hasReview = false,
    this.offering,
    this.targetProviderName,
    this.createdAt,
    this.updatedAt,
  });

  // Status constants
  static const String statusOpen = 'OPEN';
  static const String statusAssigned = 'ASSIGNED';
  static const String statusInProgress = 'IN_PROGRESS';
  static const String statusAwaitingConfirmation =
      'AWAITING_CUSTOMER_CONFIRMATION';
  static const String statusCompleted = 'COMPLETED';
  static const String statusCancelled = 'CANCELLED';
  static const String statusDisputed = 'DISPUTED';

  bool get isOpen => status == statusOpen;
  bool get isAssigned => status == statusAssigned;
  bool get isInProgress => status == statusInProgress;
  bool get isAwaitingConfirmation => status == statusAwaitingConfirmation;
  bool get isCompleted => status == statusCompleted;
  bool get isCancelled => status == statusCancelled;
  bool get isDisputed => status == statusDisputed;
  bool get isActive =>
      isOpen || isAssigned || isInProgress || isAwaitingConfirmation;

  bool get isOnline => paymentMethod.toUpperCase() == 'ONLINE';
  bool get isCash => paymentMethod.toUpperCase() == 'CASH';

  /// True if online payment is selected and not yet held in escrow.
  bool get isOnlinePending =>
      isOnline && (paymentSummary == null || paymentSummary!.isPending);

  /// True if online payment has been held into escrow.
  bool get isOnlineHeld => isOnline && paymentSummary?.isHeld == true;

  /// True if payment has been secured or settled.
  bool get isPaid => isOnline && (paymentSummary?.isHeld == true || paymentSummary?.isSettled == true);

  /// True if payment is held or settled, or payment is cash.
  bool get isFinanciallyReady =>
      isCash || (isOnline && paymentSummary?.isHeld == true);

  /// True if a refund has been initiated or completed.
  bool get hasRefund => paymentSummary?.hasRefund == true;

  String get statusLabel {
    switch (status) {
      case statusOpen:
        return isDirect ? 'Uzman Yanıtı Bekleniyor' : 'Teklif Bekleniyor';
      case statusAssigned:
        return 'Berber Atandı';
      case statusInProgress:
        return 'Hizmet Devam Ediyor';
      case statusAwaitingConfirmation:
        return 'Onayınızı Bekliyor';
      case statusCompleted:
        return 'Tamamlandı';
      case statusCancelled:
        return 'İptal Edildi';
      case statusDisputed:
        return 'Uyuşmazlık';
      default:
        return status;
    }
  }

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final servicesList = <RequestService>[];
    if (json['services'] is List) {
      for (final s in json['services'] as List) {
        if (s is Map<String, dynamic>) {
          servicesList.add(RequestService.fromJson(s));
        }
      }
    }

    return ServiceRequestModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      status: json['status']?.toString() ?? '',
      mode: json['mode']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'CASH',
      locationText: json['location_text']?.toString(),
      customerAddressId: json['customer_address_id'] is int
          ? json['customer_address_id'] as int
          : int.tryParse(json['customer_address_id']?.toString() ?? ''),
      approxProvince: json['approx_province']?.toString(),
      approxDistrict: json['approx_district']?.toString(),
      approxNeighborhood: json['approx_neighborhood']?.toString(),
      customerNote: json['customer_note']?.toString(),
      urgency: json['urgency']?.toString(),
      services: servicesList,
      assignedProviderUserId: json['assigned_provider_user_id'] is int
          ? json['assigned_provider_user_id'] as int
          : int.tryParse(json['assigned_provider_user_id']?.toString() ?? ''),
      assignedProvider: json['assigned_provider'] != null
          ? AssignedProvider.fromJson(
              json['assigned_provider'] as Map<String, dynamic>)
          : null,
      acceptedOfferId: json['accepted_offer_id'] is int
          ? json['accepted_offer_id'] as int
          : int.tryParse(json['accepted_offer_id']?.toString() ?? ''),
      offersCount: json['offers_count'] is int
          ? json['offers_count'] as int
          : int.tryParse(json['offers_count']?.toString() ?? '0') ?? 0,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())
          : null,
      serviceStartedAt: json['service_started_at'] != null
          ? DateTime.tryParse(json['service_started_at'].toString())
          : null,
      providerCompletedAt: json['provider_completed_at'] != null
          ? DateTime.tryParse(json['provider_completed_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      disputedAt: json['disputed_at'] != null
          ? DateTime.tryParse(json['disputed_at'].toString())
          : null,
      disputeReason: json['dispute_reason']?.toString(),
      disputeSummary: json['dispute_summary'] != null
          ? DisputeSummary.fromJson(
              json['dispute_summary'] as Map<String, dynamic>)
          : null,
      paymentSummary: json['payment_summary'] != null
          ? PaymentSummary.fromJson(
              json['payment_summary'] as Map<String, dynamic>)
          : (json['service_payment'] != null
              ? PaymentSummary.fromJson(
                  json['service_payment'] as Map<String, dynamic>)
              : null),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      isApproximateMatch: json['is_approximate_match'] as bool? ?? false,
      isDirect: json['is_direct'] as bool? ?? false,
      hasReview: json['has_review'] == true,
      offering: OfferingSnapshot.tryParse(json['offering']),
      targetProviderName: json['target_provider'] is Map<String, dynamic>
          ? (json['target_provider'] as Map<String, dynamic>)['business_name']?.toString()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class RequestService {
  final int id;
  final String name;
  final String? slug;
  final int? durationMinutes;
  final String? iconClass;

  const RequestService({
    required this.id,
    required this.name,
    this.slug,
    this.durationMinutes,
    this.iconClass,
  });

  factory RequestService.fromJson(Map<String, dynamic> json) {
    return RequestService(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      durationMinutes: json['duration_minutes'] is int
          ? json['duration_minutes'] as int
          : int.tryParse(json['duration_minutes']?.toString() ?? ''),
      iconClass: json['icon_class']?.toString(),
    );
  }
}
