import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/conversation_model.dart';
import '../../../core/widgets/verified_tick.dart';

class ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final local = dt.toLocal();

    if (now.year == local.year && now.month == local.month && now.day == local.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  Widget _avatarFallback(String name) => CircleAvatar(
    radius: 24,
    backgroundColor: AppTheme.primaryLight,
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 18,
        fontWeight: FontWeight.w700, color: AppTheme.primary)),
  );

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherParty;
    final displayName = conversation.displayName;
    final avatarUrl = conversation.avatarUrl;
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.slate200, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: avatarUrl?.trim().isNotEmpty == true
                    ? Image.network(avatarUrl!.trim(), fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarFallback(displayName))
                    : _avatarFallback(displayName),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight:
                                      hasUnread ? FontWeight.w700 : FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (other?.isVerified == true) ...[
                              const SizedBox(width: 4),
                              const VerifiedTick(size: 16),
                            ],
                          ],
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: hasUnread
                                ? AppTheme.primary
                                : AppTheme.slate400,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview ??
                              (conversation.isReadOnly || conversation.isClosed
                                  ? 'Sohbet kapatıldı'
                                  : 'Henüz mesaj yok'),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: hasUnread
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : conversation.unreadCount.toString(),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
