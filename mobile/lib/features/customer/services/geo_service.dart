import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GeoProvince {
  final int id;
  final String name;
  final List<GeoDistrict> districts;

  const GeoProvince({
    required this.id,
    required this.name,
    required this.districts,
  });

  factory GeoProvince.fromJson(Map<String, dynamic> json) {
    final dists = <GeoDistrict>[];
    if (json['districts'] is List) {
      for (final d in json['districts'] as List) {
        if (d is Map<String, dynamic>) {
          dists.add(GeoDistrict.fromJson(d));
        }
      }
    }
    return GeoProvince(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      districts: dists,
    );
  }
}

class GeoDistrict {
  final int id;
  final String name;

  const GeoDistrict({
    required this.id,
    required this.name,
  });

  factory GeoDistrict.fromJson(Map<String, dynamic> json) {
    return GeoDistrict(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class GeoNeighborhood {
  final int id;
  final String name;

  const GeoNeighborhood({
    required this.id,
    required this.name,
  });

  factory GeoNeighborhood.fromJson(Map<String, dynamic> json) {
    return GeoNeighborhood(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Turkish-insensitive comparison key: "İSTANBUL", "istanbul" and "Istanbul" are the same place.
String geoKey(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    switch (String.fromCharCode(rune)) {
      case 'İ':
      case 'I':
      case 'ı':
      case 'i':
        buffer.write('i');
      case 'Ç':
      case 'ç':
        buffer.write('c');
      case 'Ğ':
      case 'ğ':
        buffer.write('g');
      case 'Ö':
      case 'ö':
        buffer.write('o');
      case 'Ş':
      case 'ş':
        buffer.write('s');
      case 'Ü':
      case 'ü':
        buffer.write('u');
      case final other:
        buffer.write(other.toLowerCase());
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Turkey location data: all 81 provinces, every district and every mahalle / köy.
///
/// The data is BUNDLED with the app (`assets/geo/provinces.json` and `assets/geo/n/<provinceId>.json`, built by
/// `tools/build_tr_locations.py`), so choosing an address works offline and never depends on a third-party service.
/// The public API (https://api.turkiyeapi.dev/v1) is only a last-resort fallback if the bundled files cannot be read.
class GeoService {
  final Dio _dio;
  final AssetBundle _bundle;

  GeoService({Dio? dio, AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              followRedirects: true,
              maxRedirects: 5,
            ));

  static const String _baseUrl = 'https://api.turkiyeapi.dev/v1';
  static const String _assetDir = 'assets/geo';

  List<GeoProvince>? _cachedProvinces;
  final Map<int, Map<String, dynamic>> _neighborhoodFiles = {};
  final Map<int, List<GeoNeighborhood>> _cachedNeighborhoods = {};

  Future<List<GeoProvince>> getProvinces() async {
    if (_cachedProvinces != null && _cachedProvinces!.isNotEmpty) {
      return _cachedProvinces!;
    }

    // 1) the data shipped inside the app
    try {
      final raw = jsonDecode(await _bundle.loadString('$_assetDir/provinces.json'));
      if (raw is List) {
        final result = raw
            .whereType<Map<String, dynamic>>()
            .map((p) => GeoProvince.fromJson(p))
            .toList();
        if (result.isNotEmpty) {
          _cachedProvinces = result;
          return result;
        }
      }
    } catch (e) {
      debugPrint('[GeoService] bundled provinces unavailable: $e');
    }

    // 2) last resort: the public API
    try {
      final response = await _dio.get('$_baseUrl/provinces');
      final data = response.data;
      final rawList = data is Map<String, dynamic>
          ? data['data']
          : (data is String ? jsonDecode(data)['data'] : null);

      if (rawList is List) {
        final result = rawList
            .whereType<Map<String, dynamic>>()
            .map((p) => GeoProvince.fromJson(p))
            .toList();
        _cachedProvinces = result;
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('[GeoService] getProvinces error: $e');
      return [];
    }
  }

  /// The province whose name matches [name] regardless of how it was typed ("İSTANBUL", "istanbul").
  Future<GeoProvince?> findProvince(String name) async {
    final key = geoKey(name);
    if (key.isEmpty) return null;
    for (final p in await getProvinces()) {
      if (geoKey(p.name) == key) return p;
    }
    return null;
  }

  Future<List<GeoNeighborhood>> getNeighborhoods(int districtId) async {
    if (_cachedNeighborhoods.containsKey(districtId)) {
      return _cachedNeighborhoods[districtId]!;
    }

    // 1) the data shipped inside the app: one small file per province
    try {
      final provinces = await getProvinces();
      for (final province in provinces) {
        if (!province.districts.any((d) => d.id == districtId)) continue;
        final file = _neighborhoodFiles[province.id] ??= Map<String, dynamic>.from(
          jsonDecode(await _bundle.loadString('$_assetDir/n/${province.id}.json')) as Map,
        );
        final names = file['$districtId'];
        final result = <GeoNeighborhood>[
          if (names is List)
            for (var i = 0; i < names.length; i++) GeoNeighborhood(id: i + 1, name: names[i].toString()),
        ];
        _cachedNeighborhoods[districtId] = result;
        return result;
      }
    } catch (e) {
      debugPrint('[GeoService] bundled neighborhoods unavailable: $e');
    }

    // 2) last resort: the public API
    try {
      final response = await _dio.get('$_baseUrl/districts/$districtId');
      final data = response.data;
      final rawData = data is Map<String, dynamic>
          ? data['data']
          : (data is String ? jsonDecode(data)['data'] : null);

      if (rawData is Map<String, dynamic> && rawData['neighborhoods'] is List) {
        final result = (rawData['neighborhoods'] as List)
            .whereType<Map<String, dynamic>>()
            .map((n) => GeoNeighborhood.fromJson(n))
            .toList();
        _cachedNeighborhoods[districtId] = result;
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('[GeoService] getNeighborhoods error: $e');
      return [];
    }
  }
}
