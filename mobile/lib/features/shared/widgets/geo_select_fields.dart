import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer/providers/instant_request_provider.dart';
import '../../customer/services/geo_service.dart';

/// İl → İlçe → Mahalle/Köy pickers fed by the location data bundled with the app (all 81 provinces, every district,
/// every mahalle / köy — see `GeoService`).
///
/// The text controllers stay the source of truth, so a form keeps its existing save logic: picking a value writes the
/// name into the controller and a parent change resets the children. A stored value that is not in the lists (older
/// free-text entries) stays selectable so editing a profile never silently drops it, and if the lists cannot be loaded
/// at all the fields fall back to plain text inputs so nobody is blocked.
class GeoSelectFields extends ConsumerStatefulWidget {
  final TextEditingController province;
  final TextEditingController district;

  /// Mahalle / köy. Providers store il + ilçe only, so they leave this out.
  final TextEditingController? neighborhood;
  final String provinceLabel;
  final String districtLabel;
  final String neighborhoodLabel;
  final InputDecoration Function(String label) decoration;
  final String? Function(String? value)? provinceValidator;
  final String? Function(String? value)? districtValidator;

  /// Province and district next to each other (wide forms) instead of stacked.
  final bool sideBySide;

  /// false: il / ilçe are fixed (shown elsewhere) and only the mahalle list of that district is offered.
  final bool showLocation;
  final double gap;
  final VoidCallback? onChanged;

  const GeoSelectFields({
    super.key,
    required this.province,
    required this.district,
    required this.decoration,
    this.neighborhood,
    this.provinceLabel = 'İl',
    this.districtLabel = 'İlçe',
    this.neighborhoodLabel = 'Mahalle / Köy',
    this.provinceValidator,
    this.districtValidator,
    this.sideBySide = false,
    this.showLocation = true,
    this.gap = 12,
    this.onChanged,
  });

  @override
  ConsumerState<GeoSelectFields> createState() => _GeoSelectFieldsState();
}

