class CustomerAddress {
  final int id;
  final String? title;
  final String? province;
  final String? district;
  final String? neighborhood;
  final String? street;
  final String? buildingNo;
  final String? apartmentNo;
  final String? directions;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    this.title,
    this.province,
    this.district,
    this.neighborhood,
    this.street,
    this.buildingNo,
    this.apartmentNo,
    this.directions,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  /// Human-friendly one-line representation.
  String get displayLine {
    final parts = <String>[];
    if (neighborhood != null && neighborhood!.isNotEmpty) parts.add(neighborhood!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    return parts.join(', ');
  }

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    num? parseLat(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    return CustomerAddress(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString(),
      province: json['province']?.toString(),
      district: json['district']?.toString(),
      neighborhood: json['neighborhood']?.toString(),
      street: json['street']?.toString(),
      buildingNo: json['building_no']?.toString(),
      apartmentNo: json['apartment_no']?.toString(),
      directions: json['directions']?.toString(),
      latitude: parseLat(json['latitude'])?.toDouble(),
      longitude: parseLat(json['longitude'])?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}
