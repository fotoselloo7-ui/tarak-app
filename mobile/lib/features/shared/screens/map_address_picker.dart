import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class MapAddressData {
  final double latitude;
  final double longitude;
  final String province;
  final String district;
  final String neighborhood;
  final String street;
  final String buildingNo;
  final String formattedAddress;

  const MapAddressData({
    required this.latitude,
    required this.longitude,
    this.province = '',
    this.district = '',
    this.neighborhood = '',
    this.street = '',
    this.buildingNo = '',
    this.formattedAddress = '',
  });

  factory MapAddressData.fromJson(Map data) => MapAddressData(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        province: data['province']?.toString() ?? '',
        district: data['district']?.toString() ?? '',
        neighborhood: data['neighborhood']?.toString() ?? '',
        street: data['street']?.toString() ?? '',
        buildingNo: data['building_no']?.toString() ?? '',
        formattedAddress: data['formatted_address']?.toString() ?? '',
      );
}

/// Vendor-neutral map picker:
/// - MapLibre renders the map.
/// - OpenFreeMap supplies the vector map style/tiles without an API key.
/// - Laravel /geo/search and /geo/reverse resolve addresses through the
///   server-side OSM geocoding stack.
class MapAddressPicker extends ConsumerStatefulWidget {
  final String initialQuery;
  final double? initialLatitude;
  final double? initialLongitude;

  const MapAddressPicker({
    super.key,
    this.initialQuery = '',
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  ConsumerState<MapAddressPicker> createState() => _MapAddressPickerState();
}

class _MapAddressPickerState extends ConsumerState<MapAddressPicker> {
  static const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static const _turkeyCenter = LatLng(39.0, 35.0);

  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery);

  MapLibreMapController? _map;
  Circle? _pinCircle;
  bool _styleLoaded = false;
  MapAddressData? _selection;
  LatLng? _pin;
  bool _loading = false;
  String? _error;
  int _lookupSequence = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _pin = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selection = MapAddressData(
        latitude: _pin!.latitude,
        longitude: _pin!.longitude,
      );
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _syncPin() async {
    final controller = _map;
    final pin = _pin;
    if (!_styleLoaded || controller == null || pin == null) return;

    try {
      if (_pinCircle == null) {
        _pinCircle = await controller.addCircle(
          CircleOptions(
            geometry: pin,
            circleRadius: 8,
            circleColor: '#FF5722',
            circleStrokeWidth: 3,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      } else {
        await controller.updateCircle(
          _pinCircle!,
          CircleOptions(geometry: pin),
        );
      }
    } catch (_) {
      // The style may have just reloaded. Recreate the annotation once.
      _pinCircle = null;
      if (_styleLoaded && mounted) {
        try {
          _pinCircle = await controller.addCircle(
            CircleOptions(
              geometry: pin,
              circleRadius: 8,
              circleColor: '#FF5722',
              circleStrokeWidth: 3,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 3) return;

    FocusScope.of(context).unfocus();
    final sequence = ++_lookupSequence;
    setState(() {
      _loading = true;
      _error = null;
      _selection = null;
    });

    try {
      final response = await ref.read(apiClientProvider).get(
        '/geo/search',
        queryParameters: {'q': query},
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) {
        throw const FormatException('Adres bulunamadı.');
      }

      final result = MapAddressData.fromJson(data);
      if (!mounted || sequence != _lookupSequence) return;

      setState(() {
        _selection = result;
        _pin = LatLng(result.latitude, result.longitude);
      });
      await _syncPin();
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(_pin!, 17),
      );
    } on AppException catch (e) {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _error =
            'Adres bulunamadı. Alanları elle doldurabilirsiniz.');
      }
    } finally {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reverse(LatLng point) async {
    final sequence = ++_lookupSequence;
    setState(() {
      _pin = point;
      _selection = null;
      _loading = true;
      _error = null;
    });
    await _syncPin();

    try {
      final response = await ref.read(apiClientProvider).get(
        '/geo/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lng': point.longitude,
        },
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) {
        throw const FormatException('Adres çözümlenemedi.');
      }

      if (mounted && sequence == _lookupSequence) {
        setState(() => _selection = MapAddressData.fromJson(data));
      }
    } on AppException catch (e) {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _error =
            'Adres alanları otomatik doldurulamadı. Elle düzenleyebilirsiniz.');
      }
    } finally {
      if (mounted && sequence == _lookupSequence) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _pin ?? _turkeyCenter;

    return Scaffold(
      appBar: AppBar(title: const Text('Haritadan Adres Seç')),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Adres, mahalle veya sokak arayın',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _loading ? null : _search,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: MapLibreMap(
                styleString: _mapStyle,
                initialCameraPosition: CameraPosition(
                  target: initial,
                  zoom: _pin == null ? 5.5 : 16,
                ),
                onMapCreated: (controller) {
                  _map = controller;
                },
                onStyleLoadedCallback: () {
                  _styleLoaded = true;
                  _pinCircle = null;
                  _syncPin();
                },
                onMapClick: (_, point) => _reverse(point),
                rotateGesturesEnabled: false,
                compassEnabled: false,
                myLocationEnabled: false,
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            if (_selection != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _selection!.formattedAddress.isNotEmpty
                      ? _selection!.formattedAddress
                      : '${_selection!.latitude.toStringAsFixed(5)}, ${_selection!.longitude.toStringAsFixed(5)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selection == null || _loading
                      ? null
                      : () => Navigator.pop(context, _selection),
                  child: const Text('Bu konumu kullan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
