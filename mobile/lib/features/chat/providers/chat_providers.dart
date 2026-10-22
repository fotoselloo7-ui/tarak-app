import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/moderation/moderation_repository.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../repositories/chat_repository.dart';
import '../services/realtime_chat_service.dart';

// ── Dependency Providers ─────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(apiClient);
});

final realtimeChatServiceProvider = Provider<RealtimeChatService>((ref) {
  final service = RealtimeChatService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Global Unread Count Provider ─────────────────────────────────────────────

class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() {
    ref.watch(authNotifierProvider.select((state) => state.user?.id));
    fetch();
    return 0;
  }

  Future<void> fetch() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final count = await repo.getUnreadCount();
      state = count;
    } catch (_) {}
  }

  void decrement([int count = 1]) {
    if (state > 0) {
      state = (state - count).clamp(0, 9999);
    }
  }

  void reset() {
    state = 0;
  }
}

final unreadCountProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

// ── Conversations List Provider ──────────────────────────────────────────────

class ConversationsNotifier extends AsyncNotifier<List<ConversationModel>> {
  @override
  Future<List<ConversationModel>> build() async {
    // Conversation summaries (including the other party) belong to this user.
    // Refresh them when customer/provider accounts switch in the same app.
    ref.watch(authNotifierProvider.select((state) => state.user?.id));
    try {
      final repo = ref.watch(chatRepositoryProvider);
      return await repo.getConversations();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(chatRepositoryProvider);
      return repo.getConversations();
    });
  }

  void updateUnread(int conversationId, int unreadCount) {
    state.whenData((list) {
      final updated = list.map((c) {
        if (c.id == conversationId) {
          return ConversationModel(
            id: c.id,
            resourceType: c.resourceType,
            resourceId: c.resourceId,
            customerUserId: c.customerUserId,
            providerUserId: c.providerUserId,
            status: c.status,
            lastMessageAt: c.lastMessageAt,
            lastMessagePreview: c.lastMessagePreview,
            unreadCount: unreadCount,
            otherParty: c.otherParty,
          );
        }
        return c;
      }).toList();
      state = AsyncData(updated);
    });
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ConversationModel>>(
  ConversationsNotifier.new,
);

// ── Single Conversation Messages State & Notifier ─────────────────────────────

class ChatMessagesState {
  final List<ChatMessageModel> messages;
  final bool isLoadingInitial;
  final bool isLoadingOlder;
  final bool isSending;
  final bool hasMoreOlder;
  final int currentPage;
  final int lastPage;
  final String? errorMessage;
  final bool isWritable;

  /// True only when the signed-in user blocked the other party.
  final bool blockedByMe;
  final int? otherUserId;

  const ChatMessagesState({
    this.messages = const [],
    this.isLoadingInitial = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.hasMoreOlder = false,
    this.currentPage = 1,
    this.lastPage = 1,
    this.errorMessage,
    this.isWritable = true,
    this.blockedByMe = false,
    this.otherUserId,
  });

  ChatMessagesState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoadingInitial,
    bool? isLoadingOlder,
    bool? isSending,
    bool? hasMoreOlder,
    int? currentPage,
    int? lastPage,
    String? errorMessage,
    bool clearError = false,
    bool? isWritable,
    bool? blockedByMe,
    int? otherUserId,
  }) {
    return ChatMessagesState(
      blockedByMe: blockedByMe ?? this.blockedByMe,
      otherUserId: otherUserId ?? this.otherUserId,
      messages: messages ?? this.messages,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isWritable: isWritable ?? this.isWritable,
    );
  }
}

class ChatMessagesNotifier extends Notifier<ChatMessagesState> {
  final int conversationId;
  void Function()? _unsubscribeRealtime;
  StreamSubscription? _reconnectSub;

  ChatMessagesNotifier(this.conversationId);

  @override
  ChatMessagesState build() {
    ref.watch(authNotifierProvider.select((state) => state.user?.id));
    ref.onDispose(() {
      _unsubscribeRealtime?.call();
      _reconnectSub?.cancel();
    });

    _setupRealtime();
    _setupReconnect();

    return const ChatMessagesState(isLoadingInitial: true);
  }

  void _setupRealtime() {
    final realtime = ref.read(realtimeChatServiceProvider);
    _unsubscribeRealtime = realtime.subscribeToConversation(
      conversationId,
      (msg) => onRealtimeMessage(msg),
    );
  }

  void _setupReconnect() {
    final realtime = ref.read(realtimeChatServiceProvider);
    _reconnectSub = realtime.onReconnected.listen((_) {
      refreshMessages();
      ref.read(conversationsProvider.notifier).refresh();
      ref.read(unreadCountProvider.notifier).fetch();
    });
  }

