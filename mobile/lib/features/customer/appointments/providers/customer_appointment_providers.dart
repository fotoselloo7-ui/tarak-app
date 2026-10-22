import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/provider_list_tools.dart';
import '../../models/customer_address.dart';
import '../../models/location_share_status.dart';
import '../../models/service_item.dart';
import '../../providers/provider_list_origin.dart';
import '../../../offerings/models/offering_models.dart';
import '../../../offerings/providers/offerings_providers.dart';
import '../models/customer_appointment_model.dart';
import '../models/scheduled_provider_model.dart';
import '../repositories/customer_appointment_repository.dart';

/// User-facing message for a failed call. Server messages are already
/// sanitized by the backend; anything else gets a generic text (no raw dumps).
String appointmentErrorMessage(Object e) {
  if (e is AppException && e.message.isNotEmpty) return e.message;
  return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Repository Provider ─────────────────────────────────────────────────────

final customerAppointmentRepositoryProvider =
    Provider<CustomerAppointmentRepository>((ref) {
      final api = ref.watch(apiClientProvider);
      return CustomerAppointmentRepository(api);
    });

// ── Appointments List Provider ──────────────────────────────────────────────

final customerAppointmentsProvider =
    AsyncNotifierProvider<
      CustomerAppointmentsNotifier,
      List<CustomerAppointmentModel>
    >(CustomerAppointmentsNotifier.new);

class CustomerAppointmentsNotifier
    extends AsyncNotifier<List<CustomerAppointmentModel>> {
  @override
  Future<List<CustomerAppointmentModel>> build() async {
    final repo = ref.watch(customerAppointmentRepositoryProvider);
    return repo.fetchAppointments();
  }

  /// Pull-to-refresh keeps the current list visible while reloading.
  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final repo = ref.read(customerAppointmentRepositoryProvider);
      return repo.fetchAppointments();
    });
    if (!ref.mounted) return;
    state = next;
  }
}

// ── Appointment Detail State & Notifier ─────────────────────────────────────

/// Result of the customer's own location share actions for this screen.
/// The status endpoint only reports the *active* grant, so a revoked or
/// expired grant is remembered from the last known grant.
enum LocationShareNote { none, revoked, expired }

class AppointmentDetailState {
  final CustomerAppointmentModel? appointment;
  final LocationShareStatus? locationStatus;
  final LocationShareNote locationNote;
  final String? startCode;
  final bool startCodeLoaded;
  final bool isLoading;
  final bool isActionLoading;
  final String? errorMessage;

  const AppointmentDetailState({
    this.appointment,
    this.locationStatus,
    this.locationNote = LocationShareNote.none,
    this.startCode,
    this.startCodeLoaded = false,
    this.isLoading = false,
    this.isActionLoading = false,
    this.errorMessage,
  });

  /// Paylaşıldı / Paylaşılmadı / Süresi doldu / İptal edildi
  String get locationLabel {
    if (locationStatus?.isShared == true) return 'Paylaşıldı';
    switch (locationNote) {
      case LocationShareNote.revoked:
        return 'İptal edildi';
      case LocationShareNote.expired:
        return 'Süresi doldu';
      case LocationShareNote.none:
        return 'Paylaşılmadı';
    }
  }

