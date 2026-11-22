import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../staff/models/provider_staff_model.dart';
import '../../staff/repositories/provider_staff_repository.dart';
import '../models/provider_appointment_model.dart';
import '../repositories/provider_appointment_repository.dart';

class ProviderCreateAppointmentScreen extends ConsumerStatefulWidget {
  const ProviderCreateAppointmentScreen({super.key});

  @override
  ConsumerState<ProviderCreateAppointmentScreen> createState() =>
      _ProviderCreateAppointmentScreenState();
}

class _ProviderCreateAppointmentScreenState
    extends ConsumerState<ProviderCreateAppointmentScreen> {
  bool _loadingInitial = true;
  bool _loadingCustomers = false;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _initialError;
  String? _submitError;

  String _customerMode = 'registered'; // 'registered' | 'guest'
  List<ProviderAppointmentCustomer> _customers = const [];
  ProviderAppointmentCustomer? _selectedCustomer;
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _guestNameCtrl = TextEditingController();
  final TextEditingController _guestPhoneCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool _guestConsent = false;

  List<ProviderOfferedServiceOption> _services = const [];
  final Set<int> _selectedServiceIds = <int>{};

  List<ProviderStaffModel> _staff = const [];
  ProviderStaffModel? _selectedStaff;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<String> _slots = const [];
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _guestNameCtrl.dispose();
    _guestPhoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _initialError = null;
    });
    try {
      final staffRepo = ref.read(providerStaffRepositoryProvider);
      final apptRepo = ref.read(providerAppointmentRepositoryProvider);
      final results = await Future.wait([
        staffRepo.fetchOfferedServices(),
        staffRepo.fetchStaff(),
        apptRepo.fetchAuthorizedCustomers(),
      ]);
      if (!mounted) return;
      final offered = results[0] as List<ProviderOfferedServiceOption>;
      final allStaff = results[1] as List<ProviderStaffModel>;
      final activeStaff = allStaff
          .where((s) => s.isActive && s.acceptsAppointments && !s.isArchived)
          .toList();
      final customers = results[2] as List<ProviderAppointmentCustomer>;

      setState(() {
        _services = offered;
        if (offered.isNotEmpty) {
          _selectedServiceIds.add(offered.first.serviceId);
        }
        _staff = activeStaff;
        _customers = customers;
        if (customers.isNotEmpty) {
          _selectedCustomer = customers.first;
        }
        _loadingInitial = false;
      });
      await _loadAvailability();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialError = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'Bilgiler yüklenemedi.';
        _loadingInitial = false;
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    setState(() => _loadingCustomers = true);
    try {
      final list = await ref
          .read(providerAppointmentRepositoryProvider)
          .fetchAuthorizedCustomers(query: query);
      if (!mounted) return;
      setState(() {
        _customers = list;
        if (_selectedCustomer == null && list.isNotEmpty) {
          _selectedCustomer = list.first;
        }
        _loadingCustomers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _loadAvailability() async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null || _selectedServiceIds.isEmpty) {
      setState(() {
        _slots = const [];
        _selectedSlot = null;
      });
      return;
    }

    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });
    try {
      final res = await ref
          .read(providerAppointmentRepositoryProvider)
          .fetchAvailability(
            providerId: userId,
            date: _ymd(_selectedDate),
            serviceIds: _selectedServiceIds.toList(),
            staffId: _selectedStaff?.id,
            manual: true,
          );
      if (!mounted) return;
      setState(() {
        _slots = res.availableSlots;
        _selectedSlot = _slots.isNotEmpty ? _slots.first : null;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slots = const [];
        _selectedSlot = null;
        _loadingSlots = false;
        _submitError = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'Saatler yüklenemedi.';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _loadAvailability();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitError = null);

    if (_customerMode == 'registered') {
      if (_selectedCustomer == null) {
        setState(
          () => _submitError = 'Lütfen yetkili Tarak müşterisini seçin.',
        );
        return;
      }
    } else {
      if (_guestNameCtrl.text.trim().length < 2) {
        setState(
          () => _submitError = 'Misafir müşteri adı en az 2 karakter olmalıdır.',
        );
        return;
      }
      if (!_guestConsent) {
        setState(
          () => _submitError =
              'Misafir müşteri için kayıt izni alındığını onaylamalısınız.',
        );
        return;
      }
    }

    if (_selectedServiceIds.isEmpty) {
      setState(() => _submitError = 'En az bir hizmet seçmelisiniz.');
      return;
    }

    if (_selectedSlot == null || _selectedSlot!.isEmpty) {
      setState(() => _submitError = 'Lütfen uygun bir randevu saati seçin.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'customer_mode': _customerMode,
        if (_customerMode == 'registered')
          'customer_user_id': _selectedCustomer!.id,
        if (_customerMode == 'guest') ...{
          'guest_customer_name': _guestNameCtrl.text.trim(),
          if (_guestPhoneCtrl.text.trim().isNotEmpty)
            'guest_customer_phone': _guestPhoneCtrl.text.trim(),
          'guest_customer_consent': true,
        },
        'service_ids': _selectedServiceIds.toList(),
        if (_selectedStaff != null) 'staff_id': _selectedStaff!.id,
        'date': _ymd(_selectedDate),
        'time': _selectedSlot,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };

      await ref
          .read(providerAppointmentRepositoryProvider)
          .createManualAppointment(payload);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'Randevu oluşturulamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Randevu Oluştur',
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
      ),
      body: _loadingInitial
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _initialError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_initialError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadInitial,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (_submitError != null) ...[
                      Container(
                        key: const Key('manual_submit_error'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _submitError!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _CardBox(
                      title: '1. Müşteri Türü',
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'registered',
                              label: Text(
                                'Tarak Müşterisi',
                                key: Key('manual_mode_registered'),
                              ),
                            ),
                            ButtonSegment<String>(
                              value: 'guest',
                              label: Text(
                                'Misafir Müşteri',
                                key: Key('manual_mode_guest'),
                              ),
                            ),
                          ],
                          selected: {_customerMode},
                          onSelectionChanged: (sel) {
                            setState(() {
                              _customerMode = sel.first;
                              _submitError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_customerMode == 'registered') ...[
                          TextField(
                            controller: _customerSearchCtrl,
                            decoration: InputDecoration(
                              labelText: 'Müşteri Ara',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () => _searchCustomers(
                                  _customerSearchCtrl.text,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: _searchCustomers,
                          ),
                          const SizedBox(height: 10),
                          if (_loadingCustomers)
                            const LinearProgressIndicator(
                              color: AppTheme.primary,
                            )
                          else if (_customers.isEmpty)
                            const Text(
                              'İşletmenizle daha önce etkileşimi olan Tarak müşterisi bulunamadı. Misafir Müşteri sekmesini kullanabilirsiniz.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary,
                              ),
                            )
                          else
                            RadioGroup<int>(
                              groupValue: _selectedCustomer?.id,
                              onChanged: (id) {
                                final match = _customers
                                    .where((c) => c.id == id)
                                    .firstOrNull;
                                if (match != null) {
                                  setState(() => _selectedCustomer = match);
                                }
                              },
                              child: Column(
                                children: [
                                  for (final cust in _customers)
                                    RadioListTile<int>(
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: AppTheme.primary,
                                      value: cust.id,
                                      title: Text(cust.name),
                                    ),
                                ],
                              ),
                            ),
                        ] else ...[
                          TextField(
                            key: const Key('manual_guest_name_input'),
                            controller: _guestNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Misafir Adı Soyadı *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const Key('manual_guest_phone_input'),
                            controller: _guestPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefon Numarası (Opsiyonel)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            key: const Key('manual_guest_consent_checkbox'),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppTheme.primary,
                            value: _guestConsent,
                            title: const Text(
                              'Müşteriden randevu kaydı için sözlü onay alındı (uygulama hesabı açılmaz ve bildirim gönderilmez)',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            onChanged: (v) =>
                                setState(() => _guestConsent = v ?? false),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CardBox(
                      title: '2. Hizmetler',
                      children: [
                        if (_services.isEmpty)
                          const Text(
                            'Aktif hizmet bulunamadı. Önce Hizmetlerim alanından hizmet tanımlayın.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        else
                          for (final svc in _services)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppTheme.primary,
                              value: _selectedServiceIds.contains(svc.serviceId),
                              title: Text(svc.name),
                              subtitle: Text('${svc.durationMinutes} dk'),
                              onChanged: (checked) async {
                                setState(() {
                                  if (checked == true) {
                                    _selectedServiceIds.add(svc.serviceId);
                                  } else {
                                    _selectedServiceIds.remove(svc.serviceId);
                                  }
                                });
                                await _loadAvailability();
                              },
                            ),
                      ],
                    ),
                    if (_staff.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _CardBox(
                        title: '3. Çalışan / Usta',
                        children: [
                          DropdownButtonFormField<int?>(
                            initialValue: _selectedStaff?.id,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Fark Etmez — İlk Müsait Usta'),
                              ),
                              for (final s in _staff)
                                DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(s.fullName),
                                ),
                            ],
                            onChanged: (val) async {
                              setState(() {
                                _selectedStaff = val == null
                                    ? null
                                    : _staff
                                          .where((s) => s.id == val)
                                          .firstOrNull;
                              });
                              await _loadAvailability();
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _CardBox(
                      title: '4. Tarih ve Uygun Saatler',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.calendar_today,
                            color: AppTheme.primary,
                          ),
                          title: Text(_ymd(_selectedDate)),
                          trailing: OutlinedButton(
                            onPressed: _pickDate,
                            child: const Text('Tarih Seç'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingSlots)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          )
                        else if (_slots.isEmpty)
                          const Text(
                            'Seçilen gün ve uzman için boş saat bulunamadı.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final slot in _slots)
                                ChoiceChip(
                                  key: Key('manual_slot_$slot'),
                                  label: Text(slot),
                                  selected: _selectedSlot == slot,
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    color: _selectedSlot == slot
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _selectedSlot = slot),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CardBox(
                      title: '5. Not (Opsiyonel)',
                      children: [
                        TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            hintText: 'Telefonla alındı vb. not...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('manual_submit_btn'),
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Randevuyu Takvime Ekle'),
                      ),
                    ),
                  ],
                  ),
                ),
    );
  }
}

class _CardBox extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardBox({required this.title, required this.children});

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
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
