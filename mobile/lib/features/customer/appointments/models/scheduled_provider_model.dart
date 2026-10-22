class ProviderServiceSnapshot {
  final int id;
  final String name;
  final String? categoryId;
  final double customPrice;
  final int customDurationMinutes;

  const ProviderServiceSnapshot({
    required this.id,
    required this.name,
    this.categoryId,
    required this.customPrice,
    required this.customDurationMinutes,
  });

  factory ProviderServiceSnapshot.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    return ProviderServiceSnapshot(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      categoryId: json['category_id']?.toString(),
      customPrice: parseNum(json['custom_price'])?.toDouble() ?? 0.0,
      customDurationMinutes:
          parseNum(json['custom_duration_minutes'])?.toInt() ?? 0,
    );
  }
}

/// Scheduled discovery card data. Contact details (phone/email) and exact
/// address are never part of this model. `rating` / `reviewCount` are the real
/// Tarak review average; `distanceKm` is computed by the backend from the customer's
/// position (providers' coordinates never leave the server).
class ScheduledProviderModel {
  final int id;
  final int userId;
  final String? providerType;
  final String? businessName;
  final String? name;
  final String? avatarUrl;
  final String? city;
  final String? district;
  final int? experienceYears;
  final double? rating;
  final int reviewCount;
  final double? distanceKm;

  /// Running "Liste Reklamı" card (shown with a "Sponsorlu" tag at the top of the list).
  final bool isSponsored;
  final bool isApproved;
  final String? identityStatus;
  final bool isVerified;
  final List<ProviderServiceSnapshot> services;

  const ScheduledProviderModel({
    required this.id,
    required this.userId,
    this.providerType,
    this.businessName,
    this.name,
    this.avatarUrl,
    this.city,
    this.district,
    this.experienceYears,
    this.rating,
    this.reviewCount = 0,
    this.distanceKm,
    this.isSponsored = false,
    this.isApproved = true,
    this.identityStatus,
    this.isVerified = true,
    this.services = const [],
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

  String get locationSummary {
    final parts = <String>[];
    if (district != null && district!.trim().isNotEmpty) {
      parts.add(district!.trim());
    }
    if (city != null && city!.trim().isNotEmpty) {
      parts.add(city!.trim());
    }
    return parts.join(', ');
  }

  factory ScheduledProviderModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    final rawServices = json['services'] as List<dynamic>? ?? [];

    return ScheduledProviderModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      providerType: json['provider_type']?.toString(),
      businessName: json['business_name']?.toString(),
      name: json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      experienceYears: parseNum(json['experience_years'])?.toInt(),
      rating: parseNum(json['rating'])?.toDouble(),
      reviewCount: parseNum(json['review_count'])?.toInt() ?? 0,
      distanceKm: parseNum(json['distance_km'])?.toDouble(),
      isSponsored: json['is_sponsored'] == true,
      isApproved: json['is_approved'] == true,
      identityStatus: json['identity_status']?.toString(),
      isVerified: json['is_verified'] == true,
      services: rawServices
          .whereType<Map<String, dynamic>>()
          .map(ProviderServiceSnapshot.fromJson)
          .toList(),
    );
  }
}