  /// Initial load of page 1 messages and mark as read.
  Future<void> loadInitialMessages() async {
    state = state.copyWith(isLoadingInitial: true, clearError: true);
    final repo = ref.read(chatRepositoryProvider);

    try {
      final res = await repo.getMessages(conversationId, page: 1);
      final existingIds = <int>{};
      final uniqueMessages = <ChatMessageModel>[];
      for (final m in res.messages) {
        if (!existingIds.contains(m.id)) {
          existingIds.add(m.id);
          uniqueMessages.add(m);
        }
      }
      state = state.copyWith(
        messages: uniqueMessages,
        isLoadingInitial: false,
        hasMoreOlder: res.hasMoreOlder,
        currentPage: res.currentPage,
        lastPage: res.lastPage,
        isWritable: res.isWritable,
        blockedByMe: res.blockedByMe,
        otherUserId: res.otherUserId,
      );

      // Mark conversation as read
      await markRead();
    } catch (e) {
      state = state.copyWith(
        isLoadingInitial: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Load older messages (pagination upward).
  Future<void> loadMoreOlderMessages() async {
    if (state.isLoadingOlder || !state.hasMoreOlder) return;

    state = state.copyWith(isLoadingOlder: true, clearError: true);
    final repo = ref.read(chatRepositoryProvider);
    final nextPage = state.currentPage + 1;

    try {
      final res = await repo.getMessages(conversationId, page: nextPage);

      // Deduplicate messages by ID
      final existingIds = state.messages.map((m) => m.id).toSet();
      final olderUnique = res.messages.where((m) => !existingIds.contains(m.id)).toList();

      final combined = [...olderUnique, ...state.messages];
      // Deterministic sort: created_at ASC, id ASC
      combined.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return a.id.compareTo(b.id);
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        final cmp = a.createdAt!.compareTo(b.createdAt!);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });

      state = state.copyWith(
        messages: combined,
        isLoadingOlder: false,
        hasMoreOlder: res.hasMoreOlder,
        currentPage: res.currentPage,
        lastPage: res.lastPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingOlder: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Send message with idempotency key and double-send guard.
  Future<bool> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.isSending) return false;

    state = state.copyWith(isSending: true, clearError: true);
    final repo = ref.read(chatRepositoryProvider);
    final idempotencyKey = const Uuid().v4();

    try {
      final serverMsg = await repo.sendMessage(
        conversationId,
        body: cleanText,
        idempotencyKey: idempotencyKey,
      );

      // Deduplicate and append
      final existingIds = state.messages.map((m) => m.id).toSet();
      if (!existingIds.contains(serverMsg.id)) {
        state = state.copyWith(
          messages: [...state.messages, serverMsg],
          isSending: false,
        );
      } else {
        state = state.copyWith(isSending: false);
      }

      // Refresh conversations list preview
      try {
        ref.read(conversationsProvider.notifier).refresh();
      } catch (_) {}
      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Process incoming realtime message from WebSocket.
  void onRealtimeMessage(ChatMessageModel msg) {
    if (msg.conversationId == conversationId) {
      final existingIds = state.messages.map((m) => m.id).toSet();
      if (!existingIds.contains(msg.id)) {
        final updated = [...state.messages, msg];
        state = state.copyWith(messages: updated);
        markRead();
      }
    } else {
      // Message belongs to another conversation -> refresh conversation list & unread count
      ref.read(conversationsProvider.notifier).refresh();
      ref.read(unreadCountProvider.notifier).fetch();
    }
  }

  /// Mark conversation as read and update unread count.
  Future<void> markRead() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final readCount = await repo.markAsRead(conversationId);
      if (readCount > 0) {
        ref.read(unreadCountProvider.notifier).decrement(readCount);
        ref.read(conversationsProvider.notifier).updateUnread(conversationId, 0);
      }
    } catch (_) {}
  }

  /// Full refresh for reconnect reconciliation.
  Future<void> refreshMessages() async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final res = await repo.getMessages(conversationId, page: 1);
      final existingIds = <int>{};
      final uniqueMessages = <ChatMessageModel>[];

      for (final m in [...state.messages, ...res.messages]) {
        if (!existingIds.contains(m.id)) {
          existingIds.add(m.id);
          uniqueMessages.add(m);
        }
      }

      uniqueMessages.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return a.id.compareTo(b.id);
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        final cmp = a.createdAt!.compareTo(b.createdAt!);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });

      state = state.copyWith(
        messages: uniqueMessages,
        isWritable: res.isWritable,
        blockedByMe: res.blockedByMe,
        otherUserId: res.otherUserId,
      );
    } catch (_) {}
  }

  /// Block or unblock the other participant, then re-read the server's composer
  /// state. Returns an error message for the UI, or null on success.
  Future<String?> setOtherUserBlocked(bool blocked) async {
    final otherId = state.otherUserId;
    if (otherId == null) return 'Kullanıcı bilgisi yüklenemedi. Lütfen tekrar deneyin.';
    final moderation = ref.read(moderationRepositoryProvider);
    try {
      if (blocked) {
        await moderation.blockUser(otherId);
      } else {
        await moderation.unblockUser(otherId);
      }
      await refreshMessages();
      ref.read(conversationsProvider.notifier).refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    } catch (_) {
      return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
    }
  }
}

final chatMessagesProvider =
    NotifierProvider.family<ChatMessagesNotifier, ChatMessagesState, int>(
  ChatMessagesNotifier.new,
);
