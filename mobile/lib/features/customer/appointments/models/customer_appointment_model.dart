import '../../payment/models/customer_payment_models.dart';

class AppointmentServiceSnapshot {
  final int id;
  final String name;
  final double priceSnapshot;
  final int durationMinutesSnapshot;

  const AppointmentServiceSnapshot({
    required this.id,
    required this.name,
    required this.priceSnapshot,
    required this.durationMinutesSnapshot,
  });

  factory AppointmentServiceSnapshot.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    return AppointmentServiceSnapshot(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      priceSnapshot: parseNum(json['price_snapshot'])?.toDouble() ?? 0.0,
      durationMinutesSnapshot:
          parseNum(json['duration_minutes_snapshot'])?.toInt() ?? 0,
    );
  }
}

class AppointmentAlternativeSlot {
  final int id;
  final String date;
  final String startTime;
  final String endTime;
  final String status;

  const AppointmentAlternativeSlot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isExpired => status == 'EXPIRED';

  factory AppointmentAlternativeSlot.fromJson(Map<String, dynamic> json) {
    return AppointmentAlternativeSlot(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      date: json['date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
    );
  }
}

class AppointmentProviderInfo {
  final int id;
  final int userId;
  final String? businessName;
  final String? name;
  final String? avatarUrl;
  final String? district;
  final String? city;
  final bool isVerified;

  const AppointmentProviderInfo({
    required this.id,
    required this.userId,
    this.businessName,
    this.name,
    this.avatarUrl,
    this.district,
    this.city,
    this.isVerified = true,
  });

  String get displayName {
    if (businessName != null && businessName!.trim().isNotEmpty) {
      return businessName!.trim();
    }
    if (name != null && name!.trim().isNotEmpty) {
      return name!.trim();
    }
    return 'Hizmet Veren';
  }

  factory AppointmentProviderInfo.fromJson(Map<String, dynamic> json) {
    return AppointmentProviderInfo(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      businessName: json['business_name']?.toString(),
      name: json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      district: json['district']?.toString(),
      city: json['city']?.toString(),
      isVerified: json['is_verified'] == true,
    );
  }
}

class AppointmentPaymentSummary {
  final int id;
  final String status; // PENDING, HELD, TRANSFER_PENDING, SETTLED, DISPUTED, REFUND_REQUIRED, CANCELLED
  final double grossAmount;
  final DateTime? heldAt;
  final DateTime? transferPendingAt;
  final CustomerRefundSummaryModel? refundSummary;

  const AppointmentPaymentSummary({
    required this.id,
    required this.status,
    required this.grossAmount,
    this.heldAt,
    this.transferPendingAt,
    this.refundSummary,
  });

  bool get isHeld => status == 'HELD';
  bool get isPending => status == 'PENDING';
  bool get hasRefund => refundSummary?.hasRefund ?? false;

