import 'service_request_model.dart';

class ServiceOffer {
  final int id;
  final int serviceRequestId;
  final int providerUserId;
  final double price;
  final int durationMinutes;
  final int? estimatedArrivalMin;
  final String? paymentPreference;
  final String? message;
  final String status;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? createdAt;
  final OfferProvider? provider;
  final ServiceRequestModel? serviceRequest;

  const ServiceOffer({
    required this.id,
    required this.serviceRequestId,
    required this.providerUserId,
    required this.price,
    required this.durationMinutes,
    this.estimatedArrivalMin,
    this.paymentPreference,
    this.message,
    required this.status,
    this.acceptedAt,
    this.rejectedAt,
    this.createdAt,
    this.provider,
    this.serviceRequest,
  });

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';

  factory ServiceOffer.fromJson(Map<String, dynamic> json) {
    return ServiceOffer(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      serviceRequestId: json['service_request_id'] is int
          ? json['service_request_id'] as int
          : int.tryParse(json['service_request_id'].toString()) ?? 0,
      providerUserId: json['provider_user_id'] is int
          ? json['provider_user_id'] as int
          : int.tryParse(json['provider_user_id'].toString()) ?? 0,
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      durationMinutes: json['duration_minutes'] is int
          ? json['duration_minutes'] as int
          : int.tryParse(json['duration_minutes'].toString()) ?? 0,
      estimatedArrivalMin: json['estimated_arrival_min'] is int
          ? json['estimated_arrival_min'] as int
          : int.tryParse(json['estimated_arrival_min']?.toString() ?? ''),
      paymentPreference: json['payment_preference']?.toString(),
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'].toString()) : null,
      rejectedAt: json['rejected_at'] != null ? DateTime.tryParse(json['rejected_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      provider: json['provider'] != null ? OfferProvider.fromJson(json['provider'] as Map<String, dynamic>) : null,
      serviceRequest: json['service_request'] != null
          ? ServiceRequestModel.fromJson(json['service_request'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OfferProvider {
  final int id;
  final String name;
  final String? businessName;
  final String? providerType;
  final String? city;
  final String? district;
  final int? experienceYears;
  final bool isVerified;
  final String? avatarUrl;

  const OfferProvider({
    required this.id,
    required this.name,
    this.businessName,
    this.providerType,
    this.city,
    this.district,
    this.experienceYears,
    this.isVerified = false,
    this.avatarUrl,
  });

  String get displayName => businessName ?? name;

  factory OfferProvider.fromJson(Map<String, dynamic> json) {
    return OfferProvider(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      businessName: json['business_name']?.toString(),
      providerType: json['provider_type']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      experienceYears: json['experience_years'] is int
          ? json['experience_years'] as int
          : int.tryParse(json['experience_years']?.toString() ?? ''),
      isVerified: json['is_verified'] as bool? ?? false,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
