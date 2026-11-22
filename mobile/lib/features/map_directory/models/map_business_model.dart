import '../../provider/staff/models/provider_staff_model.dart';

/// Data models for Tarak Harita & İşletme Rehberi.
class ServiceAreaItem {
  final String? id;
  final String province;
  final String district;
  final String? neighborhood;

  const ServiceAreaItem({
    this.id,
    required this.province,
    required this.district,
    this.neighborhood,
  });

  factory ServiceAreaItem.fromJson(Map<String, dynamic> json) {
    final neigh = (json['neighborhood'] ?? '').toString().trim();
    return ServiceAreaItem(
      id: json['id']?.toString(),
      province: (json['province'] ?? '').toString().trim(),
      district: (json['district'] ?? '').toString().trim(),
      neighborhood: neigh.isEmpty ? null : neigh,
    );
  }

  Map<String, dynamic> toJson() => {
        'province': province.trim(),
        'district': district.trim(),
        if (neighborhood != null && neighborhood!.trim().isNotEmpty)
          'neighborhood': neighborhood!.trim(),
      };

  String get displayLabel {
    if (neighborhood != null && neighborhood!.isNotEmpty) {
      return '$neighborhood, $district / $province';
    }
    return '$district / $province';
  }

  String get normalizedKey =>
      '${province.trim().toLowerCase()}|${district.trim().toLowerCase()}|${(neighborhood ?? '').trim().toLowerCase()}';
}

class WorkingHourBreakItem {
  final String startTime;
  final String endTime;

  const WorkingHourBreakItem({
    required this.startTime,
    required this.endTime,
  });

  factory WorkingHourBreakItem.fromJson(Map<String, dynamic> json) {
    return WorkingHourBreakItem(
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
    );
  }
}

class WorkingHourItem {
  final String day;
  final String label;
  final bool enabled;
  final String? startTime;
  final String? endTime;
  final List<WorkingHourBreakItem> breaks;

  const WorkingHourItem({
    required this.day,
    required this.label,
    required this.enabled,
    this.startTime,
    this.endTime,
    this.breaks = const [],
  });

  factory WorkingHourItem.fromJson(Map<String, dynamic> json) {
    final rawBreaks = json['breaks'];
    return WorkingHourItem(
      day: (json['day'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      enabled: json['enabled'] == true,
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      breaks: rawBreaks is List
          ? rawBreaks
              .whereType<Map>()
              .map((b) => WorkingHourBreakItem.fromJson(
                    Map<String, dynamic>.from(b),
                  ))
              .toList()
          : const [],
    );
  }

  String get displayHours {
    if (!enabled) return 'Kapalı';
    if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    }
    return 'Açık';
  }
}

class MapBusinessServiceItem {
  final String id;
  final String providerServiceId;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;

  const MapBusinessServiceItem({
    required this.id,
    required this.providerServiceId,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
  });