  factory AppointmentPaymentSummary.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    return AppointmentPaymentSummary(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? '',
      grossAmount: parseNum(json['gross_amount'])?.toDouble() ?? 0.0,
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

class AppointmentDisputeSummary {
  final int caseId;
  final String status;
  final String? statusLabel;
  final String? resolution;
  final DateTime? openedAt;
  final DateTime? resolvedAt;

  const AppointmentDisputeSummary({
    required this.caseId,
    required this.status,
    this.statusLabel,
    this.resolution,
    this.openedAt,
    this.resolvedAt,
  });

  factory AppointmentDisputeSummary.fromJson(Map<String, dynamic> json) {
    return AppointmentDisputeSummary(
      caseId: json['case_id'] is int
          ? json['case_id'] as int
          : int.tryParse(json['case_id']?.toString() ?? '') ?? 0,
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

class CustomerAppointmentOffering {
  final String type;
  final String title;
  final String? description;
  final double? price;
  final int? durationMinutes;
  final List<String> items;

  const CustomerAppointmentOffering({
    required this.type,
    required this.title,
    this.description,
    this.price,
    this.durationMinutes,
    this.items = const [],
  });

  bool get isPackage => type == 'PACKAGE';

  factory CustomerAppointmentOffering.fromJson(Map<String, dynamic> json) {
    return CustomerAppointmentOffering(
      type: json['type']?.toString() ?? 'SERVICE',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      durationMinutes: json['duration_minutes'] is int
          ? json['duration_minutes'] as int
          : int.tryParse(json['duration_minutes']?.toString() ?? ''),
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => e['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

class CustomerAppointmentModel {
  final int id;
  final String publicId;
  final int customerUserId;
  final int providerUserId;
  final AppointmentProviderInfo? provider;
  final int? customerAddressId;
  final Map<String, dynamic>? address;
  final String status;
  final String appointmentDate;
  final String startTime;
  final String endTime;
  final String paymentMethod;
  final double totalPrice;
  final int totalDurationMinutes;
  final CustomerAppointmentOffering? offering;
  final String? approxLocation;
  final String? approxProvince;
  final String? approxDistrict;
  final String? customerNote;
  final DateTime? requestedAt;
  final DateTime? confirmedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;
  final String? rejectionReason;
  final DateTime? serviceStartedAt;
  final DateTime? providerCompletedAt;
  final DateTime? completedAt;
  final DateTime? disputedAt;
  final String? disputeReason;
  final String? disputeNote;
  final AppointmentDisputeSummary? disputeSummary;
  /// True once this customer reviewed the completed appointment (server flag).
  final bool hasReview;
  final AppointmentPaymentSummary? paymentSummary;
  final bool financiallyReady;
  final List<AppointmentServiceSnapshot> services;
  final List<AppointmentAlternativeSlot> alternativeSlots;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerAppointmentModel({
    required this.id,
    required this.publicId,
    required this.customerUserId,
    required this.providerUserId,
    this.provider,
    this.customerAddressId,
    this.address,
    required this.status,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.paymentMethod,
    required this.totalPrice,
    required this.totalDurationMinutes,
    this.offering,
    this.approxLocation,
    this.approxProvince,
    this.approxDistrict,
    this.customerNote,
    this.requestedAt,
    this.confirmedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.rejectionReason,
    this.serviceStartedAt,
    this.providerCompletedAt,
    this.completedAt,
    this.disputedAt,
    this.disputeReason,
    this.disputeNote,
    this.disputeSummary,
    this.hasReview = false,
    this.paymentSummary,
    this.financiallyReady = false,
    this.services = const [],
    this.alternativeSlots = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isAlternativeProposed =>
      status == 'ALTERNATIVE_PROPOSED' || status == 'ALT_PROPOSED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isAwaitingConfirmation => status == 'AWAITING_CUSTOMER_CONFIRMATION';
  bool get isCompleted => status == 'COMPLETED';
  bool get isDisputed => status == 'DISPUTED';

  /// Whether the appointment is in a terminal state (polling should stop)
  bool get isFinal => isRejected || isCancelled || isCompleted || isDisputed;

  /// Payment readiness gate, computed by the backend (`is_financially_ready`):
  /// CASH needs a RESERVED/CAPTURED commission, ONLINE needs HELD/TRANSFER_PENDING/SETTLED.
  /// The client never derives this from status or payment method.
  bool get isFinanciallyReady => financiallyReady;

  bool get isOnline => paymentMethod.toUpperCase() == 'ONLINE';
  bool get hasRefund => paymentSummary?.hasRefund == true;

  /// Confirmed ONLINE appointment whose payment is not secured yet.
  bool get isOnlinePending => isOnline && isConfirmed && !financiallyReady;

  /// Exact address share and start code are only offered before/while the service
  /// when the backend reports financial readiness.
  bool get canShareLocation =>
      financiallyReady && (isConfirmed || isInProgress);
  bool get canShowStartCode => financiallyReady && isConfirmed;

  /// Customer cancel is offered only before the service starts.
  bool get canCancel => isPending || isAlternativeProposed || isConfirmed;

  /// Active alternative slots proposed to customer
  List<AppointmentAlternativeSlot> get pendingAlternativeSlots =>
      alternativeSlots.where((s) => s.isPending).toList();

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Onay Bekliyor';
      case 'CONFIRMED':
        return 'Onaylandı';
      case 'ALT_PROPOSED':
      case 'ALTERNATIVE_PROPOSED':
        return 'Alternatif Saat Önerildi';
      case 'REJECTED':
        return 'Reddedildi';
      case 'CANCELLED':
        return 'İptal Edildi';
      case 'IN_PROGRESS':
        return 'Hizmet Veriliyor';
      case 'AWAITING_CUSTOMER_CONFIRMATION':
        return 'Tamamlanma Onayı Bekliyor';
      case 'COMPLETED':
        return 'Tamamlandı';
      case 'DISPUTED':
        return 'Sorun Bildirildi';
      default:
        return status;
    }
  }

  String get servicesSummary {
    if (offering?.title.isNotEmpty == true) return offering!.title;
    if (services.isEmpty) return 'Hizmet Belirtilmedi';
    return services.map((s) => s.name).join(', ');
  }

  String get formattedAddress {
    if (address != null) {
      final parts = <String>[];
      if (address!['street'] != null) parts.add(address!['street'].toString());
      if (address!['neighborhood'] != null) {
        parts.add(address!['neighborhood'].toString());
      }
      if (address!['district'] != null) {
        parts.add(address!['district'].toString());
      }
      if (address!['province'] != null) {
        parts.add(address!['province'].toString());
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }
    if (approxLocation != null && approxLocation!.isNotEmpty) {
      return approxLocation!;
    }
    return 'Kayıtlı Adres';
  }

  factory CustomerAppointmentModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    final rawServices = json['services'] as List<dynamic>? ?? [];
    final rawAlternatives = json['alternative_slots'] as List<dynamic>? ?? [];

    return CustomerAppointmentModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      publicId: json['public_id']?.toString() ?? '',
      customerUserId: json['customer_user_id'] is int
          ? json['customer_user_id'] as int
          : int.tryParse(json['customer_user_id']?.toString() ?? '') ?? 0,
      providerUserId: json['provider_user_id'] is int
          ? json['provider_user_id'] as int
          : int.tryParse(json['provider_user_id']?.toString() ?? '') ?? 0,
      provider: json['provider'] is Map<String, dynamic>
          ? AppointmentProviderInfo.fromJson(json['provider'])
          : null,
      customerAddressId: json['customer_address_id'] is int
          ? json['customer_address_id'] as int
          : int.tryParse(json['customer_address_id']?.toString() ?? ''),
      address: json['address'] is Map<String, dynamic>
          ? json['address'] as Map<String, dynamic>
          : null,
      status: json['status']?.toString() ?? 'PENDING',
      appointmentDate: json['appointment_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'CASH',
      totalPrice: parseNum(json['total_price'])?.toDouble() ?? 0.0,
      offering: json['offering'] is Map<String, dynamic>
          ? CustomerAppointmentOffering.fromJson(json['offering'])
          : null,
      totalDurationMinutes:
          parseNum(json['total_duration_minutes'])?.toInt() ?? 0,
      approxLocation: json['approx_location']?.toString(),
      approxProvince: json['approx_province']?.toString(),
      approxDistrict: json['approx_district']?.toString(),
      customerNote: json['customer_note']?.toString(),
      requestedAt: parseDate(json['requested_at']),
      confirmedAt: parseDate(json['confirmed_at']),
      rejectedAt: parseDate(json['rejected_at']),
      cancelledAt: parseDate(json['cancelled_at']),
      rejectionReason: json['rejection_reason']?.toString(),
      serviceStartedAt: parseDate(json['service_started_at']),
      providerCompletedAt: parseDate(json['provider_completed_at']),
      completedAt: parseDate(json['completed_at']),
      disputedAt: parseDate(json['disputed_at']),
      disputeReason: json['dispute_reason']?.toString(),
      disputeNote: json['dispute_note']?.toString(),
      hasReview: json['has_review'] == true,
      disputeSummary: json['dispute_summary'] is Map<String, dynamic>
          ? AppointmentDisputeSummary.fromJson(json['dispute_summary'])
          : null,
      paymentSummary: json['payment_summary'] is Map<String, dynamic>
          ? AppointmentPaymentSummary.fromJson(json['payment_summary'])
          : (json['service_payment'] is Map<String, dynamic>
                ? AppointmentPaymentSummary.fromJson(json['service_payment'])
                : null),
      financiallyReady: json['is_financially_ready'] == true,
      services: rawServices
          .whereType<Map<String, dynamic>>()
          .map(AppointmentServiceSnapshot.fromJson)
          .toList(),
      alternativeSlots: rawAlternatives
          .whereType<Map<String, dynamic>>()
          .map(AppointmentAlternativeSlot.fromJson)
          .toList(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}
