class AppointmentAvailabilityModel {
  final int providerId;
  final String date;
  final int totalDurationMinutes;
  final double totalPrice;
  final List<String> availableSlots;

  const AppointmentAvailabilityModel({
    required this.providerId,
    required this.date,
    required this.totalDurationMinutes,
    required this.totalPrice,
    required this.availableSlots,
  });

  bool get hasSlots => availableSlots.isNotEmpty;

  factory AppointmentAvailabilityModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString()));

    final rawSlots = json['available_slots'] as List<dynamic>? ?? [];

    return AppointmentAvailabilityModel(
      providerId: json['provider_id'] is int
          ? json['provider_id'] as int
          : int.tryParse(json['provider_id']?.toString() ?? '') ?? 0,
      date: json['date']?.toString() ?? '',
      totalDurationMinutes:
          parseNum(json['total_duration_minutes'])?.toInt() ?? 0,
      totalPrice: parseNum(json['total_price'])?.toDouble() ?? 0.0,
      availableSlots: rawSlots
          .map((s) => s is Map ? s['start_time']?.toString() : s?.toString())
          .whereType<String>()
          .where((s) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s))
          .toSet()
          .toList(),
    );
  }
}
