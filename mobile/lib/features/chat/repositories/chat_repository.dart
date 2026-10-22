import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

class PaginatedMessages {
  final List<ChatMessageModel> messages;
  final int currentPage;
  final int lastPage;
  final int total;
  /// Mirrors the server rule that accepts new messages (false once read-only/closed).
  final bool isWritable;

  /// True only when the signed-in user blocked the other party (so they can unblock).
  final bool blockedByMe;

  /// The other participant, used for block/unblock.
  final int? otherUserId;

  const PaginatedMessages({
    required this.messages,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.isWritable = true,
    this.blockedByMe = false,
    this.otherUserId,
  });

  bool get hasMoreOlder => currentPage < lastPage;
}

class ChatRepository {
  final ApiClient _api;

  const ChatRepository(this._api);

  /// List conversations for the authenticated user.
  /// GET /api/conversations
  Future<List<ConversationModel>> getConversations() async {
    final resp = await _api.get('/conversations');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];

    final result = list
        .whereType<Map<String, dynamic>>()
        .map(ConversationModel.fromJson)
        .toList();

    // Deterministic fallback sort: last_message_at DESC
    result.sort((a, b) {
      if (a.lastMessageAt == null && b.lastMessageAt == null) return b.id.compareTo(a.id);
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });

    return result;
  }

  /// Get global unread message count across all conversations.
  /// GET /api/conversations/unread-count
  Future<int> getUnreadCount() async {
    final resp = await _api.get('/conversations/unread-count');
    final data = resp.data as Map<String, dynamic>;
    final count = data['unread_count'] ?? data['count'];
    if (count is int) return count;
    return int.tryParse(count?.toString() ?? '0') ?? 0;
  }

  /// List paginated messages for a conversation.
  /// GET /api/conversations/{conversation}/messages
  Future<PaginatedMessages> getMessages(
    int conversationId, {
    int page = 1,
    int perPage = 30,
  }) async {
    final resp = await _api.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        'page': page,
        'per_page': perPage,
      },
    );

    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    final pagination = data['pagination'] as Map<String, dynamic>? ??
        data['meta'] as Map<String, dynamic>? ??
        data;

    final messages = list
        .whereType<Map<String, dynamic>>()
        .map(ChatMessageModel.fromJson)
        .toList();

    final currentPage = pagination['current_page'] is int
        ? pagination['current_page'] as int
        : int.tryParse(pagination['current_page']?.toString() ?? '1') ?? 1;

    final lastPage = pagination['last_page'] is int
        ? pagination['last_page'] as int
        : int.tryParse(pagination['last_page']?.toString() ?? '1') ?? 1;

    final total = pagination['total'] is int
        ? pagination['total'] as int
        : int.tryParse(pagination['total']?.toString() ?? '0') ?? 0;

    final conversation = data['conversation'];
    final isWritable =
        conversation is Map ? conversation['is_writable'] != false : true;

    final rawOther = conversation is Map ? conversation['other_user_id'] : null;

    return PaginatedMessages(
      messages: messages,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
      isWritable: isWritable,
      blockedByMe: conversation is Map && conversation['blocked_by_me'] == true,
      otherUserId: rawOther is int ? rawOther : int.tryParse(rawOther?.toString() ?? ''),
    );
  }

  /// Send a message to a conversation.
  /// POST /api/conversations/{conversation}/messages
  Future<ChatMessageModel> sendMessage(
    int conversationId, {
    required String body,
    String? idempotencyKey,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        headers['X-Idempotency-Key'] = idempotencyKey;
      }

      final resp = await _api.post(
        '/conversations/$conversationId/messages',
        data: {
          'body': body,
          'idempotency_key': ?idempotencyKey,
        },
        options: headers.isNotEmpty ? Options(headers: headers) : null,
      );

      final data = resp.data as Map<String, dynamic>;
      final msgData = data['data'] as Map<String, dynamic>? ??
          data['message'] as Map<String, dynamic>? ??
          data;
      return ChatMessageModel.fromJson(msgData);
    } on AppException catch (e) {
      if (e.statusCode == 422) {
        // Anti-bypass / content policy or message validation error
        throw AppException(
          message: e.message.isNotEmpty
              ? e.message
              : 'Mesajınız güvenlik ve iletişim politikamız nedeniyle gönderilemedi.',
          statusCode: 422,
        );
      }
      if (e.statusCode == 429) {
        throw const AppException(
          message: 'Çok hızlı mesaj gönderiyorsunuz. Lütfen biraz bekleyin.',
          statusCode: 429,
        );
      }
      if (e.statusCode == 403) {
        // Keep the server's reason: it tells a blocked user apart from a non-participant.
        throw AppException(
          message: e.message.isNotEmpty
              ? e.message
              : 'Bu sohbete mesaj gönderme yetkiniz bulunmamaktadır.',
          statusCode: 403,
        );
      }
      rethrow;
    }
  }

  /// Mark unread messages in conversation as read.
  /// POST /api/conversations/{conversation}/read
  Future<int> markAsRead(int conversationId) async {
    try {
      final resp = await _api.post('/conversations/$conversationId/read');
      final data = resp.data as Map<String, dynamic>;
      final count = data['marked_count'] ?? data['marked_read_count'];
      if (count is int) return count;
      return int.tryParse(count?.toString() ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Resource Conversation Ensure Endpoints ─────────────────────────────────

  /// Customer instant request conversation ensure.
  /// GET /api/customer/service-requests/{id}/conversation
  Future<int> getConversationForCustomerServiceRequest(int requestId) async {
    final resp = await _api.get('/customer/service-requests/$requestId/conversation');
    final data = resp.data as Map<String, dynamic>;
    final convData = data['data'] as Map<String, dynamic>? ??
        data['conversation'] as Map<String, dynamic>? ??
        data;
    final id = convData['id'] ?? convData['conversation_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  /// Provider instant request conversation ensure.
  /// GET /api/provider/service-requests/{id}/conversation
  Future<int> getConversationForProviderServiceRequest(int requestId) async {
    final resp = await _api.get('/provider/service-requests/$requestId/conversation');
    final data = resp.data as Map<String, dynamic>;
    final convData = data['data'] as Map<String, dynamic>? ??
        data['conversation'] as Map<String, dynamic>? ??
        data;
    final id = convData['id'] ?? convData['conversation_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  /// Customer scheduled appointment conversation ensure.
  /// GET /api/customer/appointments/{id}/conversation
  Future<int> getConversationForCustomerAppointment(int appointmentId) async {
    final resp = await _api.get('/customer/appointments/$appointmentId/conversation');
    final data = resp.data as Map<String, dynamic>;
    final convData = data['data'] as Map<String, dynamic>? ??
        data['conversation'] as Map<String, dynamic>? ??
        data;
    final id = convData['id'] ?? convData['conversation_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  /// Provider scheduled appointment conversation ensure.
  /// GET /api/provider/appointments/{id}/conversation
  Future<int> getConversationForProviderAppointment(int appointmentId) async {
    final resp = await _api.get('/provider/appointments/$appointmentId/conversation');
    final data = resp.data as Map<String, dynamic>;
    final convData = data['data'] as Map<String, dynamic>? ??
        data['conversation'] as Map<String, dynamic>? ??
        data;
    final id = convData['id'] ?? convData['conversation_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }
}
