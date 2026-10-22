class ProviderSharedLocationModel {
  final String resourceType;
  final int resourceId;
  final String source;
  final DateTime? sharedAt;
  final DateTime? expiresAt;
  final String? province;
  final String? district;
  final String? neighborhood;
  final String? street;
  final String? buildingNo;
  final String? apartmentNo;
  final String? directions;
  final double? latitude;
  final double? longitude;

  const ProviderSharedLocationModel({
    required this.resourceType,
    required this.resourceId,
    required this.source,
    this.sharedAt,
    this.expiresAt,
    this.province,
    this.district,
    this.neighborhood,
    this.street,
    this.buildingNo,
    this.apartmentNo,
    this.directions,
    this.latitude,
    this.longitude,
  });

  String get fullAddressText {
    final parts = <String>[];
    if (neighborhood != null && neighborhood!.isNotEmpty) parts.add(neighborhood!);
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (buildingNo != null && buildingNo!.isNotEmpty) parts.add('No: $buildingNo');
    if (apartmentNo != null && apartmentNo!.isNotEmpty) parts.add('Daire: $apartmentNo');
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (province != null && province!.isNotEmpty) parts.add(province!);

    if (parts.isEmpty) {
      return 'Konum bilgisi mevcut';
    }
    return parts.join(', ');
  }

  bool get hasExactDetails => street != null || buildingNo != null || neighborhood != null;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isActive => !isExpired && hasExactDetails;


  factory ProviderSharedLocationModel.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final exact = data['exact_location'] is Map<String, dynamic>
        ? data['exact_location'] as Map<String, dynamic>
        : <String, dynamic>{};

    return ProviderSharedLocationModel(
      resourceType: data['resource_type']?.toString() ?? 'INSTANT_REQUEST',
      resourceId: data['resource_id'] is int
          ? data['resource_id'] as int
          : int.tryParse(data['resource_id']?.toString() ?? '') ?? 0,
      source: data['source']?.toString() ?? 'SAVED_ADDRESS',
      sharedAt: data['shared_at'] != null ? DateTime.tryParse(data['shared_at'].toString()) : null,
      expiresAt: data['expires_at'] != null ? DateTime.tryParse(data['expires_at'].toString()) : null,
      province: exact['province']?.toString(),
      district: exact['district']?.toString(),
      neighborhood: exact['neighborhood']?.toString(),
      street: exact['street']?.toString(),
      buildingNo: exact['building_no']?.toString(),
      apartmentNo: exact['apartment_no']?.toString(),
      directions: exact['directions']?.toString(),
      latitude: (exact['latitude'] as num?)?.toDouble(),
      longitude: (exact['longitude'] as num?)?.toDouble(),
    );
  }
}
