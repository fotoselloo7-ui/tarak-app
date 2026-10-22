import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/report_sheet.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';
import '../../../core/widgets/verified_tick.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final String? otherPartyName;

  /// The other party is a verified provider: the blue tick next to the name in the title.
  final bool otherPartyVerified;
  final bool isReadOnly;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.otherPartyName,
    this.otherPartyVerified = false,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isNearBottom = true;
  bool _showScrollToBottom = false;
  // Captured up front: ref must not be used in dispose().
  late final ConversationsNotifier _conversations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _conversations = ref.read(conversationsProvider.notifier);

    // Initial messages fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .loadInitialMessages()
          .then((_) {
        _scrollToBottom(animated: false);
        // Reading the thread clears its unread badge in the list behind it.
        _conversations.refresh();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconcile messages missed while Android suspended the socket. The
      // notifier keeps its existing subscription and deduplicates server IDs.
      final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
      notifier.refreshMessages().then((_) => notifier.markRead());
      ref.read(conversationsProvider.notifier).refresh();
      ref.read(unreadCountProvider.notifier).fetch();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Check if near top to load older messages
    if (currentScroll <= 100) {
      final state = ref.read(chatMessagesProvider(widget.conversationId));
      if (state.hasMoreOlder && !state.isLoadingOlder) {
        ref
            .read(chatMessagesProvider(widget.conversationId).notifier)
            .loadMoreOlderMessages();
      }
    }

    // Check if near bottom
    final distanceToBottom = maxScroll - currentScroll;
    final isNear = distanceToBottom < 120;
    if (isNear != _isNearBottom) {
      setState(() {
        _isNearBottom = isNear;
        _showScrollToBottom = !isNear;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final notifier =
        ref.read(chatMessagesProvider(widget.conversationId).notifier);
    final success = await notifier.sendMessage(text);

    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: true);
      });
    } else {
      final error =
          ref.read(chatMessagesProvider(widget.conversationId)).errorMessage;
      if (mounted && error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleBlock(bool currentlyBlocked) async {
    final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
    final name = widget.otherPartyName ?? 'Bu kullanıcı';
    if (!currentlyBlocked) {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Kullanıcıyı engelle',
        message:
            '$name engellenirse birbirinize mesaj gönderemezsiniz. İstediğiniz zaman engeli kaldırabilirsiniz.',
        confirmText: 'Engelle',
        cancelText: 'Vazgeç',
        isDestructive: true,
      );
      if (confirmed != true || !mounted) return;
    }
    final error = await notifier.setOtherUserBlocked(!currentlyBlocked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? (currentlyBlocked ? 'Engel kaldırıldı.' : 'Kullanıcı engellendi.'),
        ),
        backgroundColor: error == null ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.user?.id ?? 0;
    final chatState =
        ref.watch(chatMessagesProvider(widget.conversationId));
    // Entry points other than the list do not know the status; the server does.
    final readOnly = widget.isReadOnly || !chatState.isWritable;

    // Auto scroll down if user was already at bottom when new message arrives
    ref.listen(
      chatMessagesProvider(widget.conversationId),
      (prev, next) {
        if (prev?.messages.length != next.messages.length && _isNearBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: true);
          });
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ProviderNameRow(
          name: widget.otherPartyName ?? 'Sohbet',
          verified: widget.otherPartyVerified,
          tickSize: 18,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.slate900),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (chatState.otherUserId != null)
            PopupMenuButton<String>(
              key: const Key('chat_menu_btn'),
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.slate900),
              onSelected: (value) {
                if (value == 'block') _toggleBlock(chatState.blockedByMe);
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  key: const Key('chat_block_item'),
                  value: 'block',
                  child: Text(
                    chatState.blockedByMe ? 'Engeli kaldır' : 'Kullanıcıyı engelle',
                    style: const TextStyle(fontFamily: AppTheme.fontFamily),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Read-only or Closed Banner
            if (readOnly)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.warningLight,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFDE68A), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.blockedByMe
                            ? 'Bu kullanıcıyı engellediniz. Mesaj göndermek için engeli kaldırın.'
                            : 'Bu konuşmada artık yeni mesaj gönderilemez.',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (chatState.blockedByMe)
                      TextButton(
                        key: const Key('chat_unblock_btn'),
                        onPressed: () => _toggleBlock(true),
                        child: const Text('Engeli kaldır'),
                      ),
                  ],
                ),
              ),

            // Loading older messages indicator
            if (chatState.isLoadingOlder)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),

            // Messages List or Empty State
            Expanded(
              child: Stack(
                children: [
                  if (chatState.isLoadingInitial)
                    const Center(child: CircularProgressIndicator())
                  else if (chatState.messages.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Henüz mesajınız yok.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatState.messages[index];
                        final isOwn = msg.isOwn(currentUserId);
                        return MessageBubble(
                          key: ValueKey('msg_${msg.id}'),
                          message: msg,
                          isOwn: isOwn,
                          onReport: isOwn
                              ? null
                              : () => showReportSheet(
                                    context,
                                    contentType: 'MESSAGE',
                                    contentId: msg.id,
                                    preview: msg.body,
                                  ),
                        );
                      },
                    ),

                  // Floating "New message / scroll down" button
                  if (_showScrollToBottom)
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: FloatingActionButton.small(
                        backgroundColor: const Color(0xFFFF5722),
                        onPressed: () => _scrollToBottom(animated: true),
                        child: const Icon(Icons.arrow_downward, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Composer (or hidden if read-only)
            if (!readOnly)
              _buildMessageComposer(chatState.isSending),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer(bool isSending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.slate200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input_field'),
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 2000,
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) =>
                  null, // Hide character counter
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14.5,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Mesajınızı yazın...',
                hintStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.slate400,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppTheme.slate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('chat_send_btn'),
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: AppTheme.primary,
                  ),
            onPressed: isSending ? null : _handleSend,
          ),
        ],
      ),
    );
  }
}
