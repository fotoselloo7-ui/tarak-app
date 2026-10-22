import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/chat_providers.dart';
import '../widgets/conversation_card.dart';
import 'chat_screen.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Mesajlar',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () =>
                  ref.read(conversationsProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: const EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Henüz mesajınız yok.',
                      description: 'Aktif talepleriniz ve randevularınızdaki mesajlaşmalar burada listelenir.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () =>
                ref.read(conversationsProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return ConversationCard(
                  key: ValueKey('conv_${conv.id}'),
                  conversation: conv,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: conv.id,
                          otherPartyName: conv.displayName,
                          otherPartyVerified: conv.otherParty?.isVerified == true,
                          isReadOnly: conv.isReadOnly || conv.isClosed,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => ErrorState(
          message: 'Mesajlar yüklenemedi: $error',
          onRetry: () =>
              ref.read(conversationsProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
