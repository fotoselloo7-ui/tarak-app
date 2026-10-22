class ProviderScheduleBreakModel {
  final int? id;
  final String startTime;
  final String endTime;

  const ProviderScheduleBreakModel({
    this.id,
    required this.startTime,
    required this.endTime,
  });

  factory ProviderScheduleBreakModel.fromJson(Map<String, dynamic> json) {
    return ProviderScheduleBreakModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      startTime: json['start_time']?.toString() ?? '13:00',
      endTime: json['end_time']?.toString() ?? '14:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  ProviderScheduleBreakModel copyWith({
    int? id,
    String? startTime,
    String? endTime,
  }) {
    return ProviderScheduleBreakModel(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class ProviderWeeklyScheduleModel {
  final int? id;
  final String day;
  final String dayOfWeek;
  final bool isEnabled;
  final String startTime;
  final String endTime;
  final List<ProviderScheduleBreakModel> breaks;

  const ProviderWeeklyScheduleModel({
    this.id,
    required this.day,
    required this.dayOfWeek,
    required this.isEnabled,
    required this.startTime,
    required this.endTime,
    this.breaks = const [],
  });

  String get dayLabel {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Pazartesi';
      case 'tuesday':
        return 'Salı';
      case 'wednesday':
        return 'Çarşamba';
      case 'thursday':
        return 'Perşembe';
      case 'friday':
        return 'Cuma';
      case 'saturday':
        return 'Cumartesi';
      case 'sunday':
        return 'Pazar';
      default:
        return day;
    }
  }

  factory ProviderWeeklyScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawBreaks = json['breaks'];
    List<ProviderScheduleBreakModel> parsedBreaks = [];
    if (rawBreaks is List) {
      parsedBreaks = rawBreaks
          .map((b) => ProviderScheduleBreakModel.fromJson(b as Map<String, dynamic>))
          .toList();
    }

    final dayStr = (json['day'] ?? json['day_of_week'] ?? 'monday').toString();

    return ProviderWeeklyScheduleModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      day: dayStr,
      dayOfWeek: (json['day_of_week'] ?? dayStr).toString(),
      isEnabled: json['is_enabled'] == true || json['enabled'] == true,
      startTime: json['start_time']?.toString() ?? '09:00',
      endTime: json['end_time']?.toString() ?? '19:00',
      breaks: parsedBreaks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'day_of_week': dayOfWeek,
      'is_enabled': isEnabled,
      'start_time': startTime,
      'end_time': endTime,
      'breaks': breaks.map((b) => b.toJson()).toList(),
    };
  }

  ProviderWeeklyScheduleModel copyWith({
    int? id,
    String? day,
    String? dayOfWeek,
    bool? isEnabled,
    String? startTime,
    String? endTime,
    List<ProviderScheduleBreakModel>? breaks,
  }) {
    return ProviderWeeklyScheduleModel(
      id: id ?? this.id,
      day: day ?? this.day,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breaks: breaks ?? this.breaks,
    );
  }
}

class ProviderClosedDateModel {
  final int id;
  final String date;
  final String reason;
  final String? note;

  const ProviderClosedDateModel({
    required this.id,
    required this.date,
    required this.reason,
    this.note,
  });

  factory ProviderClosedDateModel.fromJson(Map<String, dynamic> json) {
    return ProviderClosedDateModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      date: json['date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'reason': reason,
      'note': note,
    };
  }
}
