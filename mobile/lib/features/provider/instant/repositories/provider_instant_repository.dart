import '../../../../core/network/api_client.dart';
import '../../../customer/models/service_offer.dart';
import '../../../customer/models/service_request_model.dart';
import '../models/provider_profile_model.dart';
import '../models/provider_shared_location_model.dart';

class ProviderInstantRepository {
  final ApiClient _api;

  const ProviderInstantRepository(this._api);

  /// Fetch canonical provider profile including is_online and is_approved status.
  Future<ProviderProfileModel> getProfile() async {
    final resp = await _api.get('/provider/profile');
    final data = resp.data as Map<String, dynamic>;
    return ProviderProfileModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update online/offline status on the backend.
  Future<ProviderProfileModel> updateOnlineStatus(bool isOnline) async {
    final resp = await _api.put(
      '/provider/profile',
      data: {'is_online': isOnline},
    );
    final data = resp.data as Map<String, dynamic>;
    return ProviderProfileModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Fetch eligible marketplace instant service requests.
  Future<List<ServiceRequestModel>> getMarketplaceRequests() async {
    final resp = await _api.get('/provider/service-requests');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceRequestModel.fromJson)
        .toList();
  }

  /// Fetch single marketplace service request details.
  Future<ServiceRequestModel> getMarketplaceRequest(int id) async {
    final resp = await _api.get('/provider/service-requests/$id');
    final data = resp.data as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Submit an offer for an open instant request.
  Future<ServiceOffer> createOffer(
    int requestId, {
    required double price,
    required int estimatedArrivalMin,
    int durationMinutes = 30,
    String? message,
  }) async {
    final payload = <String, dynamic>{
      'price': price,
      'estimated_arrival_min': estimatedArrivalMin,
      'duration_minutes': durationMinutes,
    };
    if (message != null && message.trim().isNotEmpty) {
      payload['message'] = message.trim();
    }

    final resp = await _api.post(
      '/provider/service-requests/$requestId/offers',
      data: payload,
    );
    final data = resp.data as Map<String, dynamic>;
    return ServiceOffer.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Accept a customer's direct call at its fixed snapshot price; the job is assigned immediately.
  Future<ServiceRequestModel> acceptDirectRequest(int requestId, {required int estimatedArrivalMin}) async {
    final resp = await _api.post(
      '/provider/service-requests/$requestId/accept-direct',
      data: {'estimated_arrival_min': estimatedArrivalMin},
    );
    final data = resp.data as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Decline a direct call addressed to this provider.
  Future<void> declineDirectRequest(int requestId, {String? reason}) async {
    await _api.post(
      '/provider/service-requests/$requestId/decline-direct',
      data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    );
  }

  /// Fetch all offers submitted by this provider.
  Future<List<ServiceOffer>> getMyOffers() async {
    final resp = await _api.get('/provider/offers');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceOffer.fromJson)
        .toList();
  }

  /// Fetch all requests assigned to this provider (active and past).
  Future<List<ServiceRequestModel>> getAssignedRequests() async {
    final resp = await _api.get('/provider/assigned-requests');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceRequestModel.fromJson)
        .toList();
  }

  /// Provider reads exact shared location for an assigned instant request.
  /// Returns null if not shared, revoked, or expired (404/403).
  Future<ProviderSharedLocationModel?> getSharedLocation(int requestId) async {
    try {
      final resp = await _api.get('/provider/service-requests/$requestId/shared-location');
      final data = resp.data as Map<String, dynamic>;
      return ProviderSharedLocationModel.fromJson(data);
    } catch (_) {
      // Access denied or grant missing/expired/revoked
      return null;
    }
  }

  /// Verify 4-digit start code verbally received from customer.
  Future<Map<String, dynamic>> verifyStartCode(int requestId, String code) async {
    final resp = await _api.post(
      '/provider/service-requests/$requestId/verify-start-code',
      data: {'code': code.trim()},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Mark assigned service request as finished by provider.
  Future<Map<String, dynamic>> finishService(int requestId) async {
    final resp = await _api.post('/provider/service-requests/$requestId/finish');
    return resp.data as Map<String, dynamic>;
  }
}
