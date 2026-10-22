import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/provider_schedule_model.dart';
import '../providers/provider_appointment_providers.dart';

class ProviderScheduleScreen extends ConsumerStatefulWidget {
  const ProviderScheduleScreen({super.key});

  @override
  ConsumerState<ProviderScheduleScreen> createState() =>
      _ProviderScheduleScreenState();
}

class _ProviderScheduleScreenState extends ConsumerState<ProviderScheduleScreen> {
  List<ProviderWeeklyScheduleModel>? _localSchedules;
  bool _isSaving = false;

  final List<String> _daysOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(providerScheduleNotifierProvider);
    final closedDatesAsync = ref.watch(providerClosedDatesNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Çalışma Programı & İzinler',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.slate900,
        elevation: 0,
        actions: [
          if (_localSchedules != null)
            TextButton.icon(
              key: const Key('save_schedule_btn'),
              onPressed: _isSaving ? null : _saveSchedule,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF5722),
                      ),
                    )
                  : const Icon(Icons.save_outlined, color: Color(0xFFFF5722)),
              label: Text(
                _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                style: const TextStyle(
                  color: Color(0xFFFF5722),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(providerScheduleNotifierProvider.notifier).refresh();
          await ref.read(providerClosedDatesNotifierProvider.notifier).refresh();
          setState(() {
            _localSchedules = null;
          });
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1: Weekly Work Hours ─────────────────────────────────
            const Text(
              'Haftalık Çalışma Saatleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Çalıştığınız günleri, mesai ve mola saatlerinizi belirleyin.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            scheduleAsync.when(
              data: (schedules) {
                _localSchedules ??= _normalizeSchedules(schedules);
                return Column(
                  children: _localSchedules!.map((daySchedule) {
                    return _buildDayCard(daySchedule);
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                ),
              ),
              error: (err, _) => Card(
                color: const Color(0xFFFEF2F2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Program yüklenemedi: $err',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Section 2: Closed Dates ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Özel Kapalı Günler & İzinler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Resmi tatil, izin ve randevu almayacağınız günler.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  key: const Key('add_closed_date_btn'),
                  onPressed: _showAddClosedDateDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            closedDatesAsync.when(
              data: (closedDates) {
                if (closedDates.isEmpty) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    color: Colors.white,
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Kayıtlı kapalı gün bulunmuyor.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: closedDates.map((cd) {
                    return Card(
                      key: Key('closed_date_item_${cd.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.event_busy,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        title: Text(
                          cd.date,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          cd.reason +
                              (cd.note != null && cd.note!.isNotEmpty
                                  ? ' (${cd.note})'
                                  : ''),
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        trailing: IconButton(
                          key: Key('delete_closed_date_${cd.id}'),
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFDC2626)),
                          onPressed: () => _deleteClosedDate(cd.id),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                ),
              ),
              error: (err, _) => Text(
                'Kapalı günler yüklenemedi: $err',
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<ProviderWeeklyScheduleModel> _normalizeSchedules(
      List<ProviderWeeklyScheduleModel> server) {
    final list = <ProviderWeeklyScheduleModel>[];
    for (final day in _daysOrder) {
      final existing = server.firstWhere(
        (s) => s.day.toLowerCase() == day,
        orElse: () => ProviderWeeklyScheduleModel(
          day: day,
          dayOfWeek: day,
          isEnabled: day != 'sunday',
          startTime: '09:00',
          endTime: '19:00',
          breaks: const [],
        ),
      );
      list.add(existing);
    }
    return list;
  }

  Widget _buildDayCard(ProviderWeeklyScheduleModel daySchedule) {
    return Card(
      key: Key('schedule_day_${daySchedule.day}'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: daySchedule.isEnabled
              ? const Color(0xFFCBD5E1)
              : const Color(0xFFE2E8F0),
        ),
      ),
      elevation: 0,
      color: daySchedule.isEnabled ? Colors.white : const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  daySchedule.dayLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: daySchedule.isEnabled
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                Switch(
                  key: Key('toggle_day_${daySchedule.day}'),
                  value: daySchedule.isEnabled,
                  activeColor: const Color(0xFFFF5722),
                  onChanged: (val) {
                    _updateScheduleDay(daySchedule.copyWith(isEnabled: val));
                  },
                ),
              ],
            ),
            if (daySchedule.isEnabled) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePickerField(
                      label: 'Mesai Başlangıç',
                      time: daySchedule.startTime,
                      onSelect: (newTime) {
                        _updateScheduleDay(
                            daySchedule.copyWith(startTime: newTime));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimePickerField(
                      label: 'Mesai Bitiş',
                      time: daySchedule.endTime,
                      onSelect: (newTime) {
                        _updateScheduleDay(
                            daySchedule.copyWith(endTime: newTime));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Breaks list
              if (daySchedule.breaks.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Mola Saatleri:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                ...daySchedule.breaks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final brk = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.coffee, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Text(
                          '${brk.startTime} - ${brk.endTime}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          key: Key('remove_break_${daySchedule.day}_$idx'),
                          icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                          onPressed: () {
                            final updatedBreaks =
                                List<ProviderScheduleBreakModel>.from(daySchedule.breaks);
                            updatedBreaks.removeAt(idx);
                            _updateScheduleDay(
                                daySchedule.copyWith(breaks: updatedBreaks));
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Add break button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('add_break_${daySchedule.day}'),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Mola Ekle',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                  ),
                  onPressed: () => _showAddBreakDialog(daySchedule),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required String time,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final parts = time.split(':');
            final initialTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
            );
            final picked = await showTimePicker(
              context: context,
              initialTime: initialTime,
            );
            if (picked != null) {
              final formatted =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              onSelect(formatted);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updateScheduleDay(ProviderWeeklyScheduleModel updated) {
    if (_localSchedules == null) return;
    setState(() {
      final idx = _localSchedules!.indexWhere((s) => s.day == updated.day);
      if (idx >= 0) {
        _localSchedules![idx] = updated;
      }
    });
  }

  void _showAddBreakDialog(ProviderWeeklyScheduleModel daySchedule) {
    String startTime = '13:00';
    String endTime = '14:00';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${daySchedule.dayLabel} - Mola Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimePickerField(
                label: 'Mola Başlangıç',
                time: startTime,
                onSelect: (val) => setDialogState(() => startTime = val),
              ),
              const SizedBox(height: 12),
              _buildTimePickerField(
                label: 'Mola Bitiş',
                time: endTime,
                onSelect: (val) => setDialogState(() => endTime = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              key: const Key('confirm_add_break_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
              ),
              onPressed: () {
                final updatedBreaks =
                    List<ProviderScheduleBreakModel>.from(daySchedule.breaks);
                updatedBreaks.add(ProviderScheduleBreakModel(
                  startTime: startTime,
                  endTime: endTime,
                ));
                _updateScheduleDay(daySchedule.copyWith(breaks: updatedBreaks));
                Navigator.pop(ctx);
              },
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClosedDateDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final reasonController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kapalı Gün / İzin Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tarih'),
                  subtitle: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFFFF5722)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  key: const Key('closed_date_reason_input'),
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Sebep (Örn: Yıllık İzin, Tadilat)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('closed_date_note_input'),
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ek Not (Opsiyonel)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              key: const Key('confirm_store_closed_date_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
              ),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;
                final dateStr =
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(providerClosedDatesNotifierProvider.notifier)
                      .addClosedDate(
                        date: dateStr,
                        reason: reasonController.text.trim(),
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kapalı gün eklendi.'),
                        backgroundColor: Color(0xFF059669),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteClosedDate(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kapalı Günü Sil'),
        content: const Text('Bu kapalı gün kaydını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(providerClosedDatesNotifierProvider.notifier)
            .deleteClosedDate(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kapalı gün silindi.'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silinemedi: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveSchedule() async {
    if (_localSchedules == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ref
          .read(providerScheduleNotifierProvider.notifier)
          .updateSchedule(_localSchedules!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çalışma programı başarıyla güncellendi.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydedilemedi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
