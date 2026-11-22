import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Shared selector for configurable appointment-reminder lead time (5..1440 min),
/// reused in Customer Settings and Provider Profile without duplicating layout or dialog logic.
class AppointmentReminderMinutesSelector extends StatelessWidget {
  static const List<int> presets = <int>[15, 30, 45, 60, 120];

  final String keyPrefix;
  final int selectedMinutes;
  final bool enabled;
  final bool saving;
  final Future<String?> Function(int minutes) onSelectMinutes;

  const AppointmentReminderMinutesSelector({
    super.key,
    required this.keyPrefix,
    required this.selectedMinutes,
    required this.enabled,
    required this.saving,
    required this.onSelectMinutes,
  });

  Future<void> _openCustomDialog(BuildContext context) async {
    if (!enabled || saving) return;

    // Controller lives strictly inside the StatefulWidget dialog state so it is
    // never disposed while the closing route transition is still animating.
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CustomReminderMinutesDialog(
        keyPrefix: keyPrefix,
        initialMinutes: selectedMinutes,
        onConfirm: onSelectMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !presets.contains(selectedMinutes);
    final customLabel = isCustom ? '$selectedMinutes dk' : 'Özel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hatırlatma süresi (dakika)',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.textSecondary : AppTheme.slate400,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          width: double.infinity,
          child: SingleChildScrollView(
            key: Key('${keyPrefix}_minutes_scroll'),
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final minutes in presets) ...[
                  _DurationPillButton(
                    key: Key('${keyPrefix}_min_$minutes'),
                    label: '$minutes',
                    semanticLabel: '$minutes dakika',
                    selected: selectedMinutes == minutes,
                    enabled: enabled && !saving,
                    onTap: () {
                      if (selectedMinutes != minutes) {
                        onSelectMinutes(minutes);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                _DurationPillButton(
                  key: Key('${keyPrefix}_min_custom'),
                  label: customLabel,
                  semanticLabel: isCustom
                      ? 'Özel süre: $selectedMinutes dakika'
                      : 'Özel dakika seç',
                  selected: isCustom,
                  enabled: enabled && !saving,
                  leadingIcon: isCustom ? Icons.edit_outlined : Icons.tune_rounded,
                  onTap: () => _openCustomDialog(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DurationPillButton extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool selected;
  final bool enabled;
  final IconData? leadingIcon;
  final VoidCallback onTap;

  const _DurationPillButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.enabled,
    this.leadingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (enabled ? AppTheme.primary : AppTheme.slate300)
        : (enabled ? Colors.white : AppTheme.slate50);
    final borderColor = selected
        ? (enabled ? AppTheme.primary : AppTheme.slate300)
        : AppTheme.slate200;
    final fgColor = selected
        ? Colors.white
        : (enabled ? AppTheme.slate700 : AppTheme.slate400);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 34,
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 13, color: fgColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fgColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomReminderMinutesDialog extends StatefulWidget {
  final String keyPrefix;
  final int initialMinutes;
  final Future<String?> Function(int minutes) onConfirm;

  const _CustomReminderMinutesDialog({
    required this.keyPrefix,
    required this.initialMinutes,
    required this.onConfirm,
  });

  @override
  State<_CustomReminderMinutesDialog> createState() =>
      _CustomReminderMinutesDialogState();
}

class _CustomReminderMinutesDialogState
    extends State<_CustomReminderMinutesDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialMinutes}');
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_submitting) return;

    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorText = 'Lütfen dakika değeri girin.');
      return;
    }

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      setState(() => _errorText = 'Yalnızca sayısal bir değer girin.');
      return;
    }

    if (parsed <= 0) {
      setState(() => _errorText = 'Süre 0 veya negatif olamaz (5–1440 dk).');
      return;
    }

    if (parsed < 5 || parsed > 1440) {
      setState(
        () => _errorText = '5 ile 1440 dakika arasında bir değer girin.',
      );
      return;
    }

    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (parsed == widget.initialMinutes) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    String? apiError;
    try {
      apiError = await widget.onConfirm(parsed);
    } catch (_) {
      apiError = 'Hatırlatma süresi kaydedilemedi. Lütfen tekrar deneyin.';
    }

    if (!mounted) return;

    if (apiError == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _errorText = apiError;
      });
    }
  }

  void _handleCancel() {
    if (_submitting) return;
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        child: AlertDialog(
          backgroundColor: Colors.white,
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Özel Hatırlatma Süresi',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Randevudan kaç dakika önce bildirim almak istersiniz? (5–1440 dk)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: Key('${widget.keyPrefix}_custom_minutes_input'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_submitting,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(6)],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSave(),
                  onChanged: (_) {
                    if (_errorText != null && mounted) {
                      setState(() => _errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Dakika',
                    hintText: 'Örn. 75',
                    suffixText: 'dk',
                    errorText: _errorText,
                    errorMaxLines: 2,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: Key('${widget.keyPrefix}_custom_minutes_cancel'),
              onPressed: _submitting ? null : _handleCancel,
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              key: Key('${widget.keyPrefix}_custom_minutes_save'),
              onPressed: _submitting ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
