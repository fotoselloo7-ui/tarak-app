import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/instant_request_provider.dart';
import '../services/geo_service.dart';
import 'payment_method_screen.dart';
import '../../auth/screens/registration_location_screen.dart';

/// Step 2 — Address selection screen.
/// Supports selecting from saved addresses, or adding/specifying real Turkey
/// province, district, and neighborhood via api.turkiyeapi.dev.
///
/// With [onAddressSaved] the screen is used only as the "add saved address"
/// form (e.g. from the scheduled appointment flow): the new address is always
/// saved to the profile, the callback receives its id and the screen pops.
class AddressSelectionScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onAddressSaved;

  const AddressSelectionScreen({super.key, this.onAddressSaved});

  @override
  ConsumerState<AddressSelectionScreen> createState() =>
      _AddressSelectionScreenState();
}

class _AddressSelectionScreenState
    extends ConsumerState<AddressSelectionScreen> {
  bool _manualMode = false;
  GeoProvince? _selectedProvince;
  GeoDistrict? _selectedDistrict;
  GeoNeighborhood? _selectedNeighborhood;
  List<GeoNeighborhood> _neighborhoods = [];
  bool _isLoadingNeighborhoods = false;

  final _titleCtrl = TextEditingController(text: 'Ev');
  final _streetCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _apartmentCtrl = TextEditingController();
  final _directionsCtrl = TextEditingController();

  bool _saveToProfile = true;
  bool _isSavingAddress = false;
  double? _pinLatitude;
  double? _pinLongitude;
  final _formKey = GlobalKey<FormState>();

  bool get _addOnly => widget.onAddressSaved != null;

  @override
  void initState() {
    super.initState();
    if (_addOnly) _manualMode = true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _streetCtrl.dispose();
    _buildingCtrl.dispose();
    _apartmentCtrl.dispose();
    _directionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _onProvinceChanged(GeoProvince? prov) async {
    setState(() {
      _selectedProvince = prov;
      _selectedDistrict = null;
      _selectedNeighborhood = null;
      _neighborhoods = [];
    });
  }

  Future<void> _onDistrictChanged(GeoDistrict? dist) async {
    setState(() {
      _selectedDistrict = dist;
      _selectedNeighborhood = null;
      _neighborhoods = [];
      _isLoadingNeighborhoods = dist != null;
    });

    if (dist != null) {
      try {
        final geoService = ref.read(geoServiceProvider);
        final list = await geoService.getNeighborhoods(dist.id);
        if (mounted) {
          setState(() {
            _neighborhoods = list;
            _isLoadingNeighborhoods = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingNeighborhoods = false);
      }
    }
  }

  Future<void> _saveAndSelectAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedDistrict == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen İl ve İlçe seçin.')));
      return;
    }

    setState(() => _isSavingAddress = true);

    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final newAddr = await repo.createAddress(
        title: _titleCtrl.text.trim().isEmpty ? 'Ev' : _titleCtrl.text.trim(),
        province: _selectedProvince!.name,
        district: _selectedDistrict!.name,
        neighborhood: _selectedNeighborhood?.name,
        street: _streetCtrl.text.trim().isEmpty
            ? null
            : _streetCtrl.text.trim(),
        buildingNo: _buildingCtrl.text.trim().isEmpty
            ? null
            : _buildingCtrl.text.trim(),
        apartmentNo: _apartmentCtrl.text.trim().isEmpty
            ? null
            : _apartmentCtrl.text.trim(),
        directions: _directionsCtrl.text.trim().isEmpty
            ? null
            : _directionsCtrl.text.trim(),
        isDefault: false,
        latitude: _pinLatitude,
        longitude: _pinLongitude,
      );

      ref.invalidate(customerAddressesProvider);
      if (_addOnly) {
        widget.onAddressSaved!(newAddr.id);
        if (mounted) Navigator.pop(context);
        return;
      }
      ref.read(createRequestProvider.notifier).selectAddress(newAddr.id);

      setState(() {
        _manualMode = false;
        _isSavingAddress = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni adres başarıyla kaydedildi.')),
        );
      }
    } catch (e) {
      setState(() => _isSavingAddress = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Adres kaydedilemedi: $e')));
      }
    }
  }

  void _proceed() {
    if (_manualMode) {
      if (_selectedProvince == null || _selectedDistrict == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen İl ve İlçe seçin.')),
        );
        return;
      }

      if (_saveToProfile) {
        _saveAndSelectAddress().then((_) {
          if (mounted &&
              ref.read(createRequestProvider).selectedAddressId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
            );
          }
        });
        return;
      } else {
        ref
            .read(createRequestProvider.notifier)
            .setManualAddress(
              province: _selectedProvince!.name,
              district: _selectedDistrict!.name,
              neighborhood: _selectedNeighborhood?.name,
            );
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(customerAddressesProvider);
    final selectedAddressId = ref.watch(
      createRequestProvider.select((s) => s.selectedAddressId),
    );
    final provincesAsync = ref.watch(provincesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _addOnly ? 'Yeni Adres Ekle' : 'Adres Seç',
          style: const TextStyle(
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
      body: addresses.when(
        data: (list) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (list.isNotEmpty && !_manualMode && !_addOnly) ...[
                  const Text(
                    'Kayıtlı Adreslerim',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...list.map((addr) {
                    final isSelected = selectedAddressId == addr.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _manualMode = false);
                        ref
                            .read(createRequestProvider.notifier)
                            .selectAddress(addr.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryLight
                              : Colors.white,
                          borderRadius: AppTheme.radiusCard,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.slate200,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.slate500,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (addr.title != null &&
                                      addr.title!.isNotEmpty)
                                    Text(
                                      addr.title!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.slate900,
                                      ),
                                    ),
                                  Text(
                                    addr.displayLine,
                                    style: const TextStyle(
                                      color: AppTheme.slate500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Toggle between saved and new address form
                if (!_addOnly)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _manualMode = !_manualMode;
                        if (_manualMode) {
                          ref
                              .read(createRequestProvider.notifier)
                              .selectAddress(-1);
                        }
                      });
                    },
                    icon: Icon(
                      _manualMode
                          ? Icons.close
                          : Icons.add_location_alt_outlined,
                    ),
                    label: Text(
                      _manualMode
                          ? 'Kayıtlı Adreslerime Dön'
                          : 'Yeni Adres Ekle / Farklı Adres',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),

                if (_manualMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.radiusCard,
                      border: Border.all(color: AppTheme.slate200),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yeni Adres Bilgileri',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.slate900,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Province dropdown (all 81 provinces, bundled with the app)
                          provincesAsync.when(
                            data: (provinces) {
                              return DropdownButtonFormField<GeoProvince>(
                                initialValue: _selectedProvince,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'İl *',
                                  border: OutlineInputBorder(),
                                ),
                                items: provinces.map((p) {
                                  return DropdownMenuItem<GeoProvince>(
                                    value: p,
                                    child: Text(p.name),
                                  );
                                }).toList(),
                                onChanged: _onProvinceChanged,
                                validator: (v) =>
                                    v == null ? 'Lütfen il seçin' : null,
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text(
                              'İller yüklenemedi: $e',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // District Dropdown based on selected province
                          DropdownButtonFormField<GeoDistrict>(
                            initialValue: _selectedDistrict,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'İlçe *',
                              border: OutlineInputBorder(),
                            ),
                            items: (_selectedProvince?.districts ?? []).map((
                              d,
                            ) {
                              return DropdownMenuItem<GeoDistrict>(
                                value: d,
                                child: Text(d.name),
                              );
                            }).toList(),
                            onChanged: _selectedProvince == null
                                ? null
                                : _onDistrictChanged,
                            validator: (v) =>
                                v == null ? 'Lütfen ilçe seçin' : null,
                          ),
                          const SizedBox(height: 12),

                          // Neighborhood Dropdown
                          if (_isLoadingNeighborhoods)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            )
                          else
                            DropdownButtonFormField<GeoNeighborhood>(
                              initialValue: _selectedNeighborhood,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Mahalle',
                                border: OutlineInputBorder(),
                              ),
                              items: _neighborhoods.map((n) {
                                return DropdownMenuItem<GeoNeighborhood>(
                                  value: n,
                                  child: Text(n.name),
                                );
                              }).toList(),
                              onChanged: _selectedDistrict == null
                                  ? null
                                  : (n) => setState(
                                      () => _selectedNeighborhood = n,
                                    ),
                            ),
                          const SizedBox(height: 12),

                          OutlinedButton.icon(
                            onPressed: () async {
                              final choice = await Navigator.of(context).push<Map<String,dynamic>>(
                                MaterialPageRoute(builder: (_) => RegistrationLocationScreen(initial: {
                                  'province': _selectedProvince?.name ?? '',
                                  'district': _selectedDistrict?.name ?? '',
                                  'neighborhood': _selectedNeighborhood?.name ?? '',
                                  'street': _streetCtrl.text, 'building_no': _buildingCtrl.text,
                                  'apartment_no': _apartmentCtrl.text, 'directions': _directionsCtrl.text,
                                  'latitude': _pinLatitude, 'longitude': _pinLongitude,
                                })),
                              );
                              if (choice != null && mounted) {
                                if ((choice['province'] ?? '').toString().trim().toLowerCase() !=
                                        (_selectedProvince?.name ?? '').trim().toLowerCase() ||
                                    (choice['district'] ?? '').toString().trim().toLowerCase() !=
                                        (_selectedDistrict?.name ?? '').trim().toLowerCase()) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('Haritadaki il/ilçe ile seçilen adres uyuşmuyor. Önce adres listesinden il ve ilçeyi düzeltin.'),
                                  ));
                                  return;
                                }
                                setState(() {
                                  _pinLatitude = (choice['latitude'] as num?)?.toDouble();
                                  _pinLongitude = (choice['longitude'] as num?)?.toDouble();
                                  _streetCtrl.text = (choice['street'] ?? '').toString();
                                  _buildingCtrl.text = (choice['building_no'] ?? '').toString();
                                  _apartmentCtrl.text = (choice['apartment_no'] ?? '').toString();
                                  _directionsCtrl.text = (choice['directions'] ?? '').toString();
                                });
                              }
                            },
                            icon: const Icon(Icons.pin_drop_outlined),
                            label: Text(_pinLatitude == null ? 'Adresi Haritada Bul / Pin Seç' : 'Konum seçildi · Pini Güncelle'),
                          ),
                          const SizedBox(height: 12),
                          // Title (e.g. Ev, İş)
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Adres Başlığı (Örn: Evim, Ofis)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Street
                          TextFormField(
                            controller: _streetCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cadde / Sokak',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _buildingCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Bina No',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _apartmentCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Daire No',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _directionsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Adres Tarifi / Ek Not',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (!_addOnly)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Bu adresi profilime kaydet',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: _saveToProfile,
                              onChanged: (v) =>
                                  setState(() => _saveToProfile = v ?? true),
                            ),
                          const SizedBox(height: 8),

                          ElevatedButton.icon(
                            onPressed: _isSavingAddress
                                ? null
                                : _saveAndSelectAddress,
                            icon: _isSavingAddress
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Adresi Kaydet ve Listeye Ekle'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Adresler yüklenemedi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(customerAddressesProvider),
                  child: const Text('Tekrar Dene'),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setState(() => _manualMode = true),
                  child: const Text(
                    'Manuel adres gir',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _addOnly
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.slate200)),
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed:
                      ((selectedAddressId != null && selectedAddressId > 0) ||
                          (_manualMode &&
                              _selectedProvince != null &&
                              _selectedDistrict != null))
                      ? _proceed
                      : null,
                  child: const Text('Devam Et — Ödeme Yöntemi'),
                ),
              ),
            ),
    );
  }
}
