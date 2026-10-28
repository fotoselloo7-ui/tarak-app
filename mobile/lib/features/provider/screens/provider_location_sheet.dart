import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/screens/map_address_picker.dart';
import '../../shared/widgets/geo_select_fields.dart';
import '../instant/models/provider_profile_model.dart';

/// Edits the existing provider profile location in the profile tab's sheet.
class ProviderLocationSheet extends ConsumerStatefulWidget {
  final ProviderProfileModel profile;
  const ProviderLocationSheet({super.key, required this.profile});

  @override
  ConsumerState<ProviderLocationSheet> createState() => _ProviderLocationSheetState();
}

class _ProviderLocationSheetState extends ConsumerState<ProviderLocationSheet> {
  late final _city = TextEditingController(text: widget.profile.city ?? '');
  late final _district = TextEditingController(text: widget.profile.district ?? '');
  late final _neighborhood = TextEditingController(text: widget.profile.neighborhood ?? '');
  late final _street = TextEditingController(text: widget.profile.street ?? '');
  late final _building = TextEditingController(text: widget.profile.buildingNo ?? '');
  late final _detail = TextEditingController(text: widget.profile.addressDetail ?? '');
  late double? _latitude = widget.profile.latitude;
  late double? _longitude = widget.profile.longitude;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [_city, _district, _neighborhood, _street, _building]) {
      controller.addListener(() { _latitude = null; _longitude = null; });
    }
  }

  @override
  void dispose() {
    for (final controller in [_city, _district, _neighborhood, _street, _building, _detail]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseMap() async {
    final query = [_street.text, _neighborhood.text, _district.text, _city.text]
        .where((value) => value.trim().isNotEmpty).join(', ');
    final result = await Navigator.push<MapAddressData>(context,
        MaterialPageRoute(builder: (_) => MapAddressPicker(
          initialQuery: query, initialLatitude: _latitude, initialLongitude: _longitude,
        )));
    if (result == null || !mounted) return;
    _city.text = result.province;
    _district.text = result.district;
    _neighborhood.text = result.neighborhood;
    _street.text = result.street;
    _building.text = result.buildingNo;
    setState(() { _latitude = result.latitude; _longitude = result.longitude; });
  }

  Future<void> _save() async {
    if (_city.text.trim().isEmpty || _district.text.trim().isEmpty) {
      setState(() => _error = 'İl ve ilçe zorunludur.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(apiClientProvider).put('/provider/profile', data: {
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'neighborhood': _neighborhood.text.trim().isEmpty ? null : _neighborhood.text.trim(),
        'street': _street.text.trim().isEmpty ? null : _street.text.trim(),
        'building_no': _building.text.trim().isEmpty ? null : _building.text.trim(),
        'address_detail': _detail.text.trim().isEmpty ? null : _detail.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
      });
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Konum kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('İşletme Konumu', style: TextStyle(fontFamily: AppTheme.fontFamily,
                  fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: _chooseMap,
                  icon: const Icon(Icons.map_outlined), label: const Text('Haritadan konum seç')),
              const SizedBox(height: 12),
              GeoSelectFields(province: _city, district: _district,
                  neighborhood: _neighborhood, decoration: _dec),
              const SizedBox(height: 12),
              TextField(controller: _street, decoration: _dec('Cadde / Sokak')),
              const SizedBox(height: 12),
              TextField(controller: _building, decoration: _dec('Bina No')),
              const SizedBox(height: 12),
              TextField(controller: _detail, decoration: _dec('Adres tarifi')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
              const SizedBox(height: 16),
              FilledButton(onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Kaydediliyor…' : 'Konumu Kaydet')),
            ],
          )),
        ),
      );
}