class _GeoSelectFieldsState extends ConsumerState<GeoSelectFields> {
  List<GeoProvince> _provinces = const [];
  List<String> _neighborhoods = const [];
  bool _loaded = false;
  bool _loadingNeighborhoods = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    List<GeoProvince> list = const [];
    try {
      list = await ref.read(geoServiceProvider).getProvinces();
    } catch (_) {}
    if (!mounted) return;
    _provinces = list;
    _canonicalise();
    setState(() => _loaded = true);
    await _loadNeighborhoods();
  }

  /// "ISTANBUL" / "istanbul" stored by an older form become the official spelling of the list.
  void _canonicalise() {
    final province = _selectedProvince;
    if (province != null && widget.province.text != province.name) widget.province.text = province.name;
    final district = _selectedDistrict;
    if (district != null && widget.district.text != district.name) widget.district.text = district.name;
  }

  GeoProvince? get _selectedProvince {
    final key = geoKey(widget.province.text);
    if (key.isEmpty) return null;
    for (final p in _provinces) {
      if (geoKey(p.name) == key) return p;
    }
    return null;
  }

  GeoDistrict? get _selectedDistrict {
    final key = geoKey(widget.district.text);
    final province = _selectedProvince;
    if (key.isEmpty || province == null) return null;
    for (final d in province.districts) {
      if (geoKey(d.name) == key) return d;
    }
    return null;
  }

  Future<void> _loadNeighborhoods() async {
    if (widget.neighborhood == null) return;
    final district = _selectedDistrict;
    final generation = ++_generation;
    if (district == null) {
      if (mounted) {
        setState(() {
          _neighborhoods = const [];
          _loadingNeighborhoods = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingNeighborhoods = true);
    List<GeoNeighborhood> list = const [];
    try {
      list = await ref.read(geoServiceProvider).getNeighborhoods(district.id);
    } catch (_) {}
    if (!mounted || generation != _generation) return;
    setState(() {
      _neighborhoods = _unique(list.map((n) => n.name));
      _loadingNeighborhoods = false;
    });
  }

  List<String> _unique(Iterable<String> names) {
    final seen = <String>{};
    return [
      for (final name in names)
        if (name.trim().isNotEmpty && seen.add(name)) name,
    ];
  }

  /// [names] plus the stored value when it is not one of them (legacy free text).
  List<String> _withCurrent(Iterable<String> names, String current, {required bool known}) {
    final list = _unique(names);
    final value = current.trim();
    if (value.isNotEmpty && !known && !list.contains(value)) list.insert(0, value);
    return list;
  }

  void _onProvince(String? name) {
    widget.province.text = name ?? '';
    widget.district.text = '';
    widget.neighborhood?.text = '';
    setState(() => _neighborhoods = const []);
    widget.onChanged?.call();
  }

  void _onDistrict(String? name) {
    widget.district.text = name ?? '';
    widget.neighborhood?.text = '';
    setState(() => _neighborhoods = const []);
    _loadNeighborhoods();
    widget.onChanged?.call();
  }

  void _onNeighborhood(String? name) {
    widget.neighborhood?.text = name ?? '';
    setState(() {});
    widget.onChanged?.call();
  }

  DropdownMenuItem<String> _item(String name) => DropdownMenuItem<String>(
        value: name,
        child: Text(name, overflow: TextOverflow.ellipsis),
      );

  Widget _dropdown({
    required Key key,
    required String label,
    required List<String> items,
    required String current,
    required ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
    bool allowEmpty = false,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: current.trim().isEmpty ? (allowEmpty ? '' : null) : current,
      isExpanded: true,
      menuMaxHeight: 360,
      decoration: widget.decoration(label),
      items: [
        if (allowEmpty) const DropdownMenuItem<String>(value: '', child: Text('Seçiniz')),
        ...items.map(_item),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _manualFields() {
    final fields = <Widget>[
      if (widget.showLocation) ...[
        TextFormField(
          controller: widget.province,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: widget.decoration(widget.provinceLabel),
          validator: widget.provinceValidator,
          onChanged: (_) => widget.onChanged?.call(),
        ),
        TextFormField(
          controller: widget.district,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: widget.decoration(widget.districtLabel),
          validator: widget.districtValidator,
          onChanged: (_) => widget.onChanged?.call(),
        ),
      ],
      if (widget.neighborhood != null)
        TextFormField(
          controller: widget.neighborhood,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          decoration: widget.decoration(widget.neighborhoodLabel),
          onChanged: (_) => widget.onChanged?.call(),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) SizedBox(height: widget.gap),
          fields[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && _provinces.isEmpty) return _manualFields();

    final province = _selectedProvince;
    final district = _selectedDistrict;
    final provinceText = widget.province.text.trim();
    final districtText = widget.district.text.trim();
    final neighborhoodText = widget.neighborhood?.text.trim() ?? '';

    final provinceField = _dropdown(
      key: ValueKey('geo-province-$provinceText-$_loaded'),
      label: widget.provinceLabel,
      items: _withCurrent(_provinces.map((p) => p.name), provinceText, known: province != null),
      current: provinceText,
      onChanged: _loaded ? _onProvince : null,
      validator: widget.provinceValidator,
    );
    final districtField = _dropdown(
      key: ValueKey('geo-district-$provinceText-$districtText-$_loaded'),
      label: widget.districtLabel,
      items: _withCurrent((province?.districts ?? const <GeoDistrict>[]).map((d) => d.name), districtText,
          known: district != null),
      current: districtText,
      onChanged: _loaded && provinceText.isNotEmpty ? _onDistrict : null,
      validator: widget.districtValidator,
    );

    final children = <Widget>[];
    if (widget.showLocation) {
      if (widget.sideBySide) {
        children.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: provinceField),
            const SizedBox(width: 10),
            Expanded(child: districtField),
          ],
        ));
      } else {
        children
          ..add(provinceField)
          ..add(SizedBox(height: widget.gap))
          ..add(districtField);
      }
    }
    if (widget.neighborhood != null) {
      if (children.isNotEmpty) children.add(SizedBox(height: widget.gap));
      children.add(_loadingNeighborhoods
          ? InputDecorator(
              decoration: widget.decoration(widget.neighborhoodLabel),
              child: const SizedBox(height: 18, child: LinearProgressIndicator(minHeight: 2)),
            )
          : _dropdown(
              key: ValueKey('geo-neighborhood-${district?.id}-$neighborhoodText-${_neighborhoods.length}'),
              label: widget.neighborhoodLabel,
              items: _withCurrent(_neighborhoods, neighborhoodText, known: _neighborhoods.contains(neighborhoodText)),
              current: neighborhoodText,
              onChanged: _loaded && districtText.isNotEmpty ? _onNeighborhood : null,
              allowEmpty: true,
            ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
