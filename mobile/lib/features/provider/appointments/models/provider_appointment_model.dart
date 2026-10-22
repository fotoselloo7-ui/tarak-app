import 'package:flutter/material.dart';

class ProviderAppointmentCustomer {
  final int id;
  final String name;
  final String? avatarUrl;

  const ProviderAppointmentCustomer({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory ProviderAppointmentCustomer.fromJson(Map<String, dynamic> json) {
    return ProviderAppointmentCustomer(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Müşteri',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class ProviderAppointmentServiceItem {
  final int id;
  final String name;
  final double priceSnapshot;
  final int durationMinutesSnapshot;

  const ProviderAppointmentServiceItem({
    required this.id,
    required this.name,
    required this.priceSnapshot,
    required this.durationMinutesSnapshot,
  });

  factory ProviderAppointmentServiceItem.fromJson(Map<String, dynamic> json) {
    return ProviderAppointmentServiceItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      priceSnapshot: json['price_snapshot'] is num
          ? (json['price_snapshot'] as num).toDouble()
          : double.tryParse(json['price_snapshot']?.toString() ?? '0') ?? 0.0,
      durationMinutesSnapshot: json['duration_minutes_snapshot'] is int
          ? json['duration_minutes_snapshot'] as int
          : int.tryParse(json['duration_minutes_snapshot']?.toString() ?? '30') ?? 30,
    );
  }
}

class ProviderAlternativeSlot {
  final int id;
  final String date;
  final String startTime;
  final String endTime;
  final String status;

  const ProviderAlternativeSlot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory ProviderAlternativeSlot.fromJson(Map<String, dynamic> json) {
    return ProviderAlternativeSlot(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      date: json['date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
    );
  }
}

class ProviderDisputeSummary {
  final int caseId;
  final String status;
  final String statusLabel;
  final String? resolution;
  final DateTime? openedAt;
  final DateTime? resolvedAt;

  const ProviderDisputeSummary({
    required this.caseId,
    required this.status,
    required this.statusLabel,
    this.resolution,
    this.openedAt,
    this.resolvedAt,
  });

  factory ProviderDisputeSummary.fromJson(Map<String, dynamic> json) {
    return ProviderDisputeSummary(
      caseId: json['case_id'] is int
          ? json['case_id'] as int
          : int.tryParse(json['case_id']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'OPEN',
      statusLabel: json['status_label']?.toString() ?? 'Uyuşmazlık',
      resolution: json['resolution']?.toString(),
      openedAt: json['opened_at'] != null ? DateTime.tryParse(json['opened_at'].toString()) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
    );
  }
}

class ProviderSharedLocation {
  final String? title;
  final String? addressLine1;
  final String? addressLine2;
  final String? buildingNo;
  final String? floor;
  final String? apartmentNo;
  final String? district;
  final String? province;
  final String? postalCode;
  final String? directions;
  final DateTime? sharedAt;
  final DateTime? expiresAt;

  const ProviderSharedLocation({
    this.title,
    this.addressLine1,
    this.addressLine2,
    this.buildingNo,
    this.floor,
    this.apartmentNo,
    this.district,
    this.province,
    this.postalCode,
    this.directions,
    this.sharedAt,
    this.expiresAt,
  });

  String get fullAddressText {
    final parts = <String>[];
    if (title != null && title!.isNotEmpty) parts.add('[$title]');
    if (addressLine1 != null && addressLine1!.isNotEmpty) parts.add(addressLine1!);
    if (addressLine2 != null && addressLine2!.isNotEmpty) parts.add(addressLine2!);
    if (buildingNo != null && buildingNo!.isNotEmpty) parts.add('No: $buildingNo');
    if (floor != null && floor!.isNotEmpty) parts.add('Kat: $floor');
    if (apartmentNo != null && apartmentNo!.isNotEmpty) parts.add('Daire: $apartmentNo');
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    return parts.join(', ');
  }

  factory ProviderSharedLocation.fromJson(Map<String, dynamic> json) {
    final exact = json['exact_location'] is Map<String, dynamic>
        ? json['exact_location'] as Map<String, dynamic>
        : json;

    return ProviderSharedLocation(
      title: exact['title']?.toString(),
      addressLine1: exact['address_line1']?.toString(),
      addressLine2: exact['address_line2']?.toString(),
      buildingNo: exact['building_no']?.toString(),
      floor: exact['floor']?.toString(),
      apartmentNo: exact['apartment_no']?.toString(),
      district: exact['district']?.toString(),
      province: exact['province']?.toString(),
      postalCode: exact['postal_code']?.toString(),
      directions: exact['directions']?.toString(),
      sharedAt: json['shared_at'] != null ? DateTime.tryParse(json['shared_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
    );
  }
}

class ProviderAppointmentOffering {
  final String type;
  final String title;
  final String? description;
  final double? price;
  final int? durationMinutes;
  final List<String> items;

  const ProviderAppointmentOffering({
    required this.type,
    required this.title,
    this.description,
    this.price,
    this.durationMinutes,
    this.items = const [],
  });

  bool get isPackage => type == 'PACKAGE';

  factory ProviderAppointmentOffering.fromJson(Map<String, dynamic> json) {
    return ProviderAppointmentOffering(
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

class ProviderAppointmentModel {
  final int id;
  final String publicId;
  final int customerUserId;
  final int providerUserId;
  final ProviderAppointmentCustomer? customer;
  final String status;
  final String appointmentDate;
  final String startTime;
  final String endTime;
  final String paymentMethod;
  final double totalPrice;
  final int totalDurationMinutes;
  final String? approxLocation;
  final String? approxProvince;
  final String? approxDistrict;
  final String? approxNeighborhood;
  final String? customerNote;
  final String? rejectionReason;
  final String? disputeReason;
  final String? disputeNote;
  final ProviderDisputeSummary? disputeSummary;
  final List<ProviderAppointmentServiceItem> services;
  final int? providerPackageId;
  final ProviderAppointmentOffering? offering;
  final List<ProviderAlternativeSlot> alternativeSlots;
  final DateTime? requestedAt;
  final DateTime? confirmedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;
  final DateTime? serviceStartedAt;
  final DateTime? completedAt;
  final DateTime? disputedAt;

  const ProviderAppointmentModel({
    required this.id,
    required this.publicId,
    required this.customerUserId,
    required this.providerUserId,
    this.customer,
    required this.status,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.paymentMethod,
    required this.totalPrice,
    required this.totalDurationMinutes,
    this.approxLocation,
    this.approxProvince,
    this.approxDistrict,
    this.approxNeighborhood,
    this.customerNote,
    this.rejectionReason,
    this.disputeReason,
    this.disputeNote,
    this.disputeSummary,
    this.services = const [],
    this.providerPackageId,
    this.offering,
    this.alternativeSlots = const [],
    this.requestedAt,
    this.confirmedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.serviceStartedAt,
    this.completedAt,
    this.disputedAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isAlternativeProposed => status == 'ALTERNATIVE_PROPOSED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isAwaitingConfirmation => status == 'AWAITING_CUSTOMER_CONFIRMATION';
  bool get isCompleted => status == 'COMPLETED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isDisputed => status == 'DISPUTED';

  bool get isFinal => isCompleted || isRejected || isCancelled || isDisputed;
  bool get isUpcoming => isConfirmed || isInProgress || isAwaitingConfirmation;

  bool get isOnline => paymentMethod.toUpperCase() == 'ONLINE';
  bool get isCash => paymentMethod.toUpperCase() == 'CASH';

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Onay Bekliyor';
      case 'CONFIRMED':
        return 'Onaylandı';
      case 'ALTERNATIVE_PROPOSED':
        return 'Alternatif Saat Önerildi';
      case 'IN_PROGRESS':
        return 'Hizmet Veriliyor';
      case 'AWAITING_CUSTOMER_CONFIRMATION':
        return 'Müşteri Onayı Bekleniyor';
      case 'COMPLETED':
        return 'Tamamlandı';
      case 'REJECTED':
        return 'Reddedildi';
      case 'CANCELLED':
        return 'İptal Edildi';
      case 'DISPUTED':
        return 'Sorun Bildirildi';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFD97706);
      case 'CONFIRMED':
        return const Color(0xFF059669);
      case 'ALTERNATIVE_PROPOSED':
        return const Color(0xFF7C3AED);
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'AWAITING_CUSTOMER_CONFIRMATION':
        return const Color(0xFF0891B2);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      case 'DISPUTED':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF64748B);
    }
  }

  factory ProviderAppointmentModel.fromJson(Map<String, dynamic> json) {
    final rawCustomer = json['customer'];
    ProviderAppointmentCustomer? parsedCustomer;
    if (rawCustomer is Map<String, dynamic>) {
      parsedCustomer = ProviderAppointmentCustomer.fromJson(rawCustomer);
    }

    final rawServices = json['services'];
    List<ProviderAppointmentServiceItem> parsedServices = [];
    if (rawServices is List) {
      parsedServices = rawServices
          .map((s) => ProviderAppointmentServiceItem.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    final rawAlternatives = json['alternative_slots'];
    List<ProviderAlternativeSlot> parsedAlternatives = [];
    if (rawAlternatives is List) {
      parsedAlternatives = rawAlternatives
          .map((a) => ProviderAlternativeSlot.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    final rawDispute = json['dispute_summary'];
    ProviderDisputeSummary? parsedDispute;
    if (rawDispute is Map<String, dynamic>) {
      parsedDispute = ProviderDisputeSummary.fromJson(rawDispute);
    }

    return ProviderAppointmentModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      publicId: json['public_id']?.toString() ?? '',
      customerUserId: json['customer_user_id'] is int
          ? json['customer_user_id'] as int
          : int.tryParse(json['customer_user_id']?.toString() ?? '0') ?? 0,
      providerUserId: json['provider_user_id'] is int
          ? json['provider_user_id'] as int
          : int.tryParse(json['provider_user_id']?.toString() ?? '0') ?? 0,
      customer: parsedCustomer,
      providerPackageId: json['provider_package_id'] is int
          ? json['provider_package_id'] as int
          : int.tryParse(json['provider_package_id']?.toString() ?? ''),
      offering: json['offering'] is Map<String, dynamic>
          ? ProviderAppointmentOffering.fromJson(json['offering'] as Map<String, dynamic>)
          : null,
      status: json['status']?.toString() ?? 'PENDING',
      appointmentDate: json['appointment_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'CASH',
      totalPrice: json['total_price'] is num
          ? (json['total_price'] as num).toDouble()
          : double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      totalDurationMinutes: json['total_duration_minutes'] is int
          ? json['total_duration_minutes'] as int
          : int.tryParse(json['total_duration_minutes']?.toString() ?? '30') ?? 30,
      approxLocation: json['approx_location']?.toString(),
      approxProvince: json['approx_province']?.toString(),
      approxDistrict: json['approx_district']?.toString(),
      approxNeighborhood: json['approx_neighborhood']?.toString(),
      customerNote: json['customer_note']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      disputeReason: json['dispute_reason']?.toString(),
      disputeNote: json['dispute_note']?.toString(),
      disputeSummary: parsedDispute,
      services: parsedServices,
      alternativeSlots: parsedAlternatives,
      requestedAt: json['requested_at'] != null ? DateTime.tryParse(json['requested_at'].toString()) : null,
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at'].toString()) : null,
      rejectedAt: json['rejected_at'] != null ? DateTime.tryParse(json['rejected_at'].toString()) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      serviceStartedAt: json['service_started_at'] != null ? DateTime.tryParse(json['service_started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      disputedAt: json['disputed_at'] != null ? DateTime.tryParse(json['disputed_at'].toString()) : null,
    );
  }
}
