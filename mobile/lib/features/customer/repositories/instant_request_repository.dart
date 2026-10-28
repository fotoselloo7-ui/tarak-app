import '../../../core/network/api_client.dart';
import '../models/customer_address.dart';
import '../models/location_share_status.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../models/service_offer.dart';
import '../models/service_request_model.dart';

class InstantRequestRepository {
  final ApiClient _api;

  const InstantRequestRepository(this._api);

  // ── Service Catalog ──────────────────────────────────────────────────────

  Future<List<ServiceCategory>> fetchCategories() async {
    final resp = await _api.get('/service-categories');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceCategory.fromJson)
        .toList();
  }

  Future<List<ServiceItem>> fetchServices({String? categoryId}) async {
    final resp = await _api.get(
      '/services',
      queryParameters: categoryId != null ? {'category_id': categoryId} : null,
    );
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceItem.fromJson)
        .toList();
  }

  // ── Customer Addresses ────────────────────────────────────────────────────

  Future<List<CustomerAddress>> fetchAddresses() async {
    final resp = await _api.get('/customer/addresses');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerAddress.fromJson)
        .toList();
  }

  Future<CustomerAddress> createAddress({
    required String title,
    required String province,
    required String district,
    String? neighborhood,
    String? street,
    String? buildingNo,
    String? apartmentNo,
    String? directions,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim().isEmpty ? 'Ev' : title.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'is_default': isDefault,
      'latitude': ?latitude,
      'longitude': ?longitude,
    };
    if (neighborhood != null && neighborhood.trim().isNotEmpty) {
      payload['neighborhood'] = neighborhood.trim();
    }
    if (street != null && street.trim().isNotEmpty) {
      payload['street'] = street.trim();
    }
    if (buildingNo != null && buildingNo.trim().isNotEmpty) {
      payload['building_no'] = buildingNo.trim();
    }
    if (apartmentNo != null && apartmentNo.trim().isNotEmpty) {
      payload['apartment_no'] = apartmentNo.trim();
    }
    if (directions != null && directions.trim().isNotEmpty) {
      payload['directions'] = directions.trim();
    }

    final resp = await _api.post('/customer/addresses', data: payload);
    final data = resp.data as Map<String, dynamic>;
    return CustomerAddress.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Partial update of a saved address (`PUT /customer/addresses/{id}`).
  /// Only the keys present in [changes] are sent; backend enforces ownership.
  Future<CustomerAddress> updateAddress(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final resp = await _api.put('/customer/addresses/$id', data: changes);
    final data = resp.data as Map<String, dynamic>;
    return CustomerAddress.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Deletes a saved address (`DELETE /customer/addresses/{id}`).
  Future<void> deleteAddress(int id) async {
    await _api.delete('/customer/addresses/$id');
  }

  // ── Service Requests ──────────────────────────────────────────────────────

  Future<List<ServiceRequestModel>> fetchServiceRequests({String? status}) async {
    final resp = await _api.get(
      '/customer/service-requests',
      queryParameters: status != null ? {'status': status} : null,
    );
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceRequestModel.fromJson)
        .toList();
  }

  Future<ServiceRequestModel> createServiceRequest({
    required List<int> serviceIds,
    int? customerAddressId,
    String? approxProvince,
    String? approxDistrict,
    String? approxNeighborhood,
    String paymentMethod = 'CASH',
    String? customerNote,
  }) async {
    final payload = <String, dynamic>{
      'service_ids': serviceIds,
      'payment_method': paymentMethod,
    };
    if (customerAddressId != null) payload['customer_address_id'] = customerAddressId;
    if (approxProvince != null) payload['approx_province'] = approxProvince;
    if (approxDistrict != null) payload['approx_district'] = approxDistrict;
    if (approxNeighborhood != null) payload['approx_neighborhood'] = approxNeighborhood;
    if (customerNote != null && customerNote.trim().isNotEmpty) {
      payload['customer_note'] = customerNote.trim();
    }

    final resp = await _api.post('/customer/service-requests', data: payload);
    final data = resp.data as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<ServiceRequestModel> fetchServiceRequest(int id) async {
    final resp = await _api.get('/customer/service-requests/$id');
    final data = resp.data as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<ServiceRequestModel> cancelServiceRequest(int id) async {
    final resp = await _api.post('/customer/service-requests/$id/cancel');
    final data = resp.data as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  // ── Offers ────────────────────────────────────────────────────────────────

  Future<List<ServiceOffer>> fetchOffers(int requestId) async {
    final resp = await _api.get('/customer/service-requests/$requestId/offers');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceOffer.fromJson)
        .toList();
  }

  Future<ServiceRequestModel> acceptOffer(int requestId, int offerId) async {
    final resp = await _api
        .post('/customer/service-requests/$requestId/offers/$offerId/accept');
    final data = resp.data as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  // ── Location Share (Saved Address) ────────────────────────────────────────

  Future<LocationShareStatus> fetchLocationStatus(int requestId) async {
    final resp = await _api.get('/customer/service-requests/$requestId/location-share');
    final data = resp.data as Map<String, dynamic>;
    return LocationShareStatus.fromJson(data);
  }

  Future<LocationShareStatus> shareLocation(
    int requestId, {
    required bool explicitConsent,
    String source = 'SAVED_ADDRESS',
    int? customerAddressId,
  }) async {
    final payload = <String, dynamic>{
      'explicit_consent': explicitConsent,
      'source': source,
    };
    if (customerAddressId != null) {
      payload['customer_address_id'] = customerAddressId;
    }

    final resp = await _api.post(
      '/customer/service-requests/$requestId/location-share',
      data: payload,
    );
    final data = resp.data as Map<String, dynamic>;
    return LocationShareStatus(
      hasActiveGrant: true,
      grant: data['data'] != null
          ? LocationShareGrantModel.fromJson(data['data'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<void> revokeLocation(int requestId) async {
    await _api.delete('/customer/service-requests/$requestId/location-share');
  }

  // ── Start Code ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchStartCode(int requestId) async {
    final resp = await _api.get('/customer/service-requests/$requestId/start-code');
    final data = resp.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> regenerateStartCode(int requestId) async {
    final resp = await _api
        .post('/customer/service-requests/$requestId/start-code/regenerate');
    final data = resp.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> completeServiceRequest(int requestId) async {
    await _api.post('/customer/service-requests/$requestId/complete');
  }

  Future<void> reportProblem(int requestId, String reason, {String? note}) async {
    await _api.post(
      '/customer/service-requests/$requestId/report-problem',
      data: {
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }
}
