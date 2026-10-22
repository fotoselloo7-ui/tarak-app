import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../customer/appointments/models/appointment_availability_model.dart';
import '../models/provider_appointment_model.dart';
import '../models/provider_schedule_model.dart';

final providerAppointmentRepositoryProvider =
    Provider<ProviderAppointmentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProviderAppointmentRepository(apiClient);
});

class ProviderAppointmentRepository {
  final ApiClient _client;

  ProviderAppointmentRepository(this._client);

  /// Get list of appointments assigned to this provider.
  Future<List<ProviderAppointmentModel>> fetchAppointments({
    String? status,
    String? filter,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status.toUpperCase();
    }
    if (filter != null && filter.isNotEmpty) {
      queryParams['filter'] = filter;
    }

    final response = await _client.get(
      '/provider/appointments',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .map((item) => ProviderAppointmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get single appointment detail.
  Future<ProviderAppointmentModel> fetchAppointment(int id) async {
    final response = await _client.get('/provider/appointments/$id');
    final rawData = response.data['data'] as Map<String, dynamic>;
    return ProviderAppointmentModel.fromJson(rawData);
  }

  /// Provider confirms appointment.
  Future<ProviderAppointmentModel> confirmAppointment(int id) async {
    final response = await _client.post('/provider/appointments/$id/confirm');
    final rawData = response.data['data'] as Map<String, dynamic>;
    return ProviderAppointmentModel.fromJson(rawData);
  }

  /// Provider rejects appointment with reason.
  Future<ProviderAppointmentModel> rejectAppointment(
    int id, {
    required String reason,
  }) async {
    final response = await _client.post(
      '/provider/appointments/$id/reject',
      data: {'reason': reason},
    );
    final rawData = response.data['data'] as Map<String, dynamic>;
    return ProviderAppointmentModel.fromJson(rawData);
  }

  /// Provider proposes 1-5 alternative slots.
  Future<ProviderAppointmentModel> proposeAlternatives(
    int id, {
    required List<Map<String, String>> slots,
  }) async {
    final response = await _client.post(
      '/provider/appointments/$id/alternatives',
      data: {'slots': slots},
    );
    final rawData = response.data['data'] as Map<String, dynamic>;
    return ProviderAppointmentModel.fromJson(rawData);
  }

  /// Fetch exact location shared by customer (only active when grant is valid).
  Future<ProviderSharedLocation> fetchSharedLocation(int id) async {
    final response = await _client.get('/provider/appointments/$id/shared-location');
    final rawData = response.data['data'] as Map<String, dynamic>;
    return ProviderSharedLocation.fromJson(rawData);
  }

  /// Verify 4-digit start code verbally received from customer.
  Future<Map<String, dynamic>> verifyStartCode(int id, String code) async {
    final response = await _client.post(
      '/provider/appointments/$id/verify-start-code',
      data: {'code': code},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Provider marks service finished.
  Future<Map<String, dynamic>> finishAppointment(int id) async {
    final response = await _client.post('/provider/appointments/$id/finish');
    return response.data as Map<String, dynamic>;
  }

  /// Get provider's weekly schedule.
  Future<List<ProviderWeeklyScheduleModel>> fetchSchedule() async {
    final response = await _client.get('/provider/schedule');
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .map((item) => ProviderWeeklyScheduleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Update provider's weekly schedule.
  Future<List<ProviderWeeklyScheduleModel>> updateSchedule(
    List<Map<String, dynamic>> schedule,
  ) async {
    final response = await _client.put(
      '/provider/schedule',
      data: {'schedule': schedule},
    );
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .map((item) => ProviderWeeklyScheduleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get provider's closed dates.
  Future<List<ProviderClosedDateModel>> fetchClosedDates() async {
    final response = await _client.get('/provider/closed-dates');
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .map((item) => ProviderClosedDateModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Store closed date.
  Future<ProviderClosedDateModel> storeClosedDate({
    required String date,
    required String reason,
    String? note,
  }) async {
    final response = await _client.post(
      '/provider/closed-dates',
      data: {
        'date': date,
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    final rawData = response.data['data'] as Map<String, dynamic>;
    return ProviderClosedDateModel.fromJson(rawData);
  }

  /// Delete closed date.
  Future<void> deleteClosedDate(int id) async {
    await _client.delete('/provider/closed-dates/$id');
  }

  /// Fetch availability for a date to propose alternative slots.
  Future<AppointmentAvailabilityModel> fetchAvailability({
    required int providerId,
    required String date,
    required List<int> serviceIds,
  }) async {
    final response = await _client.get(
      '/customer/providers/$providerId/availability',
      queryParameters: {
        'date': date,
        'service_ids': serviceIds.join(','),
      },
    );

    final rawData = response.data['data'] as Map<String, dynamic>;
    return AppointmentAvailabilityModel.fromJson(rawData);
  }
}
