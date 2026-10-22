class OtherPartyModel {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? role;
  final bool isVerified;

  const OtherPartyModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role,
    this.isVerified = false,
  });

  factory OtherPartyModel.fromJson(Map<String, dynamic> json) {
    return OtherPartyModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Kullanıcı',
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString(),
      isVerified: json['is_verified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role,
      'is_verified': isVerified,
    };
  }
}

class ConversationModel {
  final int id;
  final String resourceType;
  final int resourceId;
  final int customerUserId;
  final int providerUserId;
  final String status;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final OtherPartyModel? otherParty;

  const ConversationModel({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.customerUserId,
    required this.providerUserId,
    required this.status,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.otherParty,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isReadOnly => status.toUpperCase() == 'READ_ONLY';
  bool get isClosed => status.toUpperCase() == 'CLOSED';
  bool get isWritable => isActive;

  String get displayName => otherParty?.name ?? 'Kullanıcı';
  String? get avatarUrl => otherParty?.avatarUrl;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['conversation_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;

    final rawResId = json['resource_id'];
    final resourceId = rawResId is int
        ? rawResId
        : int.tryParse(rawResId?.toString() ?? '0') ?? 0;

    final rawCustId = json['customer_user_id'];
    final customerUserId = rawCustId is int
        ? rawCustId
        : int.tryParse(rawCustId?.toString() ?? '0') ?? 0;

    final rawProvId = json['provider_user_id'];
    final providerUserId = rawProvId is int
        ? rawProvId
        : int.tryParse(rawProvId?.toString() ?? '0') ?? 0;

    final rawUnread = json['unread_count'];
    final unreadCount = rawUnread is int
        ? rawUnread
        : int.tryParse(rawUnread?.toString() ?? '0') ?? 0;

    return ConversationModel(
      id: id,
      resourceType: json['resource_type']?.toString() ?? '',
      resourceId: resourceId,
      customerUserId: customerUserId,
      providerUserId: providerUserId,
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      lastMessagePreview: json['last_message_preview']?.toString(),
      unreadCount: unreadCount,
      otherParty: json['other_party'] is Map<String, dynamic>
          ? OtherPartyModel.fromJson(json['other_party'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': id,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'customer_user_id': customerUserId,
      'provider_user_id': providerUserId,
      'status': status,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message_preview': lastMessagePreview,
      'unread_count': unreadCount,
      'other_party': otherParty?.toJson(),
    };
  }
}
