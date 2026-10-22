import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/chat_message_model.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isOwn;

  /// Shown as a small flag next to the other party's messages.
  final VoidCallback? onReport;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.onReport,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isOwn ? AppTheme.primary : AppTheme.slate100;
    final textColor = isOwn ? Colors.white : AppTheme.textPrimary;
    final timeColor = isOwn ? Colors.white.withAlpha(200) : AppTheme.slate400;

    final bubble = Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOwn ? 16 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.body,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14.5,
                color: textColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.createdAt != null)
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: timeColor,
                    ),
                  ),
                if (isOwn) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (isOwn || onReport == null) return bubble;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: bubble),
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 2),
          child: IconButton(
            key: Key('report_message_${message.id}'),
            tooltip: 'Mesajı bildir',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: AppTheme.slate400,
            icon: const Icon(Icons.flag_outlined),
            onPressed: onReport,
          ),
        ),
      ],
    );
  }
}
