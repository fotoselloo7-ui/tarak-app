import 'dart:convert';

import '../../appointments/models/provider_schedule_model.dart';

class ProviderStaffServiceAssignment {
  final int serviceId;
  final String? serviceName;
  final int? customDurationMinutes;
  final bool isActive;

  const ProviderStaffServiceAssignment({
    required this.serviceId,
    this.serviceName,
    this.customDurationMinutes,
    this.isActive = true,
  });

  factory ProviderStaffServiceAssignment.fromJson(Map<String, dynamic> json) {
    return ProviderStaffServiceAssignment(
      serviceId: json['service_id'] is int
          ? json['service_id'] as int
          : int.tryParse(json['service_id']?.toString() ?? '0') ?? 0,
      serviceName: json['service_name']?.toString() ??
          (json['service'] is Map ? json['service']['name']?.toString() : null),
      customDurationMinutes: json['custom_duration_minutes'] is int
          ? json['custom_duration_minutes'] as int
          : int.tryParse(json['custom_duration_minutes']?.toString() ?? ''),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toPayload() => {
        'service_id': serviceId,
        if (customDurationMinutes != null)
          'custom_duration_minutes': customDurationMinutes,
      };
}

class ProviderStaffTimeOffModel {
  final int id;
  final String startDate;
  final String endDate;
  final String? startTime;
  final String? endTime;
  final String reason;
  final String? note;

  const ProviderStaffTimeOffModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    this.reason = 'izin',
    this.note,
  });

  factory ProviderStaffTimeOffModel.fromJson(Map<String, dynamic> json) {
    return ProviderStaffTimeOffModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      reason: json['reason']?.toString() ?? 'izin',
      note: json['note']?.toString(),
    );
  }

  String get displayLabel {
    final range = startDate == endDate ? startDate : '$startDate - $endDate';
    final hours = (startTime != null && endTime != null)
        ? ' ($startTime - $endTime)'
        : ' (Tüm Gün)';
    return '$range$hours';
  }
}

class ProviderStaffModel {
  final int id;
  final int? providerProfileId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? photoUrl;
  final String? title;
  final String? specialty;
  final bool isActive;
  final bool acceptsAppointments;
  final bool visibleToCustomers;
  final int sortOrder;
  final String? archivedAt;
  final List<ProviderStaffServiceAssignment> services;
  final List<ProviderWeeklyScheduleModel> schedule;
  final List<ProviderStaffTimeOffModel> timeOffs;
  final int? availableSlotsCount;
  final bool? isAvailable;

  const ProviderStaffModel({
    required this.id,
    this.providerProfileId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.photoUrl,
    this.title,
    this.specialty,
    this.isActive = true,
    this.acceptsAppointments = true,
    this.visibleToCustomers = true,
    this.sortOrder = 0,
    this.archivedAt,
    this.services = const [],
    this.schedule = const [],
    this.timeOffs = const [],
    this.availableSlotsCount,
    this.isAvailable,
  });

  bool get isArchived => archivedAt != null && archivedAt!.isNotEmpty;

  String get subtitle {
    final parts = <String>[
      if (title != null && title!.trim().isNotEmpty) title!.trim(),
      if (specialty != null && specialty!.trim().isNotEmpty) specialty!.trim(),
    ];
    return parts.join(' • ');
  }

