class MapRouteBounds {
  final double south;
  final double west;
  final double north;
  final double east;

  const MapRouteBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  factory MapRouteBounds.fromJson(
    Map<String, dynamic> json,
    List<List<double>> coordinates,
  ) {
    final s = (json['south'] as num?)?.toDouble();
    final w = (json['west'] as num?)?.toDouble();
    final n = (json['north'] as num?)?.toDouble();
    final e = (json['east'] as num?)?.toDouble();
    if (s != null && w != null && n != null && e != null) {
      return MapRouteBounds(south: s, west: w, north: n, east: e);
    }

    var minLat = coordinates.first[1];
    var maxLat = coordinates.first[1];
    var minLng = coordinates.first[0];
    var maxLng = coordinates.first[0];
    for (final pt in coordinates) {
      if (pt[1] < minLat) minLat = pt[1];
      if (pt[1] > maxLat) maxLat = pt[1];
      if (pt[0] < minLng) minLng = pt[0];
      if (pt[0] > maxLng) maxLng = pt[0];
    }
    return MapRouteBounds(
      south: minLat,
      west: minLng,
      north: maxLat,
      east: maxLng,
    );
  }
}

class MapRouteResult {
  final String provider;
  final String profile;
  final int distanceMeters;
  final int durationSeconds;
  final List<List<double>> coordinates; // [lng, lat] GeoJSON LineString vertices
  final MapRouteBounds bounds;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;

  const MapRouteResult({
    required this.provider,
    required this.profile,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.coordinates,
    required this.bounds,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
  });

  factory MapRouteResult.fromJson(
    Map<String, dynamic> json, {
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
  }) {
    final geom = json['geometry'] is Map
        ? Map<String, dynamic>.from(json['geometry'] as Map)
        : <String, dynamic>{};
    final rawCoords = geom['coordinates'];
    final coords = <List<double>>[];
    if (rawCoords is List) {
      for (final item in rawCoords) {
        if (item is List && item.length >= 2) {
          final lng = (item[0] as num?)?.toDouble();
          final lat = (item[1] as num?)?.toDouble();
          if (lng != null && lat != null) {
            coords.add([lng, lat]);
          }
        }
      }
    }
    if (coords.length < 2) {
      throw const FormatException('Yönlendirme yanıtında geçerli yol geometrisi yok.');
    }

    final rawBounds = json['bounds'] is Map
        ? Map<String, dynamic>.from(json['bounds'] as Map)
        : <String, dynamic>{};

    return MapRouteResult(
      provider: (json['provider'] ?? 'valhalla').toString(),
      profile: (json['profile'] ?? 'driving').toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      coordinates: coords,
      bounds: MapRouteBounds.fromJson(rawBounds, coords),
      destinationName: destinationName,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );
  }

  Map<String, dynamic> toGeoJsonFeatureCollection() {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
          'properties': {
            'provider': provider,
            'profile': profile,
            'distance_meters': distanceMeters,
            'duration_seconds': durationSeconds,
          },
        },
      ],
    };
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    final km = distanceMeters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1).replaceAll('.', ',')} km';
  }

  String get formattedDuration {
    final totalMin = (durationSeconds / 60.0).ceil().clamp(1, 99999);
    if (totalMin < 60) {
      return '$totalMin dk';
    }
    final hours = totalMin ~/ 60;
    final mins = totalMin % 60;
    if (mins == 0) {
      return '$hours sa';
    }
    return '$hours sa $mins dk';
  }
}

class MapRouteException implements Exception {
  final String message;
  final bool isNoRoute;

  const MapRouteException(this.message, {this.isNoRoute = false});

  @override
  String toString() => message;
}
