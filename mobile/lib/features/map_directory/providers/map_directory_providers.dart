import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/map_business_model.dart';
import '../repositories/map_directory_repository.dart';
import '../services/map_route_service.dart';

final mapDirectoryRepositoryProvider = Provider<MapDirectoryRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return MapDirectoryRepository(api);
});

final mapRouteServiceProvider = Provider<MapRouteService>((ref) {
  final repo = ref.watch(mapDirectoryRepositoryProvider);
  return MapRouteService(repo);
});

class MapFilterNotifier extends Notifier<MapBusinessFilter> {
  @override
  MapBusinessFilter build() => const MapBusinessFilter();

  void setFilter(MapBusinessFilter filter) {
    state = filter;
  }

  void setSearchQuery(String q) {
    state = state.copyWith(q: q);
  }

  void setOrigin({required double lat, required double lng, int? radiusKm}) {
    state = state.copyWith(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm ?? state.radiusKm,
    );
  }

  void clearOrigin() {
    state = state.copyWith(clearOrigin: true, clearRadiusKm: true);
  }

  void clearAll() {
    state = const MapBusinessFilter();
  }
}

final mapFilterProvider =
    NotifierProvider.autoDispose<MapFilterNotifier, MapBusinessFilter>(
  MapFilterNotifier.new,
);

final mapBusinessesProvider =
    FutureProvider.autoDispose<MapBusinessesResponse>((ref) async {
  final repo = ref.watch(mapDirectoryRepositoryProvider);
  final filter = ref.watch(mapFilterProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('filter_changed'));
  return repo.fetchBusinesses(filter, cancelToken: cancelToken);
});

final mapBusinessDetailProvider = FutureProvider.autoDispose
    .family<MapBusinessDetail, String>((ref, identifier) async {
  final repo = ref.watch(mapDirectoryRepositoryProvider);
  return repo.fetchBusinessDetail(identifier);
});