  AppointmentDetailState copyWith({
    CustomerAppointmentModel? appointment,
    LocationShareStatus? locationStatus,
    LocationShareNote? locationNote,
    String? startCode,
    bool? startCodeLoaded,
    bool? isLoading,
    bool? isActionLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearStartCode = false,
    bool clearLocation = false,
  }) {
    return AppointmentDetailState(
      appointment: appointment ?? this.appointment,
      locationStatus: clearLocation
          ? null
          : (locationStatus ?? this.locationStatus),
      locationNote: locationNote ?? this.locationNote,
      startCode: clearStartCode ? null : (startCode ?? this.startCode),
      startCodeLoaded: startCodeLoaded ?? this.startCodeLoaded,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final customerAppointmentDetailNotifierProvider =
    NotifierProvider.family<
      CustomerAppointmentDetailNotifier,
      AppointmentDetailState,
      int
    >(CustomerAppointmentDetailNotifier.new);

class CustomerAppointmentDetailNotifier
    extends Notifier<AppointmentDetailState> {
  final int appointmentId;
  Timer? _pollTimer;
  bool _pollingAllowed = true;

  CustomerAppointmentDetailNotifier(this.appointmentId);

  static const pollInterval = Duration(seconds: 15);

  /// Tests switch this off to avoid periodic timers.
  static bool enableAutoPolling = true;

  @override
  AppointmentDetailState build() {
    ref.onDispose(_stopPolling);
    return const AppointmentDetailState(isLoading: true);
  }

  Timer? get pollTimer => _pollTimer;
  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;

  /// Called by the screen on resume. No-op for final states.
  void startPolling() {
    _pollingAllowed = true;
    final appt = state.appointment;
    if (appt != null && appt.isFinal) return;
    _startPolling();
  }

  void stopPolling() {
    _pollingAllowed = false;
    _stopPolling();
  }

  void _startPolling() {
    if (!enableAutoPolling || !_pollingAllowed || !ref.mounted) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (!ref.mounted) return _stopPolling();
      if (state.appointment?.isFinal == true) return _stopPolling();
      _refresh(silent: true);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadDetail() => _refresh(silent: false);

  Future<void> _refresh({required bool silent}) async {
    if (!ref.mounted) return;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(customerAppointmentRepositoryProvider);

    try {
      final appt = await repo.fetchAppointment(appointmentId);
      if (!ref.mounted) return;

      // Gated extras: only requested when the backend reports readiness.
      LocationShareStatus? loc;
      var note = state.locationNote;
      if (appt.canShareLocation) {
        try {
          loc = await repo.fetchLocationStatus(appointmentId);
          final prev = state.locationStatus?.grant;
          if (loc.isShared) {
            note = LocationShareNote.none;
          } else if (prev != null && state.locationStatus?.isShared == true) {
            final exp = prev.expiresAt;
            note = exp != null && exp.isBefore(DateTime.now())
                ? LocationShareNote.expired
                : LocationShareNote.revoked;
          }
        } catch (_) {
          loc = state.locationStatus;
        }
      }

      String? code = state.startCode;
      var codeLoaded = state.startCodeLoaded;
      if (appt.canShowStartCode) {
        if (!silent || code == null) {
          try {
            final data = await repo.fetchStartCode(appointmentId);
            final raw = data['code']?.toString();
            code = (raw != null && raw.isNotEmpty) ? raw : null;
          } catch (_) {
            code = null;
          }
          codeLoaded = true;
        }
      } else {
        code = null;
        codeLoaded = false;
      }

      if (!ref.mounted) return;
      state = AppointmentDetailState(
        appointment: appt,
        locationStatus: appt.canShareLocation ? loc : null,
        locationNote: appt.canShareLocation ? note : LocationShareNote.none,
        startCode: code,
        startCodeLoaded: codeLoaded,
        isLoading: false,
        isActionLoading: state.isActionLoading,
        errorMessage: silent ? state.errorMessage : null,
      );

      if (appt.isFinal) {
        _stopPolling();
      } else if (!isPolling) {
        _startPolling();
      }
    } catch (e) {
      if (!ref.mounted || silent) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: appointmentErrorMessage(e),
      );
    }
  }

  /// Runs a server action; on failure shows the error and re-syncs with the
  /// server so the UI never keeps an optimistic/fake state. Returns success.
  Future<bool> _action(Future<void> Function() call) async {
    if (state.isActionLoading) return false;
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      await call();
      if (!ref.mounted) return true;
      state = state.copyWith(isActionLoading: false);
      await _refresh(silent: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      final message = appointmentErrorMessage(e);
      state = state.copyWith(isActionLoading: false);
      await _refresh(silent: false);
      if (ref.mounted) state = state.copyWith(errorMessage: message);
      return false;
    }
  }

  Future<bool> cancelAppointment() => _action(() async {
    await ref
        .read(customerAppointmentRepositoryProvider)
        .cancelAppointment(appointmentId);
  });

  Future<bool> acceptAlternative(int slotId) => _action(() async {
    await ref
        .read(customerAppointmentRepositoryProvider)
        .acceptAlternative(appointmentId: appointmentId, slotId: slotId);
  });

  Future<bool> rejectAlternative() => _action(() async {
    await ref
        .read(customerAppointmentRepositoryProvider)
        .rejectAlternative(appointmentId);
  });

  /// Must only be called after the explicit consent dialog was accepted.
  Future<bool> shareLocation(int customerAddressId) => _action(() async {
    await ref
        .read(customerAppointmentRepositoryProvider)
        .shareLocation(
          appointmentId,
          explicitConsent: true,
          customerAddressId: customerAddressId,
        );
  });

  Future<bool> revokeLocation() async {
    final ok = await _action(() async {
      await ref
          .read(customerAppointmentRepositoryProvider)
          .revokeLocation(appointmentId);
    });
    if (ok && ref.mounted && state.locationStatus?.isShared != true) {
      state = state.copyWith(locationNote: LocationShareNote.revoked);
    }
    return ok;
  }

  Future<bool> regenerateStartCode() async {
    if (state.isActionLoading) return false;
    state = state.copyWith(isActionLoading: true, clearError: true);
    try {
      final res = await ref
          .read(customerAppointmentRepositoryProvider)
          .regenerateStartCode(appointmentId);
      if (!ref.mounted) return true;
      final raw = res['code']?.toString();
      state = state.copyWith(
        startCode: (raw != null && raw.isNotEmpty) ? raw : null,
        clearStartCode: raw == null || raw.isEmpty,
        startCodeLoaded: true,
        isActionLoading: false,
      );
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: appointmentErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> completeAppointment() => _action(() async {
    await ref
        .read(customerAppointmentRepositoryProvider)
        .completeAppointment(appointmentId);
  });

  Future<bool> reportProblem(String reason, {String? note}) =>
      _action(() async {
        await ref
            .read(customerAppointmentRepositoryProvider)
            .reportProblem(appointmentId, reason: reason, note: note);
      });
}

// ── Appointment Creation Wizard State & Notifier ────────────────────────────

class AppointmentWizardState {
  final List<ServiceItem> selectedServices;
  final List<ScheduledProviderModel> availableProviders;

  /// Running list ads for the chosen services / filters, shown as "Önerilen" above the organic list.
  final List<ScheduledProviderModel> sponsoredProviders;

  /// How often the recommended set changes (seconds); the provider step asks again after that.
  final int? rotationSeconds;
  final ProviderListFilters providerFilters;
  final bool isLoadingProviders;
  final String? providersError;
  final ScheduledProviderModel? selectedProvider;
  final List<ProviderPackageModel> providerPackages;
  final bool isLoadingPackages;
  final ProviderPackageModel? selectedPackage;
  final DateTime? selectedDate;
  final List<String> availableSlots;
  final bool isLoadingAvailability;
  final String? availabilityError;
  final String? selectedSlot;
  final CustomerAddress? selectedAddress;
  final String paymentMethod; // CASH or ONLINE
  final String? customerNote;
  final double? estimatedPrice;
  final int? estimatedDurationMinutes;
  final bool isSubmitting;
  final bool slotConflict;
  final String? errorMessage;

  const AppointmentWizardState({
    this.selectedServices = const [],
    this.availableProviders = const [],
    this.sponsoredProviders = const [],
    this.rotationSeconds,
    this.providerFilters = const ProviderListFilters(),
    this.isLoadingProviders = false,
    this.providersError,
    this.selectedProvider,
    this.providerPackages = const [],
    this.isLoadingPackages = false,
    this.selectedPackage,
    this.selectedDate,
    this.availableSlots = const [],
    this.isLoadingAvailability = false,
    this.availabilityError,
    this.selectedSlot,
    this.selectedAddress,
    this.paymentMethod = 'CASH',
    this.customerNote,
    this.estimatedPrice,
    this.estimatedDurationMinutes,
    this.isSubmitting = false,
    this.slotConflict = false,
    this.errorMessage,
  });

  bool get canProceedToProvider => selectedServices.isNotEmpty;
  bool get canProceedToDateTime => selectedProvider != null;
  bool get hasBookableSelection =>
      selectedPackage != null || selectedServices.isNotEmpty;
  bool get canProceedToAddress =>
      selectedDate != null &&
      selectedSlot != null &&
      (availableSlots.isEmpty || availableSlots.contains(selectedSlot));
  bool get canProceedToPayment => selectedAddress != null;
  bool get canReview =>
      canProceedToPayment &&
      (paymentMethod == 'CASH' || paymentMethod == 'ONLINE');

  AppointmentWizardState copyWith({
    List<ServiceItem>? selectedServices,
    List<ScheduledProviderModel>? availableProviders,
    List<ScheduledProviderModel>? sponsoredProviders,
    int? rotationSeconds,
    ProviderListFilters? providerFilters,
    bool? isLoadingProviders,
    String? providersError,
    ScheduledProviderModel? selectedProvider,
    List<ProviderPackageModel>? providerPackages,
    bool? isLoadingPackages,
    ProviderPackageModel? selectedPackage,
    DateTime? selectedDate,
    List<String>? availableSlots,
    bool? isLoadingAvailability,
    String? availabilityError,
    String? selectedSlot,
    CustomerAddress? selectedAddress,
    String? paymentMethod,
    String? customerNote,
    double? estimatedPrice,
    int? estimatedDurationMinutes,
    bool? isSubmitting,
    bool? slotConflict,
    String? errorMessage,
    bool clearProvider = false,
    bool clearPackage = false,
    bool clearSlot = false,
    bool clearError = false,
    bool clearProvidersError = false,
    bool clearAvailabilityError = false,
    bool clearEstimate = false,
  }) {
    return AppointmentWizardState(
      selectedServices: selectedServices ?? this.selectedServices,
      availableProviders: availableProviders ?? this.availableProviders,
      sponsoredProviders: sponsoredProviders ?? this.sponsoredProviders,
      rotationSeconds: rotationSeconds ?? this.rotationSeconds,
      providerFilters: providerFilters ?? this.providerFilters,
      isLoadingProviders: isLoadingProviders ?? this.isLoadingProviders,
      providersError: clearProvidersError
          ? null
          : (providersError ?? this.providersError),
      selectedProvider: clearProvider
          ? null
          : (selectedProvider ?? this.selectedProvider),
      providerPackages: providerPackages ?? this.providerPackages,
      isLoadingPackages: isLoadingPackages ?? this.isLoadingPackages,
      selectedPackage: clearPackage
          ? null
          : (selectedPackage ?? this.selectedPackage),
      selectedDate: selectedDate ?? this.selectedDate,
      availableSlots: availableSlots ?? this.availableSlots,
      isLoadingAvailability:
          isLoadingAvailability ?? this.isLoadingAvailability,
      availabilityError: clearAvailabilityError
          ? null
          : (availabilityError ?? this.availabilityError),
      selectedSlot: clearSlot ? null : (selectedSlot ?? this.selectedSlot),
      selectedAddress: selectedAddress ?? this.selectedAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerNote: customerNote ?? this.customerNote,
      estimatedPrice: clearEstimate
          ? null
          : (estimatedPrice ?? this.estimatedPrice),
      estimatedDurationMinutes: clearEstimate
          ? null
          : (estimatedDurationMinutes ?? this.estimatedDurationMinutes),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      slotConflict: slotConflict ?? this.slotConflict,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final appointmentWizardProvider =
    NotifierProvider<AppointmentWizardNotifier, AppointmentWizardState>(
      AppointmentWizardNotifier.new,
    );

class AppointmentWizardNotifier extends Notifier<AppointmentWizardState> {
  // Monotonic tokens: a slower, older response never overwrites a newer one.
  int _providersReq = 0;
  int _availabilityReq = 0;

  @override
  AppointmentWizardState build() => const AppointmentWizardState();

  void toggleService(ServiceItem service) {
    final list = List<ServiceItem>.from(state.selectedServices);
    if (list.any((s) => s.id == service.id)) {
      list.removeWhere((s) => s.id == service.id);
    } else {
      list.add(service);
    }

    state = state.copyWith(
      selectedServices: list,
      clearProvider: true,
      clearPackage: true,
      providerPackages: const [],
      clearSlot: true,
      availableSlots: const [],
      availableProviders: const [],
      sponsoredProviders: const [],
      clearEstimate: true,
      clearError: true,
      clearProvidersError: true,
      clearAvailabilityError: true,
      slotConflict: false,
    );

    if (list.isNotEmpty) loadProviders();
  }

  /// Search / stars / distance / sort of the provider step: the backend answers with the filtered list.
  void setProviderFilters(ProviderListFilters filters) {
    if (filters == state.providerFilters) return;
    state = state.copyWith(providerFilters: filters);
    loadProviders();
  }

  /// Discovery for ALL selected services, decided by the backend (filters and list ads included).
  Future<void> loadProviders() async {
    if (state.selectedServices.isEmpty) return;
    final req = ++_providersReq;
    state = state.copyWith(isLoadingProviders: true, clearProvidersError: true);
    try {
      final result = await ref
          .read(customerAppointmentRepositoryProvider)
          .fetchProviderList(
            serviceIds: state.selectedServices.map((s) => s.id).toList(),
            filters: state.providerFilters.toQuery(ref.read(listOriginProvider)),
          );
      if (!ref.mounted || req != _providersReq) return;
      state = state.copyWith(
        availableProviders: result.providers,
        sponsoredProviders: result.sponsored,
        rotationSeconds: result.rotationSeconds,
        isLoadingProviders: false,
      );
    } catch (e) {
      if (!ref.mounted || req != _providersReq) return;
      state = state.copyWith(
        isLoadingProviders: false,
        providersError: appointmentErrorMessage(e),
      );
    }
  }

  /// The recommended set changes every few seconds: asks for just the cards again (same filters).
  Future<void> refreshRecommended() async {
    if (state.selectedServices.isEmpty || state.isLoadingProviders) return;
    final result = await ref.read(customerAppointmentRepositoryProvider).fetchProviderList(
          serviceIds: state.selectedServices.map((s) => s.id).toList(),
          filters: {...state.providerFilters.toQuery(ref.read(listOriginProvider)), 'sponsored_only': 1},
        );
    if (!ref.mounted) return;
    state = state.copyWith(sponsoredProviders: result.sponsored, rotationSeconds: result.rotationSeconds);
  }

  void selectProvider(ScheduledProviderModel provider) {
    state = state.copyWith(
      selectedProvider: provider,
      clearPackage: true,
      providerPackages: const [],
      clearSlot: true,
      availableSlots: const [],
      clearEstimate: true,
      clearError: true,
      clearAvailabilityError: true,
    );
    loadProviderPackages(provider.userId);
    if (state.selectedDate != null) loadAvailability();
  }

  /// Load the chosen provider's active packages (optional upsell in scheduled flow).
  Future<void> loadProviderPackages(int providerUserId) async {
    state = state.copyWith(isLoadingPackages: true);
    try {
      final bundle = await ref
          .read(customerOfferingsRepositoryProvider)
          .fetchProviderOfferings(providerUserId);
      if (!ref.mounted || state.selectedProvider?.userId != providerUserId) {
        return;
      }
      state = state.copyWith(
        providerPackages: bundle.packages,
        isLoadingPackages: false,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        providerPackages: const [],
        isLoadingPackages: false,
      );
    }
  }

  /// Select/deselect a package. A package books as a whole; slot/estimate reset.
  void selectPackage(ProviderPackageModel? pkg) {
    final isSame = pkg != null && state.selectedPackage?.id == pkg.id;
    state = state.copyWith(
      selectedPackage: isSame ? null : pkg,
      clearPackage: isSame || pkg == null,
      clearSlot: true,
      availableSlots: const [],
      clearEstimate: true,
      clearError: true,
      clearAvailabilityError: true,
    );
    if (state.selectedProvider != null && state.selectedDate != null) {
      loadAvailability();
    }
  }

  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: DateTime(date.year, date.month, date.day),
      clearSlot: true,
      availableSlots: const [],
      clearError: true,
      clearAvailabilityError: true,
      slotConflict: false,
    );
    if (state.selectedProvider != null) loadAvailability();
  }

  /// Real slots from the backend availability engine; nothing is generated here.
  Future<void> loadAvailability() async {
    if (state.selectedProvider == null ||
        state.selectedDate == null ||
        !state.hasBookableSelection) {
      return;
    }
    final req = ++_availabilityReq;
    state = state.copyWith(
      isLoadingAvailability: true,
      clearAvailabilityError: true,
    );

    try {
      final availability = await ref
          .read(customerAppointmentRepositoryProvider)
          .fetchAvailability(
            providerId: state.selectedProvider!.userId,
            date: _ymd(state.selectedDate!),
            serviceIds: state.selectedPackage != null
                ? const []
                : state.selectedServices.map((s) => s.id).toList(),
            providerPackageId: state.selectedPackage?.id,
          );
      if (!ref.mounted || req != _availabilityReq) return;

      final keepSlot =
          state.selectedSlot != null &&
          availability.availableSlots.contains(state.selectedSlot);
      state = state.copyWith(
        availableSlots: availability.availableSlots,
        estimatedPrice: availability.totalPrice,
        estimatedDurationMinutes: availability.totalDurationMinutes,
        isLoadingAvailability: false,
        clearSlot: !keepSlot,
      );
    } catch (e) {
      if (!ref.mounted || req != _availabilityReq) return;
      state = state.copyWith(
        isLoadingAvailability: false,
        availableSlots: const [],
        clearSlot: true,
        availabilityError: appointmentErrorMessage(e),
      );
    }
  }

  void selectSlot(String slot) {
    if (state.availableSlots.isNotEmpty && !state.availableSlots.contains(slot)) {
      return; // only backend slots
    }
    state = state.copyWith(
      selectedSlot: slot,
      clearError: true,
      slotConflict: false,
    );
  }

  void selectAddress(CustomerAddress address) {
    state = state.copyWith(selectedAddress: address, clearError: true);
  }

  void setPaymentMethod(String method) {
    final m = method.toUpperCase();
    if (m != 'CASH' && m != 'ONLINE') return;
    state = state.copyWith(paymentMethod: m, clearError: true);
  }

  void setCustomerNote(String note) {
    state = state.copyWith(customerNote: note);
  }

  /// Creates the appointment. Returns null on failure (error in state).
  /// A 409 marks [AppointmentWizardState.slotConflict], clears the slot and
  /// reloads availability; nothing is created locally.
  Future<CustomerAppointmentModel?> submitAppointment() async {
    if (state.isSubmitting) return null; // double-tap guard
    if (state.selectedProvider == null ||
        state.selectedDate == null ||
        state.selectedSlot == null ||
        state.selectedAddress == null ||
        !state.hasBookableSelection) {
      state = state.copyWith(
        errorMessage: 'Lütfen tüm randevu bilgilerini eksiksiz doldurun.',
      );
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      slotConflict: false,
    );

    try {
      final appt = await ref
          .read(customerAppointmentRepositoryProvider)
          .createAppointment(
            providerId: state.selectedProvider!.userId,
            serviceIds: state.selectedPackage != null
                ? const []
                : state.selectedServices.map((s) => s.id).toList(),
            providerPackageId: state.selectedPackage?.id,
            date: _ymd(state.selectedDate!),
            time: state.selectedSlot!,
            customerAddressId: state.selectedAddress!.id,
            customerNote: state.customerNote,
            paymentMethod: state.paymentMethod,
          );
      if (!ref.mounted) return appt;
      state = state.copyWith(isSubmitting: false);
      return appt;
    } catch (e) {
      if (!ref.mounted) return null;
      final conflict = e is AppException && e.statusCode == 409;
      state = state.copyWith(
        isSubmitting: false,
        slotConflict: conflict,
        clearSlot: conflict,
        errorMessage: conflict ? kSlotTakenMessage : appointmentErrorMessage(e),
      );
      if (conflict) await loadAvailability();
      return null;
    }
  }

  void reset() {
    _providersReq++;
    _availabilityReq++;
    state = const AppointmentWizardState();
  }
}
