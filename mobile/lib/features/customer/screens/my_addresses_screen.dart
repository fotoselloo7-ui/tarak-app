import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/geo_select_fields.dart';
import '../models/customer_address.dart';
import '../providers/customer_profile_stats_provider.dart';
import '../providers/instant_request_provider.dart';
import 'address_selection_screen.dart';
import '../../auth/screens/registration_location_screen.dart';

/// Saved address management for the customer profile.
///
/// This is the counterpart of the web profile's "Kayıtlı Adresler" card:
/// list, add, edit, set default and delete — all against `/customer/addresses`.
/// The booking flow's [AddressSelectionScreen] stays what it is (picking an
/// address for an order) and is reused here only in its add-only mode.
class MyAddressesScreen extends ConsumerStatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  ConsumerState<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends ConsumerState<MyAddressesScreen> {
  int? _busyId;

  void _refresh() {
    ref.invalidate(customerAddressesProvider);
    ref.invalidate(customerProfileStatsProvider);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _setDefault(CustomerAddress address) async {
    setState(() => _busyId = address.id);
    try {
      await ref
          .read(instantRequestRepositoryProvider)
          .updateAddress(address.id, {'is_default': true});
      _refresh();
      _toast('Varsayılan adres güncellendi.');
    } catch (_) {
      _toast('Varsayılan adres güncellenemedi.', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adresi sil'),
        content: Text(
          '"${address.title ?? 'Adres'}" adresini silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = address.id);
    try {
      await ref.read(instantRequestRepositoryProvider).deleteAddress(address.id);
      _refresh();
      _toast('Adres silindi.');
    } catch (_) {
      _toast('Adres silinemedi.', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _edit(CustomerAddress address) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAddressSheet(address: address),
    );
    if (saved == true) {
      _refresh();
      _toast('Adres güncellendi.');
    }
  }

  Future<void> _add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(onAddressSaved: (_) {}),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customerAddressesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text(
          'Kayıtlı Adreslerim',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Adresler yüklenemedi.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _refresh, child: const Text('Tekrar dene')),
            ],
          ),
        ),
        data: (addresses) => RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 48,
                        color: AppTheme.slate400,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Henüz kayıtlı adresiniz yok.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hizmet alabilmek için en az bir adres ekleyin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppTheme.slate400,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...addresses.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _addressCard(a),
                  ),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: const Text(
                  'Yeni Adres Ekle',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressCard(CustomerAddress a) {
    final busy = _busyId == a.id;
    final detail = [
      if ((a.street ?? '').isNotEmpty) a.street,
      if ((a.buildingNo ?? '').isNotEmpty) 'No: ${a.buildingNo}',
      if ((a.apartmentNo ?? '').isNotEmpty) 'Daire: ${a.apartmentNo}',
    ].whereType<String>().join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.title ?? 'Adres',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (a.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Varsayılan',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppTheme.slate400,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'default':
                        _setDefault(a);
                      case 'edit':
                        _edit(a);
                      case 'delete':
                        _delete(a);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!a.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Varsayılan Yap'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Sil',
                        style: TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            a.displayLine.isEmpty ? 'Adres bilgisi yok' : a.displayLine,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppTheme.slate400,
              ),
            ),
          ],
          if ((a.directions ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: AppTheme.slate400,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    a.directions!,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Edit sheet — the address title, its free-text parts and the default flag.
/// Province/district come from the geography pickers used when an address is
/// created, so they are shown read-only here.
class _EditAddressSheet extends ConsumerStatefulWidget {
  final CustomerAddress address;

  const _EditAddressSheet({required this.address});

  @override
  ConsumerState<_EditAddressSheet> createState() => _EditAddressSheetState();
}

class _EditAddressSheetState extends ConsumerState<_EditAddressSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.address.title ?? '',
  );
  // il / ilçe are fixed here; they only tell the mahalle picker which list to offer.
  late final TextEditingController _province = TextEditingController(
    text: widget.address.province ?? '',
  );
  late final TextEditingController _district = TextEditingController(
    text: widget.address.district ?? '',
  );
  late final TextEditingController _neighborhood = TextEditingController(
    text: widget.address.neighborhood ?? '',
  );
  late final TextEditingController _street = TextEditingController(
    text: widget.address.street ?? '',
  );
  late final TextEditingController _building = TextEditingController(
    text: widget.address.buildingNo ?? '',
  );
  late final TextEditingController _apartment = TextEditingController(
    text: widget.address.apartmentNo ?? '',
  );
  late final TextEditingController _directions = TextEditingController(
    text: widget.address.directions ?? '',
  );
  late bool _isDefault = widget.address.isDefault;
  late double? _pinLatitude = widget.address.latitude;
  late double? _pinLongitude = widget.address.longitude;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _province.dispose();
    _district.dispose();
    _neighborhood.dispose();
    _street.dispose();
    _building.dispose();
    _apartment.dispose();
    _directions.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Reposition an existing saved address without duplicating it.
  Future<void> _chooseMapPin() async {
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => RegistrationLocationScreen(initial: {
        'province': _province.text,
        'district': _district.text,
        'neighborhood': _neighborhood.text,
        'street': _street.text,
        'building_no': _building.text,
        'apartment_no': _apartment.text,
        'directions': _directions.text,
        if (_pinLatitude != null) 'latitude': _pinLatitude,
        if (_pinLongitude != null) 'longitude': _pinLongitude,
      })),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _province.text = (selected['province'] ?? '').toString();
      _district.text = (selected['district'] ?? '').toString();
      _neighborhood.text = (selected['neighborhood'] ?? '').toString();
      _street.text = (selected['street'] ?? '').toString();
      _building.text = (selected['building_no'] ?? '').toString();
      _apartment.text = (selected['apartment_no'] ?? '').toString();
      _directions.text = (selected['directions'] ?? '').toString();
      _pinLatitude = (selected['latitude'] as num?)?.toDouble();
      _pinLongitude = (selected['longitude'] as num?)?.toDouble();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Adres başlığı zorunludur.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(instantRequestRepositoryProvider).updateAddress(
        widget.address.id,
        {
          'title': _title.text.trim(),
          'province': _province.text.trim(),
          'district': _district.text.trim(),
          'latitude': _pinLatitude,
          'longitude': _pinLongitude,
          'neighborhood': _trimmedOrNull(_neighborhood),
          'street': _trimmedOrNull(_street),
          'building_no': _trimmedOrNull(_building),
          'apartment_no': _trimmedOrNull(_apartment),
          'directions': _trimmedOrNull(_directions),
          'is_default': _isDefault,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Adres güncellenemedi. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    isDense: true,
  );

  @override
  Widget build(BuildContext context) {
    final location = [
      widget.address.district,
      widget.address.province,
    ].whereType<String>().where((v) => v.isNotEmpty).join(', ');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Adresi Düzenle',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(controller: _title, decoration: _dec('Adres Başlığı')),
              const SizedBox(height: 12),
              GeoSelectFields(
                province: _province,
                district: _district,
                neighborhood: _neighborhood,
                neighborhoodLabel: 'Mahalle / Köy',
                showLocation: false,
                decoration: _dec,
              ),
              const SizedBox(height: 12),
              TextField(controller: _street, decoration: _dec('Cadde / Sokak')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _building,
                      decoration: _dec('Bina No'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _apartment,
                      decoration: _dec('Daire No'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _directions,
                maxLines: 2,
                decoration: _dec('Tarif / Not'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _chooseMapPin,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(_pinLatitude == null
                    ? 'Adresi Haritada Bul / Pin Seç'
                    : 'Seçili konumu haritada düzenle'),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                activeColor: AppTheme.primary,
                onChanged: widget.address.isDefault
                    ? null
                    : (v) => setState(() => _isDefault = v),
                title: const Text(
                  'Varsayılan adres',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppTheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
