import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/api_client.dart';
import 'secure_storage_service.dart';

enum SemanticRouteTab { home, requests, appointments, messages, profile }

class SemanticDeepLink {
  final SemanticRouteTab tab;
  final String? resourceType;
  final int? resourceId;
  final int? conversationId;
  final String? eventType;

  const SemanticDeepLink({
    required this.tab,
    this.resourceType,
    this.resourceId,
    this.conversationId,
    this.eventType,
  });

  bool get hasAppointmentDetail {
    final t = eventType?.toUpperCase() ?? '';
    final rType = resourceType?.toUpperCase() ?? '';
    if (resourceId == null) return false;
    if (rType == 'APPOINTMENT' || rType == 'SCHEDULED_APPOINTMENT') {
      return true;
    }
    return t.startsWith('APPOINTMENT_');
  }

  /// A provider's discount campaign ("bildirim reklamı"): opens that provider's profile.
  bool get hasProviderProfile {
    if (resourceId == null) return false;
    return resourceType?.toUpperCase() == 'PROVIDER_PROFILE' || eventType?.toUpperCase() == 'PROVIDER_CAMPAIGN';
  }

  bool get hasRequestDetail {
    final t = eventType?.toUpperCase() ?? '';
    final rType = resourceType?.toUpperCase() ?? '';
    if (rType == 'APPOINTMENT' ||
        rType == 'SCHEDULED_APPOINTMENT' ||
        t.startsWith('APPOINTMENT_')) {
      return false;
    }
    if (t != 'MESSAGE_RECEIVED' &&
        (rType == 'INSTANT_REQUEST' ||
            rType == 'SERVICE_REQUEST' ||
            rType == 'INSTANT_JOB')) {
      return resourceId != null;
    }
    return resourceId != null &&
        (t == 'OFFER_RECEIVED' ||
            t == 'SERVICE_STARTED' ||
            t == 'PROVIDER_MARKED_FINISHED' ||
            t == 'DISPUTE_OPENED' ||
            t == 'DISPUTE_RESOLVED_CUSTOMER' ||
            t == 'DISPUTE_RESOLVED_PROVIDER');
  }
}

class NotificationPreferences {
  final bool push;
  final bool campaign;
  final bool appointmentReminderEnabled;
  final int appointmentReminderMinutes;
  final bool appointmentStartAlertEnabled;
  final bool birthdayGreetingEnabled;

  const NotificationPreferences({
    required this.push,
    required this.campaign,
    this.appointmentReminderEnabled = true,
    this.appointmentReminderMinutes = 30,
    this.appointmentStartAlertEnabled = true,
    this.birthdayGreetingEnabled = false,
  });

  factory NotificationPreferences.fromJson(Map<dynamic, dynamic> data) {
    final push = data['push_enabled'];
    if (push is! bool) {
      throw const FormatException('Bildirim tercihi yüklenemedi.');
    }
    final campaign = data['campaign_enabled'];
    final reminderEnabled = data['appointment_reminder_enabled'];
    final rawMinutes = data['appointment_reminder_minutes'];
    final parsedMinutes = rawMinutes is num
        ? rawMinutes.toInt()
        : int.tryParse(rawMinutes?.toString() ?? '') ?? 30;
    final clampedMinutes = parsedMinutes < 5
        ? 5
        : (parsedMinutes > 1440 ? 1440 : parsedMinutes);
    final startAlertEnabled = data['appointment_start_alert_enabled'];
    final birthdayEnabled = data['birthday_greeting_enabled'];

    return NotificationPreferences(
      push: push,
      campaign: campaign is bool ? campaign : true,
      appointmentReminderEnabled:
          reminderEnabled is bool ? reminderEnabled : true,
      appointmentReminderMinutes: clampedMinutes,
      appointmentStartAlertEnabled:
          startAlertEnabled is bool ? startAlertEnabled : true,
      birthdayGreetingEnabled:
          birthdayEnabled is bool ? birthdayEnabled : false,
    );
  }

  NotificationPreferences copyWith({
    bool? push,
    bool? campaign,
    bool? appointmentReminderEnabled,
    int? appointmentReminderMinutes,
    bool? appointmentStartAlertEnabled,
    bool? birthdayGreetingEnabled,
  }) {
    return NotificationPreferences(
      push: push ?? this.push,
      campaign: campaign ?? this.campaign,
      appointmentReminderEnabled:
          appointmentReminderEnabled ?? this.appointmentReminderEnabled,
      appointmentReminderMinutes:
          appointmentReminderMinutes ?? this.appointmentReminderMinutes,
      appointmentStartAlertEnabled:
          appointmentStartAlertEnabled ?? this.appointmentStartAlertEnabled,
      birthdayGreetingEnabled:
          birthdayGreetingEnabled ?? this.birthdayGreetingEnabled,
    );
  }
}

