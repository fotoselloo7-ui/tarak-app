import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../models/customer_address.dart';
import '../../models/location_share_status.dart';
import '../models/appointment_availability_model.dart';
import '../models/customer_appointment_model.dart';
import '../models/scheduled_provider_model.dart';

/// Message shown when the backend reports the chosen slot is no longer free (409).
const kSlotTakenMessage =
    'Bu saat artık uygun değil. Lütfen başka bir saat seçin.';

/// Organic providers plus the running list ads ("Sponsorlu") of one discovery request.
class ScheduledProviderList {
  final List<ScheduledProviderModel> providers;
  final List<ScheduledProviderModel> sponsored;

  /// How many seconds the recommended set stays before it changes (the screen asks again after that).
  final int? rotationSeconds;
  const ScheduledProviderList({this.providers = const [], this.sponsored = const [], this.rotationSeconds});

  List<ScheduledProviderModel> get all => [...sponsored, ...providers];
}

class CustomerAppointmentRepository {
  final ApiClient _api;

  const CustomerAppointmentRepository(this._api);

  // ── Providers Discovery ──────────────────────────────────────────────────

  /// Scheduled discovery. Eligibility (approval, verification, documents,
  /// offering EVERY selected service) is decided by the backend; the client
  /// never filters the returned list (e.g. by `is_online`).
  Future<List<ScheduledProviderModel>> fetchProviders({
    List<int> serviceIds = const [],
    String? providerType,
    String? category,
  }) async => (await fetchProviderList(serviceIds: serviceIds, providerType: providerType, category: category)).all;

  /// Same discovery with the list filters (`q`, `min_rating`, `lat`/`lng`, `max_distance_km`, `sort`: see
  /// ProviderListFilters) and the recommended ("Liste Reklamı") cards apart from the organic ones.
  /// With `sponsored_only` in [filters] the API answers with just the cards.
  Future<ScheduledProviderList> fetchProviderList({
    List<int> serviceIds = const [],
    String? providerType,
    String? category,
    Map<String, dynamic> filters = const {},
  }) async {
    final query = <String, dynamic>{...filters};
    // Comma-separated: PHP reads repeated `service_ids=` keys as a single value.
    if (serviceIds.isNotEmpty) query['service_ids'] = serviceIds.join(',');
    if (providerType != null && providerType.isNotEmpty) {
      query['provider_type'] = providerType;
    }
    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }

