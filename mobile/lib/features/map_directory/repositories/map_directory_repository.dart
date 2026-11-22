import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/map_business_model.dart';
import '../models/map_route_model.dart';

class MapDirectoryRepository {
  final ApiClient _api;

  MapDirectoryRepository(this._api);

  Future<MapBusinessesResponse> fetchBusinesses(
    MapBusinessFilter filter, {
    dio.CancelToken? cancelToken,
  }) async {
    final query = filter.toQueryParameters();
    try {
      final response = await _api.get(
        '/map/businesses',
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final raw = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return MapBusinessesResponse.fromJson(raw);
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) rethrow;
      debugPrint(
        '[TarakMap] GET /map/businesses failed (${e.response?.statusCode ?? e.type}): ${e.message} query=$query',
      );
      rethrow;
    } on AppException catch (e) {
      debugPrint(
        '[TarakMap] GET /map/businesses failed (${e.statusCode}): ${e.message} query=$query',
      );
      rethrow;
    }
  }

  Future<MapBusinessDetail> fetchBusinessDetail(
    String identifier, {
    dio.CancelToken? cancelToken,
  }) async {
    final encoded = Uri.encodeComponent(identifier);
    try {
      final response = await _api.get(
        '/map/businesses/$encoded',
        cancelToken: cancelToken,
      );
      final raw = response.data is Map ? response.data as Map : const {};
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : <String, dynamic>{};
      return MapBusinessDetail.fromJson(data);
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) rethrow;
      debugPrint(
        '[TarakMap] GET /map/businesses/$encoded failed (${e.response?.statusCode ?? e.type}): ${e.message}',
      );
      rethrow;
    } on AppException catch (e) {
      debugPrint(
        '[TarakMap] GET /map/businesses/$encoded failed (${e.statusCode}): ${e.message}',
      );
      rethrow;
    }
  }

  Future<MapRouteResult> fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String destinationName,
    String profile = 'driving',
    dio.CancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{
      'origin_lat': originLat,
      'origin_lng': originLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'profile': profile == 'walking' ? 'walking' : 'driving',
    };
    try {
      final response = await _api.get(
        '/map/route',
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final raw = response.data is Map ? response.data as Map : const {};
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : <String, dynamic>{};
      return MapRouteResult.fromJson(
        data,
        destinationName: destinationName,
        destinationLat: destLat,
        destinationLng: destLng,
      );
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) rethrow;
      final code = e.response?.statusCode;
      debugPrint(
        '[TarakMap] GET /map/route failed ($code / ${e.type}): ${e.message} query=$query',
      );
      throw MapRouteException(
        code == 422
            ? 'Bu iki nokta arasında kara yolu rotası hesaplanamadı.'
            : 'Yol tarifi servisine şu anda ulaşılamıyor.',
        isNoRoute: code == 422,
      );
    } on AppException catch (e) {
      debugPrint(
        '[TarakMap] GET /map/route failed (${e.statusCode}): ${e.message} query=$query',
      );
      throw MapRouteException(
        e.message,
        isNoRoute: e.statusCode == 422,
      );
    }
  }

  Future<({double lat, double lng})?> geocodePlace(
    String query, {
    dio.CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return null;
    try {
      final response = await _api.get(
        '/geo/search',
        queryParameters: {'q': trimmed},
        cancelToken: cancelToken,
      );
      final raw = response.data is Map ? response.data as Map : const {};
      final data = raw['data'] is Map ? raw['data'] as Map : const {};
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng);
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) rethrow;
      debugPrint(
        '[TarakMap] GET /geo/search failed (${e.response?.statusCode}): ${e.message} q=$trimmed',
      );
      return null;
    } on AppException catch (e) {
      debugPrint(
        '[TarakMap] GET /geo/search failed (${e.statusCode}): ${e.message} q=$trimmed',
      );
      return null;
    }
  }

  Future<void> uploadLogo(String filePath, {required String filename}) async {
    final formData = dio.FormData.fromMap({
      'logo': await dio.MultipartFile.fromFile(filePath, filename: filename),
    });
    await _api.post('/provider/profile/logo', data: formData);
  }

  Future<void> deleteLogo() async {
    await _api.delete('/provider/profile/logo');
  }

  Future<List<ServiceAreaItem>> fetchServiceAreas() async {
    final response = await _api.get('/provider/service-areas');
    final raw = response.data is Map ? response.data as Map : const {};
    final list = raw['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => ServiceAreaItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ServiceAreaItem>> updateServiceAreas(
    List<ServiceAreaItem> areas,
  ) async {
    final response = await _api.put(
      '/provider/service-areas',
      data: {
        'service_areas': areas.map((a) => a.toJson()).toList(),
      },
    );
    final raw = response.data is Map ? response.data as Map : const {};
    final list = raw['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => ServiceAreaItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
