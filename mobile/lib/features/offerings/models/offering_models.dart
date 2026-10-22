int _int(dynamic v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback);

int? _intOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse(v.toString())));

double _double(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

String? _str(dynamic v) {
  final s = v?.toString();
  return (s == null || s.trim().isEmpty) ? null : s;
}

String formatTry(double amount) {
  final isWhole = amount == amount.roundToDouble();
  final raw = isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final parts = raw.split('.');
  final buf = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write('.');
    buf.write(parts[0][i]);
  }
  return '₺$buf${parts.length > 1 ? ',${parts[1]}' : ''}';
}

/// Catalog service as defined by the platform (global).
class CatalogService {
  final int id;
  final String name;
  final String categoryId;
  final int durationMinutes;
  final double basePrice;

  const CatalogService({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.durationMinutes,
    required this.basePrice,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        categoryId: json['category_id']?.toString() ?? '',
        durationMinutes: _int(json['duration_minutes'], 30),
        basePrice: _double(json['base_price']),
      );
}

class CatalogCategory {
  final String id;
  final String name;
  final List<CatalogService> services;

  const CatalogCategory({required this.id, required this.name, required this.services});

  factory CatalogCategory.fromJson(Map<String, dynamic> json) => CatalogCategory(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        services: (json['services'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogService.fromJson)
            .toList(),
      );
}

/// A catalog service as offered by the logged-in provider (own price/duration).
class MyProviderService {
  final int id;
  final int serviceId;
  final String name;
  final double price;
  final int durationMinutes;
  final String? description;
  final bool isActive;

  const MyProviderService({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.description,
    required this.isActive,
  });

  factory MyProviderService.fromJson(Map<String, dynamic> json) => MyProviderService(
        id: _int(json['id']),
        serviceId: _int(json['service_id']),
        name: json['name']?.toString() ?? '',
        price: _double(json['price']),
        durationMinutes: _int(json['duration_min'], 30),
        description: _str(json['description']),
        isActive: json['is_active'] as bool? ?? false,
      );
}

class PackageServiceRef {
  final int serviceId;
  final String name;

  const PackageServiceRef({required this.serviceId, required this.name});

  factory PackageServiceRef.fromJson(Map<String, dynamic> json) =>
      PackageServiceRef(serviceId: _int(json['service_id']), name: json['name']?.toString() ?? '');
}

class OfferingAvailability {
  final bool available;
  final String? reason;
  final double? distanceKm;

  const OfferingAvailability({required this.available, this.reason, this.distanceKm});

  static const unknown = OfferingAvailability(available: false);

  factory OfferingAvailability.fromJson(Map<String, dynamic>? json) {
    if (json == null) return unknown;
    return OfferingAvailability(
      available: json['available'] as bool? ?? false,
      reason: _str(json['reason']),
      distanceKm: json['distance_km'] == null ? null : _double(json['distance_km']),
    );
  }
}

/// Provider-owned bundle.
class ProviderPackageModel {
  final int id;
  final String title;
  final String? description;
  final double price;

  /// The price before the provider's campaign discount (null when none runs); [price] is already discounted.
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;
  final bool isActive;
  final List<PackageServiceRef> services;
  final OfferingAvailability availability;

  const ProviderPackageModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
    required this.isActive,
    required this.services,
    this.availability = OfferingAvailability.unknown,
  });

  factory ProviderPackageModel.fromJson(Map<String, dynamic> json) => ProviderPackageModel(
        id: _int(json['provider_package_id']),
        title: json['title']?.toString() ?? '',
        description: _str(json['description']),
        price: _double(json['price']),
        originalPrice: json['original_price'] == null ? null : _double(json['original_price']),
        discountPercent: _int(json['discount_percent'], 0),
        durationMinutes: _int(json['duration_minutes'], 30),
        isActive: json['is_active'] as bool? ?? true,
        services: (json['services'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PackageServiceRef.fromJson)
            .toList(),
        availability: OfferingAvailability.fromJson(json['availability'] as Map<String, dynamic>?),
      );
}

/// A provider's service as seen by a customer.
class ServiceOffering {
  final int providerServiceId;
  final int serviceId;
  final String name;
  final String? description;
  final double price;

  /// The price before the provider's campaign discount (null when none runs); [price] is already discounted.
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;
  final OfferingAvailability availability;

  const ServiceOffering({
    required this.providerServiceId,
    required this.serviceId,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
    this.availability = OfferingAvailability.unknown,
  });

