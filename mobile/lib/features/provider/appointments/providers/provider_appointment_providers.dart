import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/provider_appointment_model.dart';
import '../models/provider_schedule_model.dart';
import '../repositories/provider_appointment_repository.dart';

// ── Provider Appointments List Notifiers ─────────────────────────────────────

final providerAppointmentsProvider =
    AsyncNotifierProvider<
      ProviderAppointmentsNotifier,
      List<ProviderAppointmentModel>
    >(ProviderAppointmentsNotifier.new);

class ProviderAppointmentsNotifier
    extends AsyncNotifier<List<ProviderAppointmentModel>> {
  @override
  Future<List<ProviderAppointmentModel>> build() async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      return await repo.fetchAppointments();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(providerAppointmentRepositoryProvider);
      return repo.fetchAppointments();
    });
  }
}

final providerPendingAppointmentsProvider =
    Provider<List<ProviderAppointmentModel>>((ref) {
      final all = ref.watch(providerAppointmentsProvider).value ?? [];
      return all.where((a) => a.isPending).toList();
    });

final providerUpcomingAppointmentsProvider =
    Provider<List<ProviderAppointmentModel>>((ref) {
      final all = ref.watch(providerAppointmentsProvider).value ?? [];
      final upcoming = all.where((a) => a.isUpcoming).toList();
      upcoming.sort((a, b) {
        final cmpDate = a.appointmentDate.compareTo(b.appointmentDate);
        if (cmpDate != 0) return cmpDate;
        return a.startTime.compareTo(b.startTime);
      });
      return upcoming;
    });

final providerHistoryAppointmentsProvider =
    Provider<List<ProviderAppointmentModel>>((ref) {
      final all = ref.watch(providerAppointmentsProvider).value ?? [];
      return all.where((a) => a.isFinal).toList();
    });

// ── Provider Schedule Notifier ───────────────────────────────────────────────

final providerScheduleNotifierProvider =
    AsyncNotifierProvider<
      ProviderScheduleNotifier,
      List<ProviderWeeklyScheduleModel>
    >(ProviderScheduleNotifier.new);

class ProviderScheduleNotifier
    extends AsyncNotifier<List<ProviderWeeklyScheduleModel>> {
  @override
  Future<List<ProviderWeeklyScheduleModel>> build() async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    return repo.fetchSchedule();
  }

  Future<void> updateSchedule(
    List<ProviderWeeklyScheduleModel> schedules,
  ) async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    final payload = schedules.map((s) => s.toJson()).toList();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return repo.updateSchedule(payload);
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(providerAppointmentRepositoryProvider);
      return repo.fetchSchedule();
    });
  }
}

// ── Provider Closed Dates Notifier ──────────────────────────────────────────

final providerClosedDatesNotifierProvider =
    AsyncNotifierProvider<
      ProviderClosedDatesNotifier,
      List<ProviderClosedDateModel>
    >(ProviderClosedDatesNotifier.new);

class ProviderClosedDatesNotifier
    extends AsyncNotifier<List<ProviderClosedDateModel>> {
  @override
  Future<List<ProviderClosedDateModel>> build() async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    return repo.fetchClosedDates();
  }

  Future<void> addClosedDate({
    required String date,
    required String reason,
    String? note,
  }) async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.storeClosedDate(date: date, reason: reason, note: note);
      return repo.fetchClosedDates();
    });
  }

  Future<void> deleteClosedDate(int id) async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.deleteClosedDate(id);
      return repo.fetchClosedDates();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(providerAppointmentRepositoryProvider);
      return repo.fetchClosedDates();
    });
  }
}

// ── Provider Appointment Detail State & Notifier ────────────────────────────

