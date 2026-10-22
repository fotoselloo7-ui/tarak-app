import '../../../core/network/api_client.dart';
import '../../customer/models/service_request_model.dart';
import '../models/offering_models.dart';

List<Map<String, dynamic>> _list(dynamic body) =>
    ((body as Map<String, dynamic>)['data'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

Map<String, dynamic> _data(dynamic body) => (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;

/// Provider-side management of own catalog services and custom packages.
class ProviderOfferingsRepository {
  final ApiClient _api;

  const ProviderOfferingsRepository(this._api);

  Future<List<CatalogCategory>> fetchCatalog() async {
    final resp = await _api.get('/service-categories');
    return _list(resp.data).map(CatalogCategory.fromJson).toList();
  }

  Future<List<MyProviderService>> fetchMyServices() async {
    final resp = await _api.get('/provider/services');
    return _list(resp.data).map(MyProviderService.fromJson).toList();
  }

  Future<MyProviderService> saveService({
    required int serviceId,
    required double price,
    required int durationMinutes,
    String? description,
    required bool isActive,
  }) async {
    final resp = await _api.patch('/provider/services', data: {
      'service_id': serviceId,
      'custom_price': price,
      'custom_duration_minutes': durationMinutes,
      'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
      'is_active': isActive,
    });
    return MyProviderService.fromJson(_data(resp.data));
  }

  Future<List<ProviderPackageModel>> fetchPackages() async {
    final resp = await _api.get('/provider/packages');
    return _list(resp.data).map(ProviderPackageModel.fromJson).toList();
  }

  Map<String, dynamic> _packagePayload({
    String? title,
    String? description,
    double? price,
    int? durationMinutes,
    bool? isActive,
    List<int>? serviceIds,
  }) =>
      {
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description.trim().isEmpty ? null : description.trim(),
        'price': ?price,
        'duration_minutes': ?durationMinutes,
        'is_active': ?isActive,
        'service_ids': ?serviceIds,
      };

  Future<ProviderPackageModel> createPackage({
    required String title,
    String? description,
    required double price,
    required int durationMinutes,
    required List<int> serviceIds,
    bool isActive = true,
  }) async {
    final resp = await _api.post('/provider/packages',
        data: _packagePayload(
          title: title,
          description: description ?? '',
          price: price,
          durationMinutes: durationMinutes,
          isActive: isActive,
          serviceIds: serviceIds,
        ));
    return ProviderPackageModel.fromJson(_data(resp.data));
  }

  Future<ProviderPackageModel> updatePackage(
    int id, {
    String? title,
    String? description,
    double? price,
    int? durationMinutes,
    bool? isActive,
    List<int>? serviceIds,
  }) async {
    final resp = await _api.put('/provider/packages/$id',
        data: _packagePayload(
          title: title,
          description: description,
          price: price,
          durationMinutes: durationMinutes,
          isActive: isActive,
          serviceIds: serviceIds,
        ));
    return ProviderPackageModel.fromJson(_data(resp.data));
  }

  Future<void> deletePackage(int id) async {
    await _api.delete('/provider/packages/$id');
  }
}

/// Customer-side discovery and direct call.
class CustomerOfferingsRepository {
  final ApiClient _api;

  const CustomerOfferingsRepository(this._api);

  Future<List<ServiceProviderResult>> fetchProvidersForService(int serviceId, {int? addressId}) async =>
      (await fetchServiceProviderList(serviceId, addressId: addressId)).all;

  /// Same list with search / stars / distance / sort (`filters`, see ProviderListFilters) and the
  /// recommended cards apart from the organic ones (`sponsored_only` in [filters]: just the cards).
  Future<ServiceProviderList> fetchServiceProviderList(int serviceId, {int? addressId, Map<String, dynamic> filters = const {}}) async {
    final query = <String, dynamic>{...filters, 'customer_address_id': ?addressId};
    final resp = await _api.get(
      '/customer/services/$serviceId/providers',
      queryParameters: query.isNotEmpty ? query : null,
    );
    final data = _data(resp.data);
    List<ServiceProviderResult> parse(Object? raw) =>
        (raw is List ? raw : const []).whereType<Map<String, dynamic>>().map(ServiceProviderResult.fromJson).toList();
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};
    return ServiceProviderList(providers: parse(data['providers']), sponsored: parse(data['sponsored']), rotationSeconds: (meta['rotation_seconds'] as num?)?.toInt());
  }

  Future<ProviderOfferingsBundle> fetchProviderOfferings(int providerUserId, {int? addressId}) async {
    final resp = await _api.get(
      '/customer/providers/$providerUserId/offerings',
      queryParameters: addressId != null ? {'customer_address_id': addressId} : null,
    );
    return ProviderOfferingsBundle.fromJson(_data(resp.data));
  }

  /// Exactly one of [providerServiceId] / [providerPackageId] must be set.
  Future<ServiceRequestModel> createDirectRequest({
    int? providerServiceId,
    int? providerPackageId,
    required int addressId,
    String paymentMethod = 'CASH',
    String? note,
  }) async {
    assert((providerServiceId == null) != (providerPackageId == null));
    final resp = await _api.post('/customer/service-requests', data: {
      'provider_service_id': ?providerServiceId,
      'provider_package_id': ?providerPackageId,
      'customer_address_id': addressId,
      'payment_method': paymentMethod,
      if (note != null && note.trim().isNotEmpty) 'customer_note': note.trim(),
    });
    return ServiceRequestModel.fromJson(_data(resp.data));
  }
}
