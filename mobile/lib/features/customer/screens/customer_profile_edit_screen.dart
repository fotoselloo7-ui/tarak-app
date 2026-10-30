import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/web_landing_widgets.dart' show trUpper;
import '../../shared/widgets/geo_select_fields.dart';
import '../../shared/screens/map_address_picker.dart';
import '../providers/customer_profile_stats_provider.dart';
import '../providers/instant_request_provider.dart';
import '../providers/home_content_providers.dart';
import '../providers/provider_list_origin.dart';

/// Full customer profile editor (`GET/PUT /customer/profile`, same fields as the web dialog):
/// name, gender, birth date and the default address. E-mail and phone stay read-only.
class CustomerProfileEditScreen extends ConsumerStatefulWidget {
  const CustomerProfileEditScreen({super.key});

  @override
  ConsumerState<CustomerProfileEditScreen> createState() => _CustomerProfileEditScreenState();
}

class _CustomerProfileEditScreenState extends ConsumerState<CustomerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _addressTitle = TextEditingController();
  final _province = TextEditingController();
  final _district = TextEditingController();
  final _neighborhood = TextEditingController();
  final _street = TextEditingController();
  final _buildingNo = TextEditingController();
  final _apartmentNo = TextEditingController();

  String _email = '';
  String _phone = '';
  String _gender = '';
  DateTime? _birthDate;
  // The API rewrites the whole default address: what this form does not edit is sent back unchanged.
  Map<String, dynamic>? _currentAddress;
  double? _latitude;
  double? _longitude;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  List<TextEditingController> get _controllers => [
        _firstName, _lastName, _addressTitle, _province, _district, _neighborhood, _street, _buildingNo, _apartmentNo,
      ];

  @override
  void initState() {
    super.initState();
    for (final controller in [_province, _district, _neighborhood, _street, _buildingNo]) {
      controller.addListener(() { _latitude = null; _longitude = null; });
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : v.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.get('/customer/profile');
      final data = res.data is Map ? res.data['data'] : null;
      final user = data is Map ? data['user'] : null;
      final profile = data is Map ? data['profile'] : null;
      if (user is! Map || profile is! Map) throw const FormatException('Profil yüklenemedi.');
      final address = profile['default_address'] is Map ? Map<String, dynamic>.from(profile['default_address'] as Map) : null;

      _firstName.text = _s(user['first_name']);
      _lastName.text = _s(user['last_name']);
      _email = _s(user['email']);
      _phone = _s(user['phone']);
      final gender = _s(user['gender']);
      _gender = const {'male', 'female', 'other'}.contains(gender) ? gender : '';
      _birthDate = DateTime.tryParse(_s(profile['birth_date']));
      _currentAddress = address;
      _addressTitle.text = address == null ? 'Ev' : (_s(address['title']).isEmpty ? 'Ev' : _s(address['title']));
      _province.text = _s(address?['province']);
      _district.text = _s(address?['district']);
      _neighborhood.text = _s(address?['neighborhood']);
      _street.text = _s(address?['street']);
      _buildingNo.text = _s(address?['building_no']);
      _apartmentNo.text = _s(address?['apartment_no']);
      _latitude = (address?['latitude'] as num?)?.toDouble();
      _longitude = (address?['longitude'] as num?)?.toDouble();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Profil bilgileri yüklenemedi.';
        });
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Doğum tarihi',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _nullIfEmpty(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _selectOnMap() async {
    final query = [_street.text, _neighborhood.text, _district.text, _province.text]
        .where((part) => part.trim().isNotEmpty).join(', ');
    final result = await Navigator.push<MapAddressData>(context,
        MaterialPageRoute(builder: (_) => MapAddressPicker(
          initialQuery: query, initialLatitude: _latitude, initialLongitude: _longitude,
        )));
    if (result == null || !mounted) return;
    _province.text = result.province;
    _district.text = result.district;
    _neighborhood.text = result.neighborhood;
    _street.text = result.street;
    _buildingNo.text = result.buildingNo;
    setState(() { _latitude = result.latitude; _longitude = result.longitude; });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final province = _province.text.trim();
    final district = _district.text.trim();
    final payload = <String, dynamic>{
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'birth_date': _birthDate?.toIso8601String().substring(0, 10),
      if (_gender.isNotEmpty) 'gender': _gender,
      if (province.isNotEmpty && district.isNotEmpty)
        'address': {
          'title': _addressTitle.text.trim().isEmpty ? 'Ev' : _addressTitle.text.trim(),
          'province': province,
          'district': district,
          'neighborhood': _nullIfEmpty(_neighborhood),
          'street': _nullIfEmpty(_street),
          'building_no': _nullIfEmpty(_buildingNo),
          'apartment_no': _nullIfEmpty(_apartmentNo),
          'directions': _currentAddress?['directions'],
          'latitude': _latitude,
          'longitude': _longitude,
        },
    };

    setState(() => _saving = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.put('/customer/profile', data: payload);
      // Refresh the cached account (name in headers) and the counters / address line on the profile tab.
      await ref.read(authNotifierProvider.notifier).restoreSession();
      // The home "nearby" section reads the cached customer address list.
      // Refresh it immediately after the default address is rewritten so a
      // city/address change never keeps using stale coordinates.
      ref.read(providerListOriginProvider.notifier).useSavedAddress();
      ref.invalidate(customerAddressesProvider);
      ref.invalidate(nearbyHomeProvidersProvider);
      ref.invalidate(customerProfileStatsProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil bilgileriniz güncellendi.'), backgroundColor: AppTheme.success),
      );
    } on AppException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Profil güncellenemedi.'; });
    }
  }

  static const _text = TextStyle(fontFamily: AppTheme.fontFamily);

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: AppTheme.radiusInput, borderSide: const BorderSide(color: AppTheme.slate200)),
        enabledBorder: OutlineInputBorder(borderRadius: AppTheme.radiusInput, borderSide: const BorderSide(color: AppTheme.slate200)),
        focusedBorder: OutlineInputBorder(borderRadius: AppTheme.radiusInput, borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _section(String title, List<Widget> children, {String? note}) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUpper(title),
                style: _text.copyWith(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppTheme.slate400)),
            const SizedBox(height: 10),
            ...children,
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note, style: _text.copyWith(fontSize: 11.5, color: AppTheme.slate400, height: 1.35)),
            ],
          ],
        ),
      );

  Widget _gap() => const SizedBox(height: 12);

  Widget _readOnly(String label, String value, {String placeholder = 'Eklenmedi'}) => InputDecorator(
        decoration: _dec(label).copyWith(fillColor: AppTheme.slate50),
        child: Text(value.isEmpty ? placeholder : value,
            style: _text.copyWith(fontSize: 14, color: value.isEmpty ? AppTheme.slate400 : AppTheme.slate600)),
      );

  Widget _genderChips() {
    const options = [('', 'Belirtmek istemiyorum'), ('male', 'Erkek'), ('female', 'Kadın'), ('other', 'Diğer')];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label, style: _text.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: _gender == value ? AppTheme.primary : AppTheme.slate600)),
            selected: _gender == value,
            showCheckmark: false,
            selectedColor: AppTheme.primaryLight,
            backgroundColor: Colors.white,
            side: BorderSide(color: _gender == value ? AppTheme.primary : AppTheme.slate200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (_) => setState(() => _gender = value),
          ),
      ],
    );
  }

  String _birthLabel() {
    final d = _birthDate;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Profili Düzenle', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _loadError != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_loadError!, style: _text.copyWith(color: AppTheme.textSecondary)),
                    TextButton(onPressed: _load, child: const Text('Tekrar Dene')),
                  ]),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          children: [
                            Text('Bilgilerini güncel tut; hizmet verenler seni ve adresini doğru tanısın.',
                                style: _text.copyWith(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
                            const SizedBox(height: 18),
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(12)),
                                child: Text(_error!, style: _text.copyWith(fontSize: 13, color: AppTheme.error)),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _section('Kişisel bilgiler', [
                              TextFormField(
                                controller: _firstName,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 50,
                                autofillHints: const [AutofillHints.givenName],
                                decoration: _dec('Ad'),
                                validator: (v) => (v ?? '').trim().isEmpty ? 'Ad alanı zorunludur.' : null,
                              ),
                              _gap(),
                              TextFormField(
                                controller: _lastName,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 50,
                                autofillHints: const [AutofillHints.familyName],
                                decoration: _dec('Soyad'),
                                validator: (v) => (v ?? '').trim().isEmpty ? 'Soyad alanı zorunludur.' : null,
                              ),
                              _gap(),
                              Text('Cinsiyet', style: _text.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.slate700)),
                              const SizedBox(height: 8),
                              _genderChips(),
                              if (_gender.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('Profilinin tamamlanması için gerekli.', style: _text.copyWith(fontSize: 11.5, color: AppTheme.slate400)),
                                ),
                              _gap(),
                              InkWell(
                                onTap: _pickBirthDate,
                                borderRadius: AppTheme.radiusInput,
                                child: InputDecorator(
                                  decoration: _dec('Doğum tarihi', suffix: _birthDate == null
                                      ? const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.slate400)
                                      : IconButton(
                                          tooltip: 'Temizle',
                                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.slate400),
                                          onPressed: () => setState(() => _birthDate = null),
                                        )),
                                  child: Text(_birthLabel().isEmpty ? 'Seçilmedi' : _birthLabel(),
                                      style: _text.copyWith(fontSize: 14, color: _birthDate == null ? AppTheme.slate400 : AppTheme.textPrimary)),
                                ),
                              ),
                            ]),
                            _section('İletişim', [
                              _readOnly('E-posta', _email),
                              _gap(),
                              _readOnly('Telefon', _phone),
                            ], note: 'Güvenliğin için e-posta ve telefon değişikliği destek ekibi üzerinden yapılır.'),
                            _section('Varsayılan adres', [
                              TextFormField(controller: _addressTitle, maxLength: 50, decoration: _dec('Adres başlığı', hint: 'Ev, İş…')),
                              _gap(),
                              OutlinedButton.icon(
                                onPressed: _selectOnMap,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Haritadan adres seç'),
                              ),
                              _gap(),
                              GeoSelectFields(
                                province: _province,
                                district: _district,
                                neighborhood: _neighborhood,
                                decoration: _dec,
                                sideBySide: true,
                                provinceValidator: (v) => (v ?? '').trim().isEmpty && _district.text.trim().isNotEmpty ? 'İl gerekli' : null,
                                districtValidator: (v) => (v ?? '').trim().isEmpty && _province.text.trim().isNotEmpty ? 'İlçe gerekli' : null,
                              ),
                              _gap(),
                              TextFormField(controller: _street, maxLength: 200, textCapitalization: TextCapitalization.words, decoration: _dec('Cadde / Sokak')),
                              _gap(),
                              Row(children: [
                                Expanded(child: TextFormField(controller: _buildingNo, maxLength: 30, decoration: _dec('Bina no'), inputFormatters: [LengthLimitingTextInputFormatter(30)])),
                                const SizedBox(width: 10),
                                Expanded(child: TextFormField(controller: _apartmentNo, maxLength: 30, decoration: _dec('Daire no'))),
                              ]),
                            ], note: 'Tam adresin hizmet verene otomatik gösterilmez; yalnızca sen paylaşmayı seçtiğinde görünür.'),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.slate100))),
                          child: Row(children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  foregroundColor: AppTheme.slate700,
                                  side: const BorderSide(color: AppTheme.slate200),
                                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
                                ),
                                child: const Text('Vazgeç', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
                                ),
                                child: Text(_saving ? 'Kaydediliyor…' : 'Değişiklikleri Kaydet',
                                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
