class ProviderProfileModel {
  final int userId;
  final String? businessName;
  final String providerType;
  final String workMode;
  final bool isApproved;
  final String identityStatus;
  final bool isOnline;
  final bool acceptsNewClients;
  final int serviceRadiusKm;
  final int? experienceYears;
  final bool profileCompleted;
  final String? city;
  final String? district;
  final String? neighborhood;
  final String? street;
  final String? buildingNo;
  final String? addressDetail;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final String? coverUrl;
  final List<String> gallery;

  const ProviderProfileModel({
    required this.userId,
    this.businessName,
    this.providerType = 'barber',
    this.workMode = 'mobile',
    this.isApproved = false,
    this.identityStatus = 'PENDING',
    this.isOnline = false,
    this.acceptsNewClients = true,
    this.serviceRadiusKm = 10,
    this.experienceYears,
    this.profileCompleted = false,
    this.city,
    this.district,
    this.neighborhood,
    this.street,
    this.buildingNo,
    this.addressDetail,
    this.latitude,
    this.longitude,
    this.isVerified = false,
    this.coverUrl,
    this.gallery = const [],
  });

  bool get canWork => isApproved && identityStatus == 'APPROVED';

  factory ProviderProfileModel.fromJson(Map<String, dynamic> json) {
    // Check if wrapped in { "user": ..., "profile": ... }
    final profileData = json.containsKey('profile') && json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : json;

    return ProviderProfileModel(
      userId: profileData['user_id'] is int
          ? profileData['user_id'] as int
          : int.tryParse(profileData['user_id']?.toString() ?? '') ?? 0,
      businessName: profileData['business_name']?.toString(),
      providerType: profileData['provider_type']?.toString() ?? 'barber',
      workMode: profileData['work_mode']?.toString() ?? 'mobile',
      isApproved: profileData['is_approved'] as bool? ?? false,
      identityStatus: profileData['identity_status']?.toString() ?? 'PENDING',
      isOnline: profileData['is_online'] as bool? ?? false,
      acceptsNewClients: profileData['accepts_new_clients'] as bool? ?? true,
      serviceRadiusKm: profileData['service_radius_km'] is int
          ? profileData['service_radius_km'] as int
          : int.tryParse(profileData['service_radius_km']?.toString() ?? '10') ?? 10,
      experienceYears: profileData['experience_years'] is int
          ? profileData['experience_years'] as int
          : int.tryParse(profileData['experience_years']?.toString() ?? ''),
      profileCompleted: profileData['profile_completed'] as bool? ?? false,
      city: profileData['city']?.toString(),
      district: profileData['district']?.toString(),
      neighborhood: profileData['neighborhood']?.toString(),
      street: profileData['street']?.toString(),
      buildingNo: profileData['building_no']?.toString(),
      addressDetail: profileData['address_detail']?.toString(),
      latitude: double.tryParse(profileData['latitude']?.toString() ?? ''),
      longitude: double.tryParse(profileData['longitude']?.toString() ?? ''),
      isVerified: profileData['is_verified'] as bool? ?? false,
      coverUrl: profileData['cover_url']?.toString(),
      gallery: profileData['gallery'] is List
          ? (profileData['gallery'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  ProviderProfileModel copyWith({
    int? userId,
    String? businessName,
    String? providerType,
    String? workMode,
    bool? isApproved,
    String? identityStatus,
    bool? isOnline,
    bool? acceptsNewClients,
    int? serviceRadiusKm,
    int? experienceYears,
    bool? profileCompleted,
    String? city,
    String? district,
    String? neighborhood,
    String? street,
    String? buildingNo,
    String? addressDetail,
    double? latitude,
    double? longitude,
    bool? isVerified,
  }) {
    return ProviderProfileModel(
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      providerType: providerType ?? this.providerType,
      workMode: workMode ?? this.workMode,
      isApproved: isApproved ?? this.isApproved,
      identityStatus: identityStatus ?? this.identityStatus,
      isOnline: isOnline ?? this.isOnline,
      acceptsNewClients: acceptsNewClients ?? this.acceptsNewClients,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      experienceYears: experienceYears ?? this.experienceYears,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      city: city ?? this.city,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
      street: street ?? this.street,
      buildingNo: buildingNo ?? this.buildingNo,
      addressDetail: addressDetail ?? this.addressDetail,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
