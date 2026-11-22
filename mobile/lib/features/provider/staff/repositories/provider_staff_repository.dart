import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/provider_staff_model.dart';

final providerStaffRepositoryProvider =
    Provider<ProviderStaffRepository>((ref) {
  return ProviderStaffRepository(ref.watch(apiClientProvider));
});

class ProviderStaffRepository {
  final ApiClient _api;

  ProviderStaffRepository(this._api);

  Future<List<ProviderStaffModel>> fetchStaff() async {
    final resp = await _api.get('/provider/staff');
    final body = resp.data;
    final list = body is Map && body['data'] is List
        ? body['data'] as List
        : (body is List ? body : const []);
    return list
        .whereType<Map>()
        .map((e) => ProviderStaffModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ProviderOfferedServiceOption>> fetchOfferedServices() async {
    final resp = await _api.get('/provider/services');
    final body = resp.data;
    final list = body is Map && body['data'] is List
        ? body['data'] as List
        : (body is List ? body : const []);
    return list
        .whereType<Map>()
        .map(
          (e) => ProviderOfferedServiceOption.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .where((s) => s.serviceId > 0)
        .toList();
  }

  Future<ProviderStaffModel> createStaff(Map<String, dynamic> payload) async {
    final resp = await _api.post('/provider/staff', data: payload);
    final body = resp.data as Map<String, dynamic>;
    return ProviderStaffModel.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<ProviderStaffModel> updateStaff(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final resp = await _api.put('/provider/staff/$id', data: payload);
    final body = resp.data as Map<String, dynamic>;
    return ProviderStaffModel.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<ProviderStaffModel> archiveStaff(int id) async {
    final resp = await _api.delete('/provider/staff/$id');
    final body = resp.data as Map<String, dynamic>;
    return ProviderStaffModel.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<String?> uploadPhoto(int id, String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    final resp = await _api.post('/provider/staff/$id/photo', data: formData);
    final body = resp.data;
    if (body is Map && body['data'] is Map) {
      return body['data']['photo_url']?.toString();
    }
    return null;
  }

  Future<void> deletePhoto(int id) async {
    await _api.delete('/provider/staff/$id/photo');
  }

  Future<ProviderStaffTimeOffModel> addTimeOff(
    int staffId,
    Map<String, dynamic> payload,
  ) async {
    final resp =
        await _api.post('/provider/staff/$staffId/time-offs', data: payload);
    final body = resp.data as Map<String, dynamic>;
    return ProviderStaffTimeOffModel.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<void> deleteTimeOff(int staffId, int timeOffId) async {
    await _api.delete('/provider/staff/$staffId/time-offs/$timeOffId');
  }

  Future<BirthdayAssistantSettingsModel> fetchBirthdaySettings() async {
    final resp = await _api.get('/provider/birthday-assistant');
    final body = resp.data as Map<String, dynamic>;
    return BirthdayAssistantSettingsModel.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<BirthdayAssistantSettingsModel> updateBirthdaySettings(
    Map<String, dynamic> payload,
  ) async {
    final resp = await _api.put('/provider/birthday-assistant', data: payload);
    final body = resp.data as Map<String, dynamic>;
    return BirthdayAssistantSettingsModel.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }
}
