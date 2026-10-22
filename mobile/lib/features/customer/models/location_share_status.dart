class LocationShareGrantModel {
  final int id;
  final String resourceType;
  final int resourceId;
  final String source;
  final String status;
  final DateTime? sharedAt;
  final DateTime? expiresAt;

  const LocationShareGrantModel({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.source,
    required this.status,
    this.sharedAt,
    this.expiresAt,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isRevoked => status == 'REVOKED';
  bool get isExpired => status == 'EXPIRED';

  factory LocationShareGrantModel.fromJson(Map<String, dynamic> json) {
    return LocationShareGrantModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      resourceType: json['resource_type']?.toString() ?? '',
      resourceId: json['resource_id'] is int
          ? json['resource_id'] as int
          : int.tryParse(json['resource_id']?.toString() ?? '') ?? 0,
      source: json['source']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      sharedAt: json['shared_at'] != null
          ? DateTime.tryParse(json['shared_at'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }
}

class LocationShareStatus {
  final bool hasActiveGrant;
  final LocationShareGrantModel? grant;

  const LocationShareStatus({
    required this.hasActiveGrant,
    this.grant,
  });

  bool get isShared => hasActiveGrant && grant?.isActive == true;
  bool get isRevoked => grant?.isRevoked == true;
  bool get isExpired => grant?.isExpired == true;

  String get displayStatus {
    if (isShared) return 'Paylaşıldı';
    if (isRevoked) return 'İptal edildi';
    if (isExpired) return 'Süresi doldu';
    return 'Paylaşılmadı';
  }

  factory LocationShareStatus.fromJson(Map<String, dynamic> json) {
    final grantJson = json['grant'] is Map<String, dynamic>
        ? json['grant'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
            ? (json['data']['grant'] is Map<String, dynamic>
                ? json['data']['grant'] as Map<String, dynamic>
                : json['data'] as Map<String, dynamic>)
            : null);

    return LocationShareStatus(
      hasActiveGrant: json['has_active_grant'] == true ||
          (grantJson != null && grantJson['status'] == 'ACTIVE'),
      grant: grantJson != null
          ? LocationShareGrantModel.fromJson(grantJson)
          : null,
    );
  }
}
