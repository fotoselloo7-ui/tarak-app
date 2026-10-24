import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Explicit address choice; no background tracking or automatic address sharing.
class RegistrationLocationScreen extends StatefulWidget {
  const RegistrationLocationScreen({super.key, this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<RegistrationLocationScreen> createState() => _RegistrationLocationScreenState();
}

class _RegistrationLocationScreenState extends State<RegistrationLocationScreen> {
  final _key = GlobalKey<FormState>();
  final _province = TextEditingController();
  final _district = TextEditingController();
  final _neighborhood = TextEditingController();
  final _street = TextEditingController();
  final _building = TextEditingController();
  final _apartment = TextEditingController();
  final _directions = TextEditingController();
  LatLng? _pin;
  GoogleMapController? _controller;
  String? _error;
  bool _searching = false;

  // Explicit opt-in until both Google Maps SDK native API keys are configured.
  static const mapsEnabled = bool.fromEnvironment('TARAK_MAPS_ENABLED', defaultValue: false);

  @override
  void initState() {
    super.initState();
    final item = widget.initial ?? {};
    _province.text = (item['province'] ?? '').toString();
    _district.text = (item['district'] ?? '').toString();
    _neighborhood.text = (item['neighborhood'] ?? '').toString();
    _street.text = (item['street'] ?? '').toString();
    _building.text = (item['building_no'] ?? '').toString();
    _apartment.text = (item['apartment_no'] ?? '').toString();
    _directions.text = (item['directions'] ?? '').toString();
    if (item['latitude'] is num && item['longitude'] is num) {
      _pin = LatLng((item['latitude'] as num).toDouble(), (item['longitude'] as num).toDouble());
    }
  }

  @override
  void dispose() {
    for (final c in [_province, _district, _neighborhood, _street, _building, _apartment, _directions]) {
      c.dispose();
    }
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_key.currentState!.validate()) return;
    if (!mapsEnabled) {
      setState(() => _error = 'Google Maps anahtarı henüz tanımlı değil. Açık adresi kaydedebilirsiniz.');
      return;
    }
    setState(() { _searching = true; _error = null; });
    try {
      final query = [_street.text, _neighborhood.text, _district.text, _province.text, 'Türkiye']
          .where((v) => v.trim().isNotEmpty).join(', ');
      final result = await locationFromAddress(query);
      if (result.isEmpty) throw StateError('Adres bulunamadı');
      final pos = LatLng(result.first.latitude, result.first.longitude);
      if (!mounted) return;
      setState(() => _pin = pos);
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(pos, 17));
    } catch (_) {
      if (mounted) setState(() => _error = 'Adres otomatik bulunamadı. Pini elle konumlandırın.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Widget field(TextEditingController c, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (v) => v == null || v.trim().isEmpty ? 'Bu alan zorunludur.' : null : null,
    ),
  );

  void _save() {
    if (!_key.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'province': _province.text.trim(), 'district': _district.text.trim(),
      'neighborhood': _neighborhood.text.trim(), 'street': _street.text.trim(),
      'building_no': _building.text.trim(), 'apartment_no': _apartment.text.trim(),
      'directions': _directions.text.trim(),
      if (_pin != null) 'latitude': _pin!.latitude,
      if (_pin != null) 'longitude': _pin!.longitude,
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Adres ve Konum'), backgroundColor: Colors.white),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(key: _key, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Adresinizin hangi kapıya ait olduğunu kontrol edin. Haritadaki pini kendiniz taşıyabilirsiniz.'),
          const SizedBox(height: 14),
          field(_province, 'İl *', required: true),
          field(_district, 'İlçe *', required: true),
          field(_neighborhood, 'Mahalle / Köy'),
          field(_street, 'Cadde / Sokak'),
          Row(children: [
            Expanded(child: field(_building, 'Bina No')),
            const SizedBox(width: 8),
            Expanded(child: field(_apartment, 'Daire No')),
          ]),
          field(_directions, 'Tarif / Ek bilgiler'),
          OutlinedButton.icon(onPressed: _searching ? null : _search,
            icon: const Icon(Icons.travel_explore), label: const Text('Adresi Haritada Bul')),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.deepOrange)),
          if (mapsEnabled) ...[
            const SizedBox(height: 12),
            SizedBox(height: 270, child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _pin ?? const LatLng(39.0, 35.0), zoom: _pin == null ? 5 : 16),
              onMapCreated: (c) => _controller = c,
              onTap: (p) => setState(() => _pin = p),
              markers: _pin == null ? {} : {
                Marker(markerId: const MarkerId('address'), position: _pin!, draggable: true,
                  onDragEnd: (p) => setState(() => _pin = p)),
              },
              zoomControlsEnabled: false,
            )),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.check),
            label: const Text('Adresi Onayla'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5429),
              foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48))),
        ],
      )),
    )),
  );
}
