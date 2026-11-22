import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../appointments/models/provider_schedule_model.dart';
import '../models/provider_staff_model.dart';
import '../repositories/provider_staff_repository.dart';

class ProviderStaffScreen extends ConsumerStatefulWidget {
  const ProviderStaffScreen({super.key});

  @override
  ConsumerState<ProviderStaffScreen> createState() =>
      _ProviderStaffScreenState();
}

class _ProviderStaffScreenState extends ConsumerState<ProviderStaffScreen> {
  bool _loading = true;
  String? _error;
  List<ProviderStaffModel> _staff = const [];
  List<ProviderOfferedServiceOption> _offeredServices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(providerStaffRepositoryProvider);
      final results = await Future.wait([
        repo.fetchStaff(),
        repo.fetchOfferedServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _staff = results[0] as List<ProviderStaffModel>;
        _offeredServices = results[1] as List<ProviderOfferedServiceOption>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'Çalışan listesi yüklenemedi.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([ProviderStaffModel? existing]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProviderStaffEditorScreen(
          existing: existing,
          offeredServices: _offeredServices,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _archiveStaff(ProviderStaffModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çalışanı Pasife Al / Arşivle'),
        content: Text(
          '${staff.fullName} artık yeni randevular için seçilemeyecek. '
          'Geçmiş ve mevcut randevu kayıtları silinmeden korunacaktır. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Arşivle'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(providerStaffRepositoryProvider).archiveStaff(staff.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${staff.fullName} arşivlendi. Geçmiş kayıtlar korundu.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException && e.message.isNotEmpty
          ? e.message
          : 'Çalışan arşivlenemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _staff.where((s) => !s.isArchived && s.isActive).toList();
    final archived = _staff.where((s) => s.isArchived || !s.isActive).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Çalışanlarım',
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
          TextButton.icon(
            key: const Key('add_staff_btn'),
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text(
              'Çalışan Ekle',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.slate200),
                        ),
                        child: const Text(
                          'Her ustanın verdiği hizmetleri, özel işlem sürelerini, çalışma saatlerini ve izin günlerini ayrı yönetin. Çalışanı olan işletmelerde her çalışanın takvimi bağımsızdır.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_staff.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.slate200),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.groups_2_outlined,
                                size: 48,
                                color: AppTheme.slate300,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Henüz ekli çalışan yok',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tek kişilik çalışıyorsanız mevcut takviminiz aynen devam eder. Salonunuzda çalışan ustalar varsa hemen ekleyebilirsiniz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add),
                                label: const Text('İlk Çalışanı Ekle'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        if (active.isNotEmpty) ...[
                          Text(
                            'Aktif Çalışanlar (${active.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.slate700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final member in active)
                            _StaffCard(
                              staff: member,
                              onEdit: () => _openEditor(member),
                              onArchive: () => _archiveStaff(member),
                            ),
                        ],
                        if (archived.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Pasif / Arşivlenenler (${archived.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.slate500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final member in archived)
                            _StaffCard(
                              staff: member,
                              onEdit: () => _openEditor(member),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final ProviderStaffModel staff;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

  const _StaffCard({
    required this.staff,
    required this.onEdit,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      _StatusPill(
        label: staff.isActive ? 'Aktif' : 'Pasif',
        color: staff.isActive ? const Color(0xFF059669) : AppTheme.slate500,
      ),
      if (staff.isActive)
        _StatusPill(
          label: staff.acceptsAppointments
              ? 'Randevuya Açık'
              : 'Randevu Kapalı',
          color: staff.acceptsAppointments
              ? AppTheme.primary
              : const Color(0xFFD97706),
        ),
      if (staff.isActive)
        _StatusPill(
          label: staff.visibleToCustomers ? 'Müşteriye Açık' : 'Gizli',
          color: staff.visibleToCustomers
              ? const Color(0xFF2563EB)
              : AppTheme.slate500,
        ),
    ];

    return Container(
      key: Key('staff_card_${staff.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(
                    radius: 24,
                    imageUrl: staff.photoUrl,
                    name: staff.fullName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.fullName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (staff.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            staff.subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${staff.services.length} hizmet • ${staff.timeOffs.length} izin kaydı',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('edit_staff_${staff.id}'),
                    tooltip: 'Düzenle',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                  if (onArchive != null)
                    IconButton(
                      key: Key('archive_staff_${staff.id}'),
                      tooltip: 'Arşivle',
                      icon: Icon(
                        Icons.archive_outlined,
                        size: 20,
                        color: Colors.red.shade600,
                      ),
                      onPressed: onArchive,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: badges),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ProviderStaffEditorScreen extends ConsumerStatefulWidget {
  final ProviderStaffModel? existing;
  final List<ProviderOfferedServiceOption> offeredServices;

  const _ProviderStaffEditorScreen({
    this.existing,
    required this.offeredServices,
  });

  @override
  ConsumerState<_ProviderStaffEditorScreen> createState() =>
      _ProviderStaffEditorScreenState();
}

class _ProviderStaffEditorScreenState
    extends ConsumerState<_ProviderStaffEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _specialtyCtrl;

  late bool _isActive;
  late bool _acceptsAppointments;
  late bool _visibleToCustomers;
  String? _photoUrl;
  String? _pendingPhotoPath;

  late Map<int, int?> _selectedServices;
  final Map<int, TextEditingController> _durationControllers = {};
  late List<ProviderWeeklyScheduleModel> _schedule;
  late List<ProviderStaffTimeOffModel> _timeOffs;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _firstNameCtrl = TextEditingController(text: e?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: e?.lastName ?? '');
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _specialtyCtrl = TextEditingController(text: e?.specialty ?? '');

    _isActive = e?.isActive ?? true;
    _acceptsAppointments = e?.acceptsAppointments ?? true;
    _visibleToCustomers = e?.visibleToCustomers ?? true;
    _photoUrl = e?.photoUrl;

    _selectedServices = {};
    if (e != null) {
      for (final s in e.services) {
        _selectedServices[s.serviceId] = s.customDurationMinutes;
      }
    } else {
      for (final s in widget.offeredServices) {
        _selectedServices[s.serviceId] = null;
      }
    }

    for (final opt in widget.offeredServices) {
      final current = _selectedServices[opt.serviceId];
      _durationControllers[opt.serviceId] = TextEditingController(
        text: current != null ? '$current' : '',
      );
    }

    final existingSchedule = e?.schedule ?? const <ProviderWeeklyScheduleModel>[];
    _schedule = existingSchedule.length == 7
        ? List<ProviderWeeklyScheduleModel>.from(existingSchedule)
        : ProviderStaffModel.defaultSchedule();
    _timeOffs = List<ProviderStaffTimeOffModel>.from(e?.timeOffs ?? const []);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _titleCtrl.dispose();
    _specialtyCtrl.dispose();
    for (final ctrl in _durationControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final servicePayload = <Map<String, dynamic>>[];
    for (final entry in _selectedServices.entries) {
      final rawDur = _durationControllers[entry.key]?.text.trim() ?? '';
      final parsedDur = rawDur.isEmpty ? null : int.tryParse(rawDur);
      servicePayload.add({
        'service_id': entry.key,
        if (parsedDur != null && parsedDur >= 5 && parsedDur <= 480)
          'custom_duration_minutes': parsedDur,
      });
    }

    final payload = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'title': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      'specialty':
          _specialtyCtrl.text.trim().isEmpty ? null : _specialtyCtrl.text.trim(),
      'is_active': _isActive,
      'accepts_appointments': _acceptsAppointments,
      'visible_to_customers': _visibleToCustomers,
      'services': servicePayload,
      'schedule': _schedule.map((d) => d.toJson()).toList(),
    };

    try {
      final repo = ref.read(providerStaffRepositoryProvider);
      if (widget.existing == null) {
        final created = await repo.createStaff(payload);
        if (_pendingPhotoPath != null && created.id > 0) {
          try {
            await repo.uploadPhoto(created.id, _pendingPhotoPath!);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Çalışan eklendi ancak profil fotoğrafı yüklenemedi.'),
                ),
              );
            }
          }
        }
      } else {
        await repo.updateStaff(widget.existing!.id, payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'Çalışan kaydedilemedi.';
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final staffId = widget.existing?.id;
    if (staffId == null) {
      setState(() => _pendingPhotoPath = picked.path);
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      final url = await ref
          .read(providerStaffRepositoryProvider)
          .uploadPhoto(staffId, picked.path);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException && e.message.isNotEmpty
                ? e.message
                : 'Fotoğraf yüklenemedi.',
          ),
        ),
      );
    }
  }

  Future<void> _removePhoto() async {
    final staffId = widget.existing?.id;
    if (_uploadingPhoto) return;
    if (staffId == null) {
      setState(() => _pendingPhotoPath = null);
      return;
    }
    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(providerStaffRepositoryProvider).deletePhoto(staffId);
      if (!mounted) return;
      setState(() {
        _photoUrl = null;
        _uploadingPhoto = false;
      });
    } catch (_) {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _addTimeOffDialog() async {
    final staffId = widget.existing?.id;
    if (staffId == null) return;

    DateTime startDate = DateTime.now();
    DateTime endDate = startDate;
    bool allDay = true;
    TimeOfDay startTime = const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 14, minute: 0);
    final reasonCtrl = TextEditingController(text: 'İzin');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String fmtDate(DateTime d) =>
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          String fmtTod(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            scrollable: true,
            title: const Text('Çalışan İzni Ekle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Başlangıç Tarihi'),
                  subtitle: Text(fmtDate(startDate)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                        if (endDate.isBefore(picked)) endDate = picked;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bitiş Tarihi'),
                  subtitle: Text(fmtDate(endDate)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tüm Gün İzinli'),
                  value: allDay,
                  onChanged: (v) => setDialogState(() => allDay = v),
                ),
                if (!allDay)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: startTime,
                            );
                            if (t != null) setDialogState(() => startTime = t);
                          },
                          child: Text('Başlangıç: ${fmtTod(startTime)}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: endTime,
                            );
                            if (t != null) setDialogState(() => endTime = t);
                          },
                          child: Text('Bitiş: ${fmtTod(endTime)}'),
                        ),
                      ),
                    ],
                  ),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Neden (opsiyonel)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || !mounted) {
      reasonCtrl.dispose();
      return;
    }

    String fmtDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTod(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    try {
      final added = await ref.read(providerStaffRepositoryProvider).addTimeOff(
        staffId,
        {
          'start_date': fmtDate(startDate),
          'end_date': fmtDate(endDate),
          if (!allDay) 'start_time': fmtTod(startTime),
          if (!allDay) 'end_time': fmtTod(endTime),
          'reason': reasonCtrl.text.trim().isEmpty
              ? 'izin'
              : reasonCtrl.text.trim(),
        },
      );
      if (mounted) {
        setState(() => _timeOffs.add(added));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException && e.message.isNotEmpty
                  ? e.message
                  : 'İzin kaydedilemedi.',
            ),
          ),
        );
      }
    } finally {
      reasonCtrl.dispose();
    }
  }

  Future<void> _pickScheduleTime(int idx, bool isStart) async {
    final day = _schedule[idx];
    final raw = isStart ? day.startTime : day.endTime;
    final parts = raw.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _schedule[idx] = isStart
          ? day.copyWith(startTime: formatted)
          : day.copyWith(endTime: formatted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final fullName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Çalışanı Düzenle' : 'Yeni Çalışan'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.slate900,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              key: const Key('staff_photo_section'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Çalışan Profil Fotoğrafı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!kIsWeb && _pendingPhotoPath != null)
                        ClipOval(
                          child: Image.file(
                            File(_pendingPhotoPath!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        AppAvatar(
                          radius: 28,
                          imageUrl: _photoUrl,
                          name: fullName.isEmpty ? 'Usta' : fullName,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('staff_pick_photo_btn'),
                              onPressed:
                                  _uploadingPhoto ? null : _pickAndUploadPhoto,
                              icon: const Icon(Icons.photo_camera_outlined, size: 16),
                              label: Text(
                                _uploadingPhoto
                                    ? 'Yükleniyor...'
                                    : (_pendingPhotoPath != null ||
                                            (_photoUrl != null && _photoUrl!.isNotEmpty))
                                        ? 'Fotoğrafı Değiştir'
                                        : 'Fotoğraf Seç',
                              ),
                            ),
                            if (_pendingPhotoPath != null ||
                                (_photoUrl != null && _photoUrl!.isNotEmpty))
                              TextButton(
                                key: const Key('staff_remove_photo_btn'),
                                onPressed: _uploadingPhoto ? null : _removePhoto,
                                child: const Text(
                                  'Kaldır',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Temel Bilgiler',
              children: [
                TextFormField(
                  key: const Key('staff_first_name_input'),
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ad',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Ad alanı zorunludur.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('staff_last_name_input'),
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Soyad',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Soyad alanı zorunludur.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('staff_title_input'),
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unvan / Pozisyon (Örn. Baş Berber)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('staff_specialty_input'),
                  controller: _specialtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Uzmanlık Alanı (Örn. Fade & Sakal)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Durum ve Görünürlük',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif Çalışan'),
                  value: _isActive,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Randevu Kabul Ediyor'),
                  value: _acceptsAppointments,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _acceptsAppointments = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Müşteri Seçiminde Görünür'),
                  value: _visibleToCustomers,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _visibleToCustomers = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Verdiği Hizmetler ve Özel Süreler',
              children: [
                if (widget.offeredServices.isEmpty)
                  const Text(
                    'İşletmenizde henüz tanımlı hizmet görünmüyor. Seçilmezse varsayılan hizmetler atanır.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  )
                else
                  for (final opt in widget.offeredServices) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selectedServices.containsKey(opt.serviceId),
                      activeColor: AppTheme.primary,
                      title: Text(opt.name),
                      subtitle: Text('Standart süre: ${opt.durationMinutes} dk'),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedServices[opt.serviceId] = null;
                          } else {
                            _selectedServices.remove(opt.serviceId);
                          }
                        });
                      },
                    ),
                    if (_selectedServices.containsKey(opt.serviceId))
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: TextField(
                          controller: _durationControllers[opt.serviceId],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Bu çalışana özel süre (dk, opsiyonel)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                  ],
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Haftalık Çalışma Saatleri',
              children: [
                for (int i = 0; i < _schedule.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Switch(
                                value: _schedule[i].isEnabled,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (val) => setState(() {
                                  _schedule[i] =
                                      _schedule[i].copyWith(isEnabled: val);
                                }),
                              ),
                              Flexible(
                                child: Text(
                                  _schedule[i].dayLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_schedule[i].isEnabled) ...[
                          TextButton(
                            onPressed: () => _pickScheduleTime(i, true),
                            child: Text(_schedule[i].startTime),
                          ),
                          const Text('-'),
                          TextButton(
                            onPressed: () => _pickScheduleTime(i, false),
                            child: Text(_schedule[i].endTime),
                          ),
                        ] else
                          const Text(
                            'Kapalı',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.slate400,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (isEdit) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'İzinler ve Müsait Olmadığı Tarihler',
                trailing: TextButton.icon(
                  onPressed: _addTimeOffDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('İzin Ekle'),
                ),
                children: [
                  if (_timeOffs.isEmpty)
                    const Text(
                      'Tanımlı izin yok.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    )
                  else
                    for (final off in _timeOffs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(off.displayLabel),
                        subtitle: Text(off.reason),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(providerStaffRepositoryProvider)
                                  .deleteTimeOff(widget.existing!.id, off.id);
                              if (mounted) {
                                setState(
                                  () => _timeOffs
                                      .removeWhere((item) => item.id == off.id),
                                );
                              }
                            } catch (_) {}
                          },
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('save_staff_btn'),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Değişiklikleri Kaydet' : 'Çalışanı Ekle'),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
