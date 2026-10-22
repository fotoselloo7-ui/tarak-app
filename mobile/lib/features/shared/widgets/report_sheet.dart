import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../moderation/moderation_repository.dart';

/// Bottom sheet to report a chat message (`MESSAGE`) or a review (`REVIEW`).
/// Shows the server's confirmation in a snackbar once the report is sent.
Future<void> showReportSheet(
  BuildContext context, {
  required String contentType,
  required int contentId,
  String? preview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ReportSheet(
      contentType: contentType,
      contentId: contentId,
      preview: preview,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  final String contentType;
  final int contentId;
  final String? preview;

  const _ReportSheet({
    required this.contentType,
    required this.contentId,
    this.preview,
  });

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _details = TextEditingController();
  String _reason = reportReasons.first.key;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final message = await ref.read(moderationRepositoryProvider).report(
            contentType: widget.contentType,
            contentId: widget.contentId,
            reason: _reason,
            details: _details.text,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.success),
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Bildirim gönderilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contentType == 'MESSAGE' ? 'Mesajı bildir' : 'Değerlendirmeyi bildir';
    final preview = widget.preview?.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppTheme.errorLight, shape: BoxShape.circle),
                  child: const Icon(Icons.flag_rounded, size: 18, color: AppTheme.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _style(17, FontWeight.w800)),
                      Text(
                        'Bildiriminiz yönetici ekibimizce incelenir.',
                        style: _style(12, FontWeight.w400, AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _sending ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            if (preview != null && preview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '“$preview”',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: _style(13, FontWeight.w400),
                ),
              ),
            ],
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) {
                if (!_sending && value != null) setState(() => _reason = value);
              },
              child: Column(
                children: [
                  for (final item in reportReasons)
                    RadioListTile<String>(
                      key: Key('report_reason_${item.key}'),
                      value: item.key,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primary,
                      title: Text(item.value, style: _style(14, FontWeight.w500)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('report_details_field'),
              controller: _details,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ek bilgi (isteğe bağlı)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: _style(13, FontWeight.w500, AppTheme.error)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('report_submit_btn'),
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Bildir'),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _style(double size, FontWeight weight, [Color? color]) => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppTheme.textPrimary,
      );
}