    final resp = await _api.get(
      '/customer/providers',
      queryParameters: query.isNotEmpty ? query : null,
    );
    final data = resp.data as Map<String, dynamic>;
    List<ScheduledProviderModel> parse(Object? raw) =>
        (raw is List ? raw : const []).whereType<Map<String, dynamic>>().map(ScheduledProviderModel.fromJson).toList();
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};
    return ScheduledProviderList(providers: parse(data['data']), sponsored: parse(data['sponsored']), rotationSeconds: (meta['rotation_seconds'] as num?)?.toInt());
  }

  // ── Availability ─────────────────────────────────────────────────────────

  Future<AppointmentAvailabilityModel> fetchAvailability({
    required int providerId,
    required String date,
    required List<int> serviceIds,
    int? providerPackageId,
  }) async {
    final query = <String, dynamic>{
      'date': date,
      'service_ids': serviceIds.join(','),
      'provider_package_id': ?providerPackageId,
    };

    final resp = await _api.get(
      '/customer/providers/$providerId/availability',
      queryParameters: query,
    );
    final data = resp.data as Map<String, dynamic>;
    return AppointmentAvailabilityModel.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }

  // ── Customer Appointments List & Details ──────────────────────────────────

  Future<List<CustomerAppointmentModel>> fetchAppointments() async {
    final resp = await _api.get('/customer/appointments');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerAppointmentModel.fromJson)
        .toList();
  }

  Future<CustomerAppointmentModel> fetchAppointment(int id) async {
    final resp = await _api.get('/customer/appointments/$id');
    final data = resp.data as Map<String, dynamic>;
    return CustomerAppointmentModel.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }

  // ── Create Appointment ───────────────────────────────────────────────────

  Future<CustomerAppointmentModel> createAppointment({
    required int providerId,
    List<int> serviceIds = const [],
    int? providerPackageId,
    required String date,
    required String time,
    int? customerAddressId,
    String? customerNote,
    String paymentMethod = 'CASH',
    String? approxProvince,
    String? approxDistrict,
    String? approxNeighborhood,
  }) async {
    final payload = <String, dynamic>{
      'provider_id': providerId,
      if (providerPackageId != null) 'provider_package_id': providerPackageId else 'service_ids': serviceIds,
      'date': date,
      'time': time,
      'payment_method': paymentMethod.toUpperCase(),
    };
    if (customerAddressId != null) {
      payload['customer_address_id'] = customerAddressId;
    }
    if (customerNote != null && customerNote.trim().isNotEmpty) {
      payload['customer_note'] = customerNote.trim();
    }
    if (approxProvince != null) payload['approx_province'] = approxProvince;
    if (approxDistrict != null) payload['approx_district'] = approxDistrict;
    if (approxNeighborhood != null) {
      payload['approx_neighborhood'] = approxNeighborhood;
    }

    try {
      final resp = await _api.post('/customer/appointments', data: payload);
      final data = resp.data as Map<String, dynamic>;
      return CustomerAppointmentModel.fromJson(
        data['data'] as Map<String, dynamic>,
      );
    } on AppException catch (e) {
      if (e.statusCode == 409) {
        throw AppException(message: kSlotTakenMessage, statusCode: 409);
      }
      rethrow;
    }
  }

  // ── Cancel Appointment ───────────────────────────────────────────────────

  Future<CustomerAppointmentModel> cancelAppointment(int id) async {
    final resp = await _api.post('/customer/appointments/$id/cancel');
    final data = resp.data as Map<String, dynamic>;
    return CustomerAppointmentModel.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }

  // ── Alternative Slots ─────────────────────────────────────────────────────

  Future<CustomerAppointmentModel> acceptAlternative({
    required int appointmentId,
    required int slotId,
  }) async {
    try {
      final resp = await _api.post(
        '/customer/appointments/$appointmentId/alternatives/$slotId/accept',
      );
      final data = resp.data as Map<String, dynamic>;
      return CustomerAppointmentModel.fromJson(
        data['data'] as Map<String, dynamic>,
      );
    } on AppException catch (e) {
      if (e.statusCode == 409) {
        throw AppException(
          message: e.message.isNotEmpty
              ? e.message
              : 'Bu saat artık uygun değil. Lütfen başka bir saat seçin.',
          statusCode: 409,
        );
      }
      rethrow;
    }
  }

  Future<CustomerAppointmentModel> rejectAlternative(int appointmentId) async {
    final resp = await _api.post(
      '/customer/appointments/$appointmentId/alternatives/reject',
    );
    final data = resp.data as Map<String, dynamic>;
    return CustomerAppointmentModel.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }

  // ── Saved Address Location Share ──────────────────────────────────────────

  Future<LocationShareStatus> fetchLocationStatus(int appointmentId) async {
    final resp = await _api.get(
      '/customer/appointments/$appointmentId/location-share',
    );
    final data = resp.data as Map<String, dynamic>;
    return LocationShareStatus.fromJson(data);
  }

  Future<LocationShareStatus> shareLocation(
    int appointmentId, {
    required bool explicitConsent,
    required int customerAddressId,
    String source = 'SAVED_ADDRESS',
  }) async {
    final payload = <String, dynamic>{
      'explicit_consent': explicitConsent,
      'source': source,
      'customer_address_id': customerAddressId,
    };

    final resp = await _api.post(
      '/customer/appointments/$appointmentId/location-share',
      data: payload,
    );
    final data = resp.data as Map<String, dynamic>;
    return LocationShareStatus(
      hasActiveGrant: true,
      grant: data['data'] != null
          ? LocationShareGrantModel.fromJson(
              data['data'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Future<void> revokeLocation(int appointmentId) async {
    await _api.delete('/customer/appointments/$appointmentId/location-share');
  }

  // ── Start Verification Code ───────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchStartCode(int appointmentId) async {
    final resp = await _api.get(
      '/customer/appointments/$appointmentId/start-code',
    );
    final data = resp.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> regenerateStartCode(int appointmentId) async {
    final resp = await _api.post(
      '/customer/appointments/$appointmentId/start-code/regenerate',
    );
    final data = resp.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // ── Completion & Dispute ──────────────────────────────────────────────────

  Future<void> completeAppointment(int appointmentId) async {
    await _api.post('/customer/appointments/$appointmentId/complete');
  }

  Future<void> reportProblem(
    int appointmentId, {
    required String reason,
    String? note,
  }) async {
    await _api.post(
      '/customer/appointments/$appointmentId/report-problem',
      data: {
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  // ── Conversation Deep-link helper ─────────────────────────────────────────

  Future<Map<String, dynamic>> fetchConversation(int appointmentId) async {
    final resp = await _api.get(
      '/customer/appointments/$appointmentId/conversation',
    );
    final data = resp.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // ── Saved Addresses Helper ────────────────────────────────────────────────

  Future<List<CustomerAddress>> fetchAddresses() async {
    final resp = await _api.get('/customer/addresses');
    final data = resp.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerAddress.fromJson)
        .toList();
  }
}