class PushNotificationService {
  static const MethodChannel _androidForegroundPush =
      MethodChannel('app.tarak.mobile/notifications');
  late final ApiClient _apiClient;
  late final SecureStorageService _storage;

  bool _isFirebaseInitialized = false;
  bool _isRegistered = false;
  StreamSubscription<String>? _tokenRefreshSub;

  final StreamController<SemanticDeepLink> _deepLinkController =
      StreamController<SemanticDeepLink>.broadcast();

  Stream<SemanticDeepLink> get deepLinkStream => _deepLinkController.stream;

  // The notification bell updates from server state whenever FCM delivers.
  // No local unread count is invented: the UI refetches /notifications/unread-count.
  final StreamController<RemoteMessage> _arrivalController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get notificationArrivals => _arrivalController.stream;

  PushNotificationService({
    required ApiClient apiClient,
    required SecureStorageService storage,
  }) {
    _apiClient = apiClient;
    _storage = storage;
  }

  bool get isFirebaseInitialized => _isFirebaseInitialized;
  bool get isRegistered => _isRegistered;

  /// Gracefully initialize Firebase without crashing if configuration files are missing.
  ///
  /// Options come from the native config files, not from Dart:
  /// Android `android/app/google-services.json` (processed by the
  /// google-services Gradle plugin) and iOS `ios/Runner/GoogleService-Info.plist`
  /// (bundled in the Runner target). Without them this throws and push stays off.
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        // Attempt default platform initialization
        await Firebase.initializeApp();
      }
      _isFirebaseInitialized = true;
      debugPrint(
        '[PushNotificationService] Firebase initialized successfully.',
      );

      // iOS does not display foreground notifications by default.
      if (!kIsWeb && Platform.isIOS) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      _setupMessageHandlers();
    } catch (e) {
      _isFirebaseInitialized = false;
      debugPrint(
        '[PushNotificationService] Firebase init gracefully skipped: $e',
      );
    }
  }

  /// Request runtime notification permissions (called gracefully after user login).
  Future<void> requestPermissions() async {
    if (!_isFirebaseInitialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        '[PushNotificationService] Permission status: ${settings.authorizationStatus}',
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Permission request skipped: $e');
    }
  }

  /// Register device FCM token with backend.
  Future<void> registerDevice() async {
    if (!_isFirebaseInitialized) {
      debugPrint(
        '[PushNotificationService] Skipping device registration: Firebase not initialized.',
      );
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          '[PushNotificationService] FCM token is null or empty, skipping backend registration.',
        );
        return;
      }

      final installationId = await _storage.getInstallationId();
      final appVersion = await _getAppVersion();
      final deviceModel = await _getDeviceModel();
      final platform = kIsWeb
          ? 'ANDROID'
          : (Platform.isIOS ? 'IOS' : 'ANDROID');

      await _apiClient.post(
        '/push/devices',
        data: {
          'platform': platform,
          'token': token,
          'installation_id': installationId,
          'app_version': appVersion,
          'device_model': deviceModel,
        },
      );

      _isRegistered = true;
      debugPrint(
        '[PushNotificationService] FCM device registered with backend.',
      );

      // Listen for token rotations
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        newToken,
      ) async {
        debugPrint(
          '[PushNotificationService] FCM token refreshed, updating backend...',
        );
        try {
          await _apiClient.post(
            '/push/devices',
            data: {
              'platform': platform,
              'token': newToken,
              'installation_id': installationId,
              'app_version': appVersion,
              'device_model': deviceModel,
            },
          );
        } catch (err) {
          debugPrint(
            '[PushNotificationService] Failed to update rotated token: $err',
          );
        }
      });
    } catch (e) {
      debugPrint('[PushNotificationService] Device registration error: $e');
    }
  }

  /// Unregister device upon logout.
  Future<void> unregisterDevice() async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _isRegistered = false;
  }

  /// Fetch user push notification preference.
  Future<bool> getPushPreference() async {
    final response = await _apiClient.get('/push/preferences');
    final value = response.data is Map ? response.data['push_enabled'] : null;
    if (value is! bool) {
      throw const FormatException('Bildirim tercihi yüklenemedi.');
    }
    return value;
  }

  /// Push, campaign and appointment reminder preferences.
  Future<NotificationPreferences> getNotificationPreferences() async {
    final response = await _apiClient.get('/push/preferences');
    final data = response.data is Map ? response.data as Map : const {};
    return NotificationPreferences.fromJson(data);
  }

  Future<bool> updateCampaignPreference(bool enabled) async {
    final response = await _apiClient.put(
      '/push/preferences',
      data: {'campaign_enabled': enabled},
    );
    final value = response.data is Map ? response.data['campaign_enabled'] : null;
    if (value is! bool) {
      throw const FormatException('Bildirim tercihi kaydedilemedi.');
    }
    return value;
  }

  Future<NotificationPreferences> updateAppointmentReminderPreferences({
    bool? appointmentReminderEnabled,
    int? appointmentReminderMinutes,
    bool? appointmentStartAlertEnabled,
    bool? birthdayGreetingEnabled,
  }) async {
    final payload = <String, dynamic>{};
    if (appointmentReminderEnabled != null) {
      payload['appointment_reminder_enabled'] = appointmentReminderEnabled;
    }
    if (appointmentReminderMinutes != null) {
      payload['appointment_reminder_minutes'] = appointmentReminderMinutes;
    }
    if (appointmentStartAlertEnabled != null) {
      payload['appointment_start_alert_enabled'] =
          appointmentStartAlertEnabled;
    }
    if (birthdayGreetingEnabled != null) {
      payload['birthday_greeting_enabled'] = birthdayGreetingEnabled;
    }
    final response = await _apiClient.put('/push/preferences', data: payload);
    final data = response.data is Map ? response.data as Map : const {};
    return NotificationPreferences.fromJson(data);
  }

  /// Update user push notification preference.
  Future<bool> updatePushPreference(bool enabled) async {
    final response = await _apiClient.put(
      '/push/preferences',
      data: {'push_enabled': enabled},
    );
    final value = response.data is Map ? response.data['push_enabled'] : null;
    if (value is! bool) {
      throw const FormatException('Bildirim tercihi kaydedilemedi.');
    }
    return value;
  }

  void _setupMessageHandlers() {
    // When notification is tapped while app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _arrivalController.add(message);
      _resolveSemanticDeepLink(message.data);
    });

    // Handle cold start from notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        _arrivalController.add(message);
        _resolveSemanticDeepLink(message.data);
      }
    });

    // iOS presents the remote alert via setForegroundNotificationPresentationOptions.
    // Android does not auto-display foreground FCM alerts, so use the native
    // notification channel shared with the background FCM payload.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      _arrivalController.add(message);
      if (!kIsWeb && Platform.isAndroid) {
        final title = message.notification?.title ??
            message.data['title']?.toString() ?? 'Tarak';
        final body = message.notification?.body ??
            message.data['body']?.toString() ?? '';
        if (body.isNotEmpty) {
          final id = int.tryParse(message.data['notification_id']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
          try {
            await _androidForegroundPush.invokeMethod<bool>('show', {
              'title': title,
              'body': body,
              'id': id,
            });
          } catch (e) {
            debugPrint('[PushNotificationService] Foreground alert failed: $e');
          }
        }
      }
    });
  }

  /// Handle incoming push notification payload and trigger deep linking
  void handleIncomingPayload(Map<String, dynamic> data) {
    _resolveSemanticDeepLink(data);
  }

  /// Resolve semantic notification data into appropriate app shell tab & target resource.
  void _resolveSemanticDeepLink(Map<String, dynamic> data) {
    final type = data['type']?.toString().toUpperCase() ?? '';
    final resourceType = data['resource_type']?.toString();
    final rawResourceId = data['resource_id'] ?? data['request_id'];
    final resourceId = rawResourceId is int
        ? rawResourceId
        : int.tryParse(rawResourceId?.toString() ?? '');

    final rawConversationId = data['conversation_id'];
    final conversationId = rawConversationId is int
        ? rawConversationId
        : int.tryParse(rawConversationId?.toString() ?? '');

    SemanticRouteTab targetTab;
    if (type == 'MESSAGE_RECEIVED') {
      targetTab = SemanticRouteTab.messages;
    } else if (type.startsWith('APPOINTMENT_') ||
        resourceType?.toUpperCase() == 'APPOINTMENT' ||
        resourceType?.toUpperCase() == 'SCHEDULED_APPOINTMENT') {
      targetTab = SemanticRouteTab.appointments;
    } else if (type.startsWith('OFFER_') ||
        type.startsWith('SERVICE_') ||
        type.startsWith('REQUEST_') ||
        type.startsWith('DISPUTE_') ||
        type.startsWith('PROVIDER_MARKED_FINISHED')) {
      targetTab = SemanticRouteTab.requests;
    } else {
      targetTab = SemanticRouteTab.home;
    }

    _deepLinkController.add(
      SemanticDeepLink(
        tab: targetTab,
        resourceType: resourceType,
        resourceId: resourceId,
        conversationId: conversationId,
        eventType: type,
      ),
    );
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '1.0.0';
    }
  }

  Future<String> _getDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
      } else if (!kIsWeb && Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }
      return 'Generic Device';
    } catch (_) {
      return 'Mobile Device';
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _deepLinkController.close();
    _arrivalController.close();
  }
}
