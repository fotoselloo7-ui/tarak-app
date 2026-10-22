class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderUserId;
  final String body;
  final String status;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    this.status = 'SENT',
    this.createdAt,
  });

  bool get isSent => status.toUpperCase() == 'SENT';
  bool get isRead => status.toUpperCase() == 'READ';

  bool isOwn(int currentUserId) => senderUserId == currentUserId;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      conversationId: json['conversation_id'] is int
          ? json['conversation_id'] as int
          : int.tryParse(json['conversation_id']?.toString() ?? '0') ?? 0,
      senderUserId: json['sender_user_id'] is int
          ? json['sender_user_id'] as int
          : int.tryParse(json['sender_user_id']?.toString() ?? '0') ?? 0,
      body: json['body']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'SENT',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_user_id': senderUserId,
      'body': body,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