  factory MapBusinessServiceItem.fromJson(Map<String, dynamic> json) {
    return MapBusinessServiceItem(
      id: (json['id'] ?? json['service_id'] ?? '').toString(),
      providerServiceId: (json['provider_service_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
    );
  }
}

class MapBusinessPackageItem {
  final String id;
  final String title;
  final String? description;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;
  final List<String> services;

  const MapBusinessPackageItem({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
    this.services = const [],
  });

  factory MapBusinessPackageItem.fromJson(Map<String, dynamic> json) {
    final rawServices = json['services'];
    return MapBusinessPackageItem(
      id: (json['id'] ?? json['provider_package_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      services: rawServices is List
          ? rawServices
              .map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class MapBusinessReviewItem {
  final String id;
  final int rating;
  final String? comment;
  final String customerName;
  final String? createdAt;

  const MapBusinessReviewItem({
    required this.id,
    required this.rating,
    this.comment,
    required this.customerName,
    this.createdAt,
  });

  factory MapBusinessReviewItem.fromJson(Map<String, dynamic> json) {
    return MapBusinessReviewItem(
      id: (json['id'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment']?.toString(),
      customerName: (json['customer_name'] ?? 'Müşteri').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class MapBusinessSummary {
  final String id;
  final String userId;
  final String slug;
  final String? publicUrl;
  final String businessName;
  final String? name;
  final String providerType;
  final String workMode;
  final String? pinImageUrl;
  final String? logoUrl;
  final String? avatarUrl;
  final String? coverUrl;
  final double? rating;
  final int reviewCount;
  final bool isVerified;
  final bool isDemo;
  final bool acceptsTarakBookings;
  final bool isOnline;
  final String? city;
  final String? district;
  final String? neighborhood;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final bool hasPublicPin;
  final bool canGetDirections;
  final double? distanceKm;
  final int serviceCount;
  final int serviceRadiusKm;
  final List<ServiceAreaItem> serviceAreas;

  const MapBusinessSummary({
    required this.id,
    required this.userId,
    required this.slug,
    this.publicUrl,
    required this.businessName,
    this.name,
    required this.providerType,
    required this.workMode,
    this.pinImageUrl,
    this.logoUrl,
    this.avatarUrl,
    this.coverUrl,
    this.rating,
    this.reviewCount = 0,
    this.isVerified = false,
    this.isDemo = false,
    this.acceptsTarakBookings = false,
    this.isOnline = false,
    this.city,
    this.district,
    this.neighborhood,
    this.formattedAddress,
    this.latitude,
    this.longitude,
    this.hasPublicPin = false,
    this.canGetDirections = false,
    this.distanceKm,
    this.serviceCount = 0,
    this.serviceRadiusKm = 15,
    this.serviceAreas = const [],
  });

  factory MapBusinessSummary.fromJson(Map<String, dynamic> json) {
    final mode = (json['work_mode'] ?? 'venue').toString();
    // Client defense-in-depth: never expose coordinates/pin for mobile providers.
    final isMobileOnly = mode == 'mobile';
    final lat = isMobileOnly ? null : (json['latitude'] as num?)?.toDouble();
    final lng = isMobileOnly ? null : (json['longitude'] as num?)?.toDouble();
    final pinAllowed = !isMobileOnly &&
        json['has_public_pin'] == true &&
        lat != null &&
        lng != null;

    final rawAreas = json['service_areas'];
    return MapBusinessSummary(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      publicUrl: json['public_url']?.toString(),
      businessName:
          (json['business_name'] ?? json['name'] ?? 'İşletme').toString(),
      name: json['name']?.toString(),
      providerType: (json['provider_type'] ?? 'barber').toString(),
      workMode: mode,
      pinImageUrl: json['pin_image_url']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] == true,
      isDemo: json['is_demo'] == true,
      acceptsTarakBookings: json['accepts_tarak_bookings'] == true,
      isOnline: json['is_online'] == true,
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      neighborhood: isMobileOnly ? null : json['neighborhood']?.toString(),
      formattedAddress: json['formatted_address']?.toString(),
      latitude: lat,
      longitude: lng,
      hasPublicPin: pinAllowed,
      canGetDirections: pinAllowed && json['can_get_directions'] == true,
      distanceKm: pinAllowed ? (json['distance_km'] as num?)?.toDouble() : null,
      serviceCount: (json['service_count'] as num?)?.toInt() ?? 0,
      serviceRadiusKm: (json['service_radius_km'] as num?)?.toInt() ?? 15,
      serviceAreas: rawAreas is List
          ? rawAreas
              .whereType<Map>()
              .map((a) => ServiceAreaItem.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
    );
  }

  String? get displayImageUrl => pinImageUrl ?? logoUrl ?? avatarUrl ?? coverUrl;

  String get typeLabel =>
      providerType == 'coiffeur' ? 'Kadın Kuaför' : 'Erkek Berber';

  String get workModeLabel {
    switch (workMode) {
      case 'mobile':
        return 'Adrese Gelen';
      case 'both':
        return 'İşletme + Adrese Gelen';
      case 'venue':
      default:
        return 'İşletmede Hizmet';
    }
  }

  String get publicLocationSummary {
    if (formattedAddress != null && formattedAddress!.trim().isNotEmpty) {
      return formattedAddress!;
    }
    final parts = [district, city]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList();
    return parts.isEmpty ? 'Konum belirtilmedi' : parts.join(', ');
  }
}

class MapBusinessDetail {
  final String id;
  final String userId;
  final String slug;
  final String? publicUrl;
  final String businessName;
  final String? name;
  final String? title;
  final String? bio;
  final String providerType;
  final String workMode;
  final bool isVerified;
  final bool directoryListed;
  final String directoryStatus;
  final bool acceptsTarakBookings;
  final bool isOnline;
  final int? experienceYears;
  final String? avatarUrl;
  final String? logoUrl;
  final String? coverUrl;
  final String? pinImageUrl;
  final List<String> gallery;
  final String? city;
  final String? district;
  final String? neighborhood;
  final String? street;
  final String? buildingNo;
  final String? addressDetail;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final bool hasPublicPin;
  final bool canGetDirections;
  final int serviceRadiusKm;
  final List<ServiceAreaItem> serviceAreas;
  final List<WorkingHourItem> workingHours;
  final List<MapBusinessServiceItem> services;
  final List<MapBusinessPackageItem> packages;
  final List<ProviderStaffModel> staff;
  final int serviceCount;
  final int discountPercent;
  final double? rating;
  final int reviewCount;
  final List<MapBusinessReviewItem> reviews;

  const MapBusinessDetail({
    required this.id,
    required this.userId,
    required this.slug,
    this.publicUrl,
    required this.businessName,
    this.name,
    this.title,
    this.bio,
    required this.providerType,
    required this.workMode,
    this.isVerified = false,
    this.directoryListed = false,
    this.directoryStatus = 'NOT_REQUESTED',
    this.acceptsTarakBookings = false,
    this.isOnline = false,
    this.experienceYears,
    this.avatarUrl,
    this.logoUrl,
    this.coverUrl,
    this.pinImageUrl,
    this.gallery = const [],
    this.city,
    this.district,
    this.neighborhood,
    this.street,
    this.buildingNo,
    this.addressDetail,
    this.formattedAddress,
    this.latitude,
    this.longitude,
    this.hasPublicPin = false,
    this.canGetDirections = false,
    this.serviceRadiusKm = 15,
    this.serviceAreas = const [],
    this.workingHours = const [],
    this.services = const [],
    this.packages = const [],
    this.staff = const [],
    this.serviceCount = 0,
    this.discountPercent = 0,
    this.rating,
    this.reviewCount = 0,
    this.reviews = const [],
  });

  factory MapBusinessDetail.fromJson(Map<String, dynamic> json) {
    final mode = (json['work_mode'] ?? 'venue').toString();
    final isMobileOnly = mode == 'mobile';
    final lat = isMobileOnly ? null : (json['latitude'] as num?)?.toDouble();
    final lng = isMobileOnly ? null : (json['longitude'] as num?)?.toDouble();
    final pinAllowed = !isMobileOnly &&
        json['has_public_pin'] == true &&
        lat != null &&
        lng != null;

    final rawGallery = json['gallery'];
    final rawAreas = json['service_areas'];
    final rawHours = json['working_hours'];
    final rawServices = json['services'];
    final rawPackages = json['packages'];
    final rawStaff = json['staff'];
    final rawReviews = json['reviews'];

    return MapBusinessDetail(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      publicUrl: json['public_url']?.toString(),
      businessName:
          (json['business_name'] ?? json['name'] ?? 'İşletme').toString(),
      name: json['name']?.toString(),
      title: json['title']?.toString(),
      bio: json['bio']?.toString(),
      providerType: (json['provider_type'] ?? 'barber').toString(),
      workMode: mode,
      isVerified: json['is_verified'] == true,
      directoryListed: json['directory_listed'] == true,
      directoryStatus: (json['directory_status'] ?? 'NOT_REQUESTED').toString(),
      acceptsTarakBookings: json['accepts_tarak_bookings'] == true,
      isOnline: json['is_online'] == true,
      experienceYears: (json['experience_years'] as num?)?.toInt(),
      avatarUrl: json['avatar_url']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      pinImageUrl: json['pin_image_url']?.toString(),
      gallery: rawGallery is List
          ? rawGallery.map((e) => e.toString()).toList()
          : const [],
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      neighborhood: isMobileOnly ? null : json['neighborhood']?.toString(),
      street: isMobileOnly ? null : json['street']?.toString(),
      buildingNo: isMobileOnly ? null : json['building_no']?.toString(),
      addressDetail: isMobileOnly ? null : json['address_detail']?.toString(),
      formattedAddress: json['formatted_address']?.toString(),
      latitude: lat,
      longitude: lng,
      hasPublicPin: pinAllowed,
      canGetDirections: pinAllowed && json['can_get_directions'] == true,
      serviceRadiusKm: (json['service_radius_km'] as num?)?.toInt() ?? 15,
      serviceAreas: rawAreas is List
          ? rawAreas
              .whereType<Map>()
              .map((a) => ServiceAreaItem.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
      workingHours: rawHours is List
          ? rawHours
              .whereType<Map>()
              .map((h) => WorkingHourItem.fromJson(Map<String, dynamic>.from(h)))
              .toList()
          : const [],
      services: rawServices is List
          ? rawServices
              .whereType<Map>()
              .map((s) =>
                  MapBusinessServiceItem.fromJson(Map<String, dynamic>.from(s)))
              .toList()
          : const [],
      packages: rawPackages is List
          ? rawPackages
              .whereType<Map>()
              .map((p) =>
                  MapBusinessPackageItem.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
      staff: rawStaff is List
          ? rawStaff
              .whereType<Map>()
              .map((m) =>
                  ProviderStaffModel.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      serviceCount: (json['service_count'] as num?)?.toInt() ?? 0,
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      reviews: rawReviews is List
          ? rawReviews
              .whereType<Map>()
              .map((r) =>
                  MapBusinessReviewItem.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : const [],
    );
  }

  String? get displayLogoUrl => pinImageUrl ?? logoUrl ?? avatarUrl;

  String get typeLabel =>
      providerType == 'coiffeur' ? 'Kadın Kuaför' : 'Erkek Berber';

  String get workModeLabel {
    switch (workMode) {
      case 'mobile':
        return 'Adrese Gelen Hizmet';
      case 'both':
        return 'İşletmede & Adrese Gelen';
      case 'venue':
      default:
        return 'İşletmede Hizmet';
    }
  }
}

class MapBusinessesResponse {
  final List<MapBusinessSummary> pins;
  final List<MapBusinessSummary> mobileProviders;
  final String mapStyleUrl;
  final int totalPins;
  final int totalMobile;
  final bool truncated;

  const MapBusinessesResponse({
    required this.pins,
    required this.mobileProviders,
    required this.mapStyleUrl,
    required this.totalPins,
    required this.totalMobile,
    required this.truncated,
  });

  factory MapBusinessesResponse.fromJson(Map<String, dynamic> json) {
    final rawPins = json['data'];
    final rawMobile = json['mobile_providers'];
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};

    return MapBusinessesResponse(
      pins: rawPins is List
          ? rawPins
              .whereType<Map>()
              .map((p) =>
                  MapBusinessSummary.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
      mobileProviders: rawMobile is List
          ? rawMobile
              .whereType<Map>()
              .map((p) =>
                  MapBusinessSummary.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
      mapStyleUrl: (meta['map_style_url'] ??
              'https://tiles.openfreemap.org/styles/liberty')
          .toString(),
      totalPins: (meta['total_pins'] as num?)?.toInt() ?? 0,
      totalMobile: (meta['total_mobile'] as num?)?.toInt() ?? 0,
      truncated: meta['truncated'] == true,
    );
  }
}

class MapBusinessFilter {
  final String? type; // barber | coiffeur
  final String? workMode; // venue | mobile | both
  final String? city;
  final String? district;
  final String? neighborhood;
  final String q;
  final int? radiusKm;
  final double? lat;
  final double? lng;
  final double? minLat;
  final double? maxLat;
  final double? minLng;
  final double? maxLng;
  final bool bookingOnly;
  final bool verifiedOnly;

  const MapBusinessFilter({
    this.type,
    this.workMode,
    this.city,
    this.district,
    this.neighborhood,
    this.q = '',
    this.radiusKm,
    this.lat,
    this.lng,
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
    this.bookingOnly = false,
    this.verifiedOnly = false,
  });

  bool get hasOrigin => lat != null && lng != null;

  bool get hasBounds =>
      minLat != null && maxLat != null && minLng != null && maxLng != null;

  bool get hasActiveFilters =>
      type != null ||
      workMode != null ||
      (city != null && city!.isNotEmpty) ||
      (district != null && district!.isNotEmpty) ||
      (neighborhood != null && neighborhood!.isNotEmpty) ||
      q.trim().isNotEmpty ||
      bookingOnly ||
      verifiedOnly ||
      radiusKm != null ||
      hasBounds;

  MapBusinessFilter copyWith({
    String? type,
    bool clearType = false,
    String? workMode,
    bool clearWorkMode = false,
    String? city,
    bool clearCity = false,
    String? district,
    bool clearDistrict = false,
    String? neighborhood,
    bool clearNeighborhood = false,
    String? q,
    int? radiusKm,
    bool clearRadiusKm = false,
    double? lat,
    double? lng,
    bool clearOrigin = false,
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
    bool clearBounds = false,
    bool? bookingOnly,
    bool? verifiedOnly,
  }) {
    return MapBusinessFilter(
      type: clearType ? null : (type ?? this.type),
      workMode: clearWorkMode ? null : (workMode ?? this.workMode),
      city: clearCity ? null : (city ?? this.city),
      district: clearDistrict ? null : (district ?? this.district),
      neighborhood:
          clearNeighborhood ? null : (neighborhood ?? this.neighborhood),
      q: q ?? this.q,
      radiusKm: clearRadiusKm ? null : (radiusKm ?? this.radiusKm),
      lat: clearOrigin ? null : (lat ?? this.lat),
      lng: clearOrigin ? null : (lng ?? this.lng),
      minLat: clearBounds ? null : (minLat ?? this.minLat),
      maxLat: clearBounds ? null : (maxLat ?? this.maxLat),
      minLng: clearBounds ? null : (minLng ?? this.minLng),
      maxLng: clearBounds ? null : (maxLng ?? this.maxLng),
      bookingOnly: bookingOnly ?? this.bookingOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    return {
      if (type != null) 'type': type,
      if (workMode != null) 'work_mode': workMode,
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (district != null && district!.trim().isNotEmpty)
        'district': district!.trim(),
      if (neighborhood != null && neighborhood!.trim().isNotEmpty)
        'neighborhood': neighborhood!.trim(),
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (lat != null && lng != null) ...{
        'lat': lat,
        'lng': lng,
      },
      if (lat != null && lng != null && radiusKm != null)
        'radius_km': radiusKm,
      if (hasBounds) ...{
        'min_lat': minLat,
        'max_lat': maxLat,
        'min_lng': minLng,
        'max_lng': maxLng,
      },
      if (bookingOnly) 'booking_only': 1,
      if (verifiedOnly) 'verified_only': 1,
      'include_mobile': 1,
      'limit': 5000,
    };
  }
}