class ProviderAppointmentDetailState {
  final ProviderAppointmentModel? appointment;
  final ProviderSharedLocation? sharedLocation;
  final bool isLoading;
  final bool isActionLoading;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ProviderAppointmentDetailState({
    this.appointment,
    this.sharedLocation,
    this.isLoading = false,
    this.isActionLoading = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  ProviderAppointmentDetailState copyWith({
    ProviderAppointmentModel? appointment,
    ProviderSharedLocation? sharedLocation,
    bool? isLoading,
    bool? isActionLoading,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearSharedLocation = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ProviderAppointmentDetailState(
      appointment: appointment ?? this.appointment,
      sharedLocation: clearSharedLocation
          ? null
          : (sharedLocation ?? this.sharedLocation),
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearSuccess
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}

final providerAppointmentDetailNotifierProvider =
    NotifierProvider.family<
      ProviderAppointmentDetailNotifier,
      ProviderAppointmentDetailState,
      int
    >(ProviderAppointmentDetailNotifier.new);

class ProviderAppointmentDetailNotifier
    extends Notifier<ProviderAppointmentDetailState> {
  final int appointmentId;
  Timer? _pollTimer;
  bool _pollingAllowed = true;

  ProviderAppointmentDetailNotifier(this.appointmentId);

  @override
  ProviderAppointmentDetailState build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _pollTimer = null;
    });

    return const ProviderAppointmentDetailState(isLoading: true);
  }

  static bool enableAutoPolling = true;

  Timer? get pollTimer => _pollTimer;
  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;

  void startPolling() {
    _pollingAllowed = true;
    _startPolling();
  }

  void stopPolling() {
    _pollingAllowed = false;
    _stopPolling();
  }

  void _startPolling() {
    if (!enableAutoPolling ||
        !_pollingAllowed ||
        !ref.mounted ||
        state.appointment?.isFinal == true) {
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.appointment != null && state.appointment!.isFinal) {
        _stopPolling();
        return;
      }
      _silentRefresh();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadDetail() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(providerAppointmentRepositoryProvider);

    try {
      final appt = await repo.fetchAppointment(appointmentId);
      if (!ref.mounted) return;

      ProviderSharedLocation? location;
      // Location is only fetchable when CONFIRMED / IN_PROGRESS / AWAITING
      if (appt.isConfirmed ||
          appt.isInProgress ||
          appt.isAwaitingConfirmation) {
        try {
          location = await repo.fetchSharedLocation(appointmentId);
        } catch (_) {
          // If revoked or expired, location is null
        }
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        appointment: appt,
        sharedLocation: location,
        isLoading: false,
      );

      if (appt.isFinal) {
        _stopPolling();
      } else {
        _startPolling();
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _silentRefresh() async {
    if (!ref.mounted) return;
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      final appt = await repo.fetchAppointment(appointmentId);
      if (!ref.mounted) return;

      ProviderSharedLocation? location = state.sharedLocation;
      if (appt.isConfirmed ||
          appt.isInProgress ||
          appt.isAwaitingConfirmation) {
        try {
          location = await repo.fetchSharedLocation(appointmentId);
        } catch (_) {
          location = null;
        }
      } else {
        location = null;
      }

      if (!ref.mounted) return;
      state = state.copyWith(appointment: appt, sharedLocation: location);

      if (appt.isFinal) {
        _stopPolling();
      }
    } catch (_) {}
  }

  Future<void> confirmAppointment() async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      final updated = await repo.confirmAppointment(appointmentId);
      state = state.copyWith(
        appointment: updated,
        isActionLoading: false,
        actionSuccessMessage: 'Randevu başarıyla onaylandı.',
      );
      // Refresh all lists
      ref.read(providerAppointmentsProvider.notifier).refresh();
      await loadDetail();
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> rejectAppointment(String reason) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      final updated = await repo.rejectAppointment(
        appointmentId,
        reason: reason,
      );
      _stopPolling();
      state = state.copyWith(
        appointment: updated,
        isActionLoading: false,
        actionSuccessMessage: 'Randevu reddedildi.',
      );
      ref.read(providerAppointmentsProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> proposeAlternatives(List<Map<String, String>> slots) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      final updated = await repo.proposeAlternatives(
        appointmentId,
        slots: slots,
      );
      state = state.copyWith(
        appointment: updated,
        isActionLoading: false,
        actionSuccessMessage: 'Alternatif saat teklifleri müşteriye iletildi.',
      );
      ref.read(providerAppointmentsProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> verifyStartCode(String code) async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      await repo.verifyStartCode(appointmentId, code);
      await loadDetail();
      ref.read(providerAppointmentsProvider.notifier).refresh();
      state = state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'Başlangıç kodu doğrulandı, hizmet başladı.',
      );
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> finishAppointment() async {
    state = state.copyWith(isActionLoading: true, clearError: true);
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      await repo.finishAppointment(appointmentId);
      await loadDetail();
      ref.read(providerAppointmentsProvider.notifier).refresh();
      state = state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'Hizmet tamamlandı olarak işaretlendi.',
      );
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> refreshSharedLocation() async {
    final repo = ref.read(providerAppointmentRepositoryProvider);
    try {
      final loc = await repo.fetchSharedLocation(appointmentId);
      if (ref.mounted) {
        state = state.copyWith(sharedLocation: loc);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(clearSharedLocation: true);
      }
    }
  }
}
