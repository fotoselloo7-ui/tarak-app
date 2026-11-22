import 'package:dio/dio.dart';

import '../models/map_route_model.dart';
import '../repositories/map_directory_repository.dart';

typedef MapRouteFetcher = Future<MapRouteResult> Function({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  required String destinationName,
  String profile,
  CancelToken? cancelToken,
});

/// Fetches real turn-by-turn road routes from Tarak's routing proxy endpoint.
/// Never synthesizes a straight-line fallback when road routing fails.
class MapRouteService {
  final MapDirectoryRepository _repository;

  MapRouteService(this._repository);

  Future<MapRouteResult> fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String destinationName,
    String profile = 'driving',
    CancelToken? cancelToken,
  }) {
    return _repository.fetchRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      destinationName: destinationName,
      profile: profile,
      cancelToken: cancelToken,
    );
  }
}
