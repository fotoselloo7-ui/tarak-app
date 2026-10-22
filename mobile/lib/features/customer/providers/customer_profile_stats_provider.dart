import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Real profile counters for the customer profile tab.
///
/// Computed from the same endpoints and with the same rules the web profile
/// uses, so both platforms report identical numbers. Nothing here is faked:
/// A failed request is exposed as an error instead of fabricated empty counts.
class CustomerProfileStats {
  final int activeRequests;
  final int upcomingAppointments;
  final int completedServices;
  final int savedAddresses;

  /// "İlçe, İl" of the default (or first) saved address — null when the
  /// customer has no address yet, in which case the UI hides the line.
  final String? defaultAddressLine;

  const CustomerProfileStats({
    this.activeRequests = 0,
    this.upcomingAppointments = 0,
    this.completedServices = 0,
    this.savedAddresses = 0,
    this.defaultAddressLine,
  });

  static const CustomerProfileStats empty = CustomerProfileStats();
}

List<Map<String, dynamic>> _rows(dynamic responseData) {
  if (responseData is Map && responseData['data'] is List) {
    return (responseData['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  throw const FormatException('Profil verileri yüklenemedi.');
}

final customerProfileStatsProvider = FutureProvider<CustomerProfileStats>((
  ref,
) async {
  ref.watch(authNotifierProvider.select((state) => state.user?.id));
  final ApiClient api = ref.read(apiClientProvider);

  Future<List<Map<String, dynamic>>> fetch(String path) async {
    final res = await api.get(path);
    return _rows(res.data);
  }

  final results = await Future.wait([
    fetch('/customer/addresses'),
    fetch('/customer/service-requests'),
    fetch('/customer/appointments'),
  ]);

  final addresses = results[0];
  final requests = results[1];
  final appointments = results[2];

  String? addressLine;
  if (addresses.isNotEmpty) {
    final def = addresses.firstWhere(
      (a) => a['is_default'] == true,
      orElse: () => addresses.first,
    );
    final parts = [def['district'], def['province']]
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) addressLine = parts.join(', ');
  }

  const activeStatuses = {
    'OPEN',
    'ASSIGNED',
    'IN_PROGRESS',
    'AWAITING_CUSTOMER_CONFIRMATION',
  };
  const upcomingStatuses = {'PENDING', 'CONFIRMED', 'ALT_PROPOSED'};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekEnd = today.add(const Duration(days: 7));

  return CustomerProfileStats(
    activeRequests: requests
        .where((r) => activeStatuses.contains(r['status']?.toString()))
        .length,
    upcomingAppointments: appointments.where((a) {
      final date = DateTime.tryParse(a['appointment_date']?.toString() ?? '');
      return upcomingStatuses.contains(a['status']?.toString()) &&
          date != null &&
          !date.isBefore(today) &&
          date.isBefore(weekEnd);
    }).length,
    completedServices:
        appointments
            .where((a) => a['status']?.toString() == 'COMPLETED')
            .length +
        requests.where((r) => r['status']?.toString() == 'COMPLETED').length,
    savedAddresses: addresses.length,
    defaultAddressLine: addressLine,
  );
}, retry: (_, _) => null);