  factory ServiceOffering.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? availability}) => ServiceOffering(
        providerServiceId: _int(json['provider_service_id']),
        serviceId: _int(json['service_id']),
        name: json['name']?.toString() ?? '',
        description: _str(json['description']),
        price: _double(json['price']),
        originalPrice: json['original_price'] == null ? null : _double(json['original_price']),
        discountPercent: _int(json['discount_percent'], 0),
        durationMinutes: _int(json['duration_minutes'], 30),
        availability: OfferingAvailability.fromJson(
            availability ?? json['availability'] as Map<String, dynamic>?),
      );
}

/// Public provider card (only real data; rating stays null until reviews exist).
class OfferingProvider {
  final int userId;
  final String name;
  final String? avatarUrl;
  final String? providerType;
  final String? city;
  final String? district;
  final String? bio;
  final bool isVerified;
  final bool isOnline;
  final double? rating;
  final int reviewCount;

  /// From the customer's position (computed by the backend); null when unknown.
  final double? distanceKm;

  /// A running list ad ("Sponsorlu").
  final bool isSponsored;

  const OfferingProvider({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.providerType,
    this.city,
    this.district,
    this.bio,
    this.isVerified = false,
    this.isOnline = false,
    this.rating,
    this.reviewCount = 0,
    this.distanceKm,
    this.isSponsored = false,
  });

  String get region => [district, city].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  String get typeLabel => providerType == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';

  factory OfferingProvider.fromJson(Map<String, dynamic> json) => OfferingProvider(
        userId: _int(json['user_id']),
        name: _str(json['business_name']) ?? json['name']?.toString() ?? '',
        avatarUrl: _str(json['avatar_url']),
        providerType: _str(json['provider_type']),
        city: _str(json['city']),
        district: _str(json['district']),
        bio: _str(json['bio']),
        isVerified: json['is_verified'] as bool? ?? false,
        isOnline: json['is_online'] as bool? ?? false,
        rating: json['rating'] == null ? null : _double(json['rating']),
        reviewCount: _int(json['review_count']),
        distanceKm: json['distance_km'] == null ? null : _double(json['distance_km']),
        isSponsored: json['is_sponsored'] == true,
      );
}

class ServiceProviderResult {
  final OfferingProvider provider;
  final ServiceOffering offering;

  const ServiceProviderResult({required this.provider, required this.offering});

  factory ServiceProviderResult.fromJson(Map<String, dynamic> json) => ServiceProviderResult(
        provider: OfferingProvider.fromJson(json['provider'] as Map<String, dynamic>),
        offering: ServiceOffering.fromJson(
          json['offering'] as Map<String, dynamic>,
          availability: json['availability'] as Map<String, dynamic>?,
        ),
      );
}

/// Organic providers of a service plus the running list ads ("Sponsorlu") for it.
class ServiceProviderList {
  final List<ServiceProviderResult> providers;
  final List<ServiceProviderResult> sponsored;
  final int? rotationSeconds;

  const ServiceProviderList({this.providers = const [], this.sponsored = const [], this.rotationSeconds});

  List<ServiceProviderResult> get all => [...sponsored, ...providers];
}

class ProviderOfferingsBundle {
  final OfferingProvider provider;
  final List<ServiceOffering> services;
  final List<ProviderPackageModel> packages;

  const ProviderOfferingsBundle({required this.provider, required this.services, required this.packages});

  factory ProviderOfferingsBundle.fromJson(Map<String, dynamic> json) => ProviderOfferingsBundle(
        provider: OfferingProvider.fromJson(json['provider'] as Map<String, dynamic>),
        services: (json['services'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => ServiceOffering.fromJson(e))
            .toList(),
        packages: (json['packages'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ProviderPackageModel.fromJson)
            .toList(),
      );
}

/// Immutable snapshot carried by a direct request.
class OfferingSnapshot {
  final String type;
  final String title;
  final String? description;
  final double price;
  final int durationMinutes;
  final List<String> items;
  final String? providerName;

  const OfferingSnapshot({
    required this.type,
    required this.title,
    this.description,
    required this.price,
    required this.durationMinutes,
    this.items = const [],
    this.providerName,
  });

  bool get isPackage => type == 'PACKAGE';

  static OfferingSnapshot? tryParse(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return OfferingSnapshot(
      type: json['type']?.toString() ?? 'SERVICE',
      title: json['title']?.toString() ?? '',
      description: _str(json['description']),
      price: _double(json['price']),
      durationMinutes: _intOrNull(json['duration_minutes']) ?? 30,
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => e['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      providerName: _str(json['provider_name']),
    );
  }
}