  factory ProviderStaffModel.fromJson(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    final combined = '$first $last'.trim();

    final rawServices = json['services'];
    final servicesList = rawServices is List
        ? rawServices
            .whereType<Map>()
            .map((e) => ProviderStaffServiceAssignment.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : const <ProviderStaffServiceAssignment>[];

    final rawSchedule = json['schedule'];
    final scheduleList = rawSchedule is List
        ? rawSchedule
            .whereType<Map>()
            .map((e) => ProviderWeeklyScheduleModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : const <ProviderWeeklyScheduleModel>[];

    final rawTimeOffs = json['time_offs'];
    final timeOffList = rawTimeOffs is List
        ? rawTimeOffs
            .whereType<Map>()
            .map((e) => ProviderStaffTimeOffModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : const <ProviderStaffTimeOffModel>[];

    return ProviderStaffModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      providerProfileId: json['provider_profile_id'] is int
          ? json['provider_profile_id'] as int
          : int.tryParse(json['provider_profile_id']?.toString() ?? ''),
      firstName: first,
      lastName: last,
      fullName: (json['full_name']?.toString() ?? '').trim().isNotEmpty
          ? json['full_name'].toString().trim()
          : combined,
      photoUrl: json['photo_url']?.toString(),
      title: json['title']?.toString(),
      specialty: json['specialty']?.toString(),
      isActive: json['is_active'] != false,
      acceptsAppointments: json['accepts_appointments'] != false,
      visibleToCustomers: json['visible_to_customers'] != false,
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
      archivedAt: json['archived_at']?.toString(),
      services: servicesList,
      schedule: scheduleList,
      timeOffs: timeOffList,
      availableSlotsCount: json['available_slots_count'] is int
          ? json['available_slots_count'] as int
          : int.tryParse(json['available_slots_count']?.toString() ?? ''),
      isAvailable: json['is_available'] is bool
          ? json['is_available'] as bool
          : null,
    );
  }

  static List<ProviderWeeklyScheduleModel> defaultSchedule() {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days
        .map(
          (d) => ProviderWeeklyScheduleModel(
            day: d,
            dayOfWeek: d,
            isEnabled: d != 'sunday',
            startTime: '09:00',
            endTime: '19:00',
            breaks: const [],
          ),
        )
        .toList();
  }
}

class ProviderOfferedServiceOption {
  final int serviceId;
  final String name;
  final int durationMinutes;

  const ProviderOfferedServiceOption({
    required this.serviceId,
    required this.name,
    required this.durationMinutes,
  });

  factory ProviderOfferedServiceOption.fromJson(Map<String, dynamic> json) {
    final nested = json['service'] is Map
        ? Map<String, dynamic>.from(json['service'] as Map)
        : const <String, dynamic>{};
    final serviceId = json['service_id'] is int
        ? json['service_id'] as int
        : int.tryParse(json['service_id']?.toString() ?? '') ??
            (nested['id'] is int
                ? nested['id'] as int
                : int.tryParse(nested['id']?.toString() ?? '0') ?? 0);
    final duration = json['custom_duration_minutes'] is int
        ? json['custom_duration_minutes'] as int
        : int.tryParse(json['custom_duration_minutes']?.toString() ?? '') ??
            (nested['duration_minutes'] is int
                ? nested['duration_minutes'] as int
                : int.tryParse(nested['duration_minutes']?.toString() ?? '30') ??
                    30);
    final rawName = json['service_name'] ??
        json['name'] ??
        nested['name'] ??
        'Hizmet #$serviceId';

    return ProviderOfferedServiceOption(
      serviceId: serviceId,
      name: rawName.toString(),
      durationMinutes: duration > 0 ? duration : 30,
    );
  }
}

class BirthdayTemplateOption {
  final String key;
  final String label;
  final String body;

  const BirthdayTemplateOption({
    required this.key,
    required this.label,
    required this.body,
  });

  factory BirthdayTemplateOption.fromJson(Map<String, dynamic> json) {
    return BirthdayTemplateOption(
      key: json['key']?.toString() ?? 'classic',
      label: json['label']?.toString() ?? 'Klasik Tebrik',
      body: json['body']?.toString() ?? '',
    );
  }
}

class BirthdayAssistantSettingsModel {
  final bool isEnabled;
  final bool sendOnBirthday;
  final bool sendOneDayBefore;
  final bool sendTwoDaysBefore;
  final String sendTime;
  final String templateKey;
  final String? customMessage;
  final String? requiredPlanTier;
  final bool planEntitled;
  final int eligibleCustomerCount;
  final int sentThisYearCount;
  final int upcomingEligibleBirthdays30d;
  final double unitPrice;
  final bool allowPromoForBirthday;
  final bool fallbackToCash;
  final double usablePromoBalance;
  final double usableCashBalance;
  final bool walletFrozen;
  final bool birthdayBlocked;
  final bool autoSpecialDayBlocked;
  final String? restrictionReason;
  final int monthlyPaidCount;
  final double monthlyTotalSpent;
  final List<Map<String, dynamic>> recentDeliveries;
  final List<BirthdayTemplateOption> templates;

  const BirthdayAssistantSettingsModel({
    this.isEnabled = false,
    this.sendOnBirthday = true,
    this.sendOneDayBefore = false,
    this.sendTwoDaysBefore = false,
    this.sendTime = '10:00',
    this.templateKey = 'classic',
    this.customMessage,
    this.requiredPlanTier,
    this.planEntitled = true,
    this.eligibleCustomerCount = 0,
    this.sentThisYearCount = 0,
    this.upcomingEligibleBirthdays30d = 0,
    this.unitPrice = 0,
    this.allowPromoForBirthday = true,
    this.fallbackToCash = true,
    this.usablePromoBalance = 0,
    this.usableCashBalance = 0,
    this.walletFrozen = false,
    this.birthdayBlocked = false,
    this.autoSpecialDayBlocked = false,
    this.restrictionReason,
    this.monthlyPaidCount = 0,
    this.monthlyTotalSpent = 0,
    this.recentDeliveries = const [],
    this.templates = const [],
  });

  bool get isRestrictedByAdmin => birthdayBlocked || autoSpecialDayBlocked;

  factory BirthdayAssistantSettingsModel.fromJson(Map<String, dynamic> json) {
    final rawTemplates = json['templates'];
    final templatesList = rawTemplates is List
        ? rawTemplates
            .whereType<Map>()
            .map((e) => BirthdayTemplateOption.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : const <BirthdayTemplateOption>[];

    final pricing = json['pricing'] is Map
        ? Map<String, dynamic>.from(json['pricing'] as Map)
        : const <String, dynamic>{};
    final wallet = json['wallet'] is Map
        ? Map<String, dynamic>.from(json['wallet'] as Map)
        : const <String, dynamic>{};
    final permissions = json['permissions'] is Map
        ? Map<String, dynamic>.from(json['permissions'] as Map)
        : const <String, dynamic>{};
    final monthly = json['monthly_summary'] is Map
        ? Map<String, dynamic>.from(json['monthly_summary'] as Map)
        : const <String, dynamic>{};
    final rawDeliveries = json['recent_deliveries'];
    final deliveries = rawDeliveries is List
        ? rawDeliveries
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];

    return BirthdayAssistantSettingsModel(
      isEnabled: json['is_enabled'] == true,
      sendOnBirthday: json['send_on_birthday'] != false,
      sendOneDayBefore: json['send_one_day_before'] == true,
      sendTwoDaysBefore: json['send_two_days_before'] == true,
      sendTime: (json['send_time']?.toString() ?? '10:00').trim().isNotEmpty
          ? json['send_time'].toString().trim()
          : '10:00',
      templateKey: json['template_key']?.toString() ?? 'classic',
      customMessage: json['custom_message']?.toString(),
      requiredPlanTier: json['required_plan_tier']?.toString(),
      planEntitled: json['plan_entitled'] != false,
      eligibleCustomerCount: json['eligible_customer_count'] is int
          ? json['eligible_customer_count'] as int
          : int.tryParse(json['eligible_customer_count']?.toString() ?? '0') ??
              0,
      sentThisYearCount: json['sent_this_year_count'] is int
          ? json['sent_this_year_count'] as int
          : int.tryParse(json['sent_this_year_count']?.toString() ?? '0') ?? 0,
      upcomingEligibleBirthdays30d:
          (json['upcoming_eligible_birthdays_30d'] as num?)?.toInt() ?? 0,
      unitPrice: (pricing['birthday_unit_price'] as num?)?.toDouble() ?? 0,
      allowPromoForBirthday: pricing['allow_promo_for_birthday'] != false,
      fallbackToCash:
          pricing['fallback_to_cash_when_promo_insufficient'] != false,
      usablePromoBalance:
          (wallet['usable_promo_balance'] as num?)?.toDouble() ?? 0,
      usableCashBalance:
          (wallet['usable_cash_balance'] as num?)?.toDouble() ?? 0,
      walletFrozen: wallet['is_frozen'] == true,
      birthdayBlocked: permissions['birthday_blocked'] == true,
      autoSpecialDayBlocked: permissions['auto_special_day_blocked'] == true,
      restrictionReason: permissions['restriction_reason']?.toString(),
      monthlyPaidCount:
          (monthly['paid_notifications_count'] as num?)?.toInt() ?? 0,
      monthlyTotalSpent: (monthly['total_spent'] as num?)?.toDouble() ?? 0,
      recentDeliveries: deliveries,
      templates: templatesList,
    );
  }

  Map<String, dynamic> toPayload() => {
        'is_enabled': isEnabled,
        'send_on_birthday': sendOnBirthday,
        'send_one_day_before': sendOneDayBefore,
        'send_two_days_before': sendTwoDaysBefore,
        'send_time': sendTime,
        'template_key': templateKey,
        'custom_message':
            customMessage?.trim().isNotEmpty == true ? customMessage!.trim() : null,
      };
}

String encodeDebugPrettyJson(Map<String, dynamic> map) => jsonEncode(map);
