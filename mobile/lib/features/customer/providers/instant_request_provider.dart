import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/customer_address.dart';
import '../models/location_share_status.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../models/service_offer.dart';
import '../models/service_request_model.dart';
import '../repositories/instant_request_repository.dart';
import '../services/geo_service.dart';

// ── Repository & Service Providers ───────────────────────────────────────────

final instantRequestRepositoryProvider = Provider<InstantRequestRepository>((ref) {
  ref.watch(authNotifierProvider.select((state) => state.user?.id));
  final api = ref.watch(apiClientProvider);
  return InstantRequestRepository(api);
});

final geoServiceProvider = Provider<GeoService>((ref) {
  return GeoService();
});

// ── Geography Providers (il / ilçe / mahalle data bundled with the app) ───────

final provincesProvider = FutureProvider<List<GeoProvince>>((ref) async {
  final service = ref.watch(geoServiceProvider);
  return service.getProvinces();
});

final neighborhoodsProvider =
    FutureProvider.family<List<GeoNeighborhood>, int>((ref, districtId) async {
  final service = ref.watch(geoServiceProvider);
  return service.getNeighborhoods(districtId);
});

// ── Service Catalog Providers ─────────────────────────────────────────────────

final serviceCategoriesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(instantRequestRepositoryProvider);
  return repo.fetchCategories();
});

final servicesProvider =
    FutureProvider.family<List<ServiceItem>, String?>((ref, categoryId) async {
  final repo = ref.watch(instantRequestRepositoryProvider);
  return repo.fetchServices(categoryId: categoryId);
});

// ── Customer Addresses Provider ───────────────────────────────────────────────

final customerAddressesProvider = FutureProvider<List<CustomerAddress>>((ref) async {
  final repo = ref.watch(instantRequestRepositoryProvider);
  return repo.fetchAddresses();
});

// ── My Service Requests Provider ──────────────────────────────────────────────

final myServiceRequestsProvider =
    AsyncNotifierProvider<MyServiceRequestsNotifier, List<ServiceRequestModel>>(
  MyServiceRequestsNotifier.new,
);

class MyServiceRequestsNotifier extends AsyncNotifier<List<ServiceRequestModel>> {
  @override
  Future<List<ServiceRequestModel>> build() async {
    final repo = ref.watch(instantRequestRepositoryProvider);
    return repo.fetchServiceRequests();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(instantRequestRepositoryProvider);
      return repo.fetchServiceRequests();
    });
  }
}

// ── Single Request Polling (Notifier.family) ──────────────────────────────────

class ActiveRequestState {
  final ServiceRequestModel? request;
  final bool isLoading;
  final String? error;

  const ActiveRequestState({
    this.request,
    this.isLoading = false,
    this.error,
  });

  ActiveRequestState copyWith({
    ServiceRequestModel? request,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ActiveRequestState(
      request: request ?? this.request,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ActiveRequestNotifier extends Notifier<ActiveRequestState> {
  final int requestId;

  ActiveRequestNotifier(this.requestId);

  @override
  ActiveRequestState build() {
    return const ActiveRequestState(isLoading: true);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final req = await repo.fetchServiceRequest(requestId);
      state = state.copyWith(request: req, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  Future<void> cancel() async {
    final repo = ref.read(instantRequestRepositoryProvider);
    final updated = await repo.cancelServiceRequest(requestId);
    state = state.copyWith(request: updated);
    ref.invalidate(myServiceRequestsProvider);
  }

  Future<void> acceptOffer(int offerId) async {
    final repo = ref.read(instantRequestRepositoryProvider);
    final updated = await repo.acceptOffer(requestId, offerId);
    state = state.copyWith(request: updated);
  }

  Future<void> complete() async {
    final repo = ref.read(instantRequestRepositoryProvider);
    await repo.completeServiceRequest(requestId);
    await load();
    ref.invalidate(myServiceRequestsProvider);
  }

  Future<void> reportProblem(String reason, {String? note}) async {
    final repo = ref.read(instantRequestRepositoryProvider);
    await repo.reportProblem(requestId, reason, note: note);
    await load();
    ref.invalidate(myServiceRequestsProvider);
  }
}

final activeRequestProvider =
    NotifierProvider.family<ActiveRequestNotifier, ActiveRequestState, int>(
  ActiveRequestNotifier.new,
);

// ── Location Share (Notifier.family) ──────────────────────────────────────────

class LocationShareState {
  final LocationShareStatus? status;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const LocationShareState({
    this.status,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  bool get isShared => status?.isShared == true;
  bool get isRevoked => status?.isRevoked == true;
  bool get isExpired => status?.isExpired == true;
  String get displayStatus => status?.displayStatus ?? 'Paylaşılmadı';

  LocationShareState copyWith({
    LocationShareStatus? status,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LocationShareState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class LocationShareNotifier extends Notifier<LocationShareState> {
  final int requestId;

  LocationShareNotifier(this.requestId);

  @override
  LocationShareState build() {
    return const LocationShareState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final res = await repo.fetchLocationStatus(requestId);
      state = LocationShareState(status: res, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> shareSavedAddress({
    required bool explicitConsent,
    int? customerAddressId,
  }) async {
    if (!explicitConsent) {
      state = state.copyWith(error: 'Açık müşteri onayı zorunludur.');
      return false;
    }

    state = state.copyWith(
        isLoading: true, clearError: true, clearSuccess: true);
    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final res = await repo.shareLocation(
        requestId,
        explicitConsent: explicitConsent,
        source: 'SAVED_ADDRESS',
        customerAddressId: customerAddressId,
      );
      state = LocationShareState(
        status: res,
        isLoading: false,
        successMessage: 'Adresiniz hizmet verenle başarıyla paylaşıldı.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> revoke() async {
    state = state.copyWith(
        isLoading: true, clearError: true, clearSuccess: true);
    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      await repo.revokeLocation(requestId);
      final res = await repo.fetchLocationStatus(requestId);
      state = LocationShareState(
        status: res,
        isLoading: false,
        successMessage: 'Konum paylaşımı başarıyla kapatıldı.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final locationShareProvider =
    NotifierProvider.family<LocationShareNotifier, LocationShareState, int>(
  LocationShareNotifier.new,
);

// ── Offers Provider ───────────────────────────────────────────────────────────

final offersProvider =
    FutureProvider.family<List<ServiceOffer>, int>((ref, requestId) async {
  final repo = ref.watch(instantRequestRepositoryProvider);
  return repo.fetchOffers(requestId);
});

// ── Start Code (Notifier.family) ──────────────────────────────────────────────

class StartCodeState {
  final String? code;
  final String? expiresAt;
  final bool isLoading;
  final String? error;

  const StartCodeState({
    this.code,
    this.expiresAt,
    this.isLoading = false,
    this.error,
  });

  StartCodeState copyWith({
    String? code,
    String? expiresAt,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return StartCodeState(
      code: code ?? this.code,
      expiresAt: expiresAt ?? this.expiresAt,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StartCodeNotifier extends Notifier<StartCodeState> {
  final int requestId;

  StartCodeNotifier(this.requestId);

  @override
  StartCodeState build() {
    return const StartCodeState(isLoading: true);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final data = await repo.fetchStartCode(requestId);
      state = StartCodeState(
        code: data['code']?.toString(),
        expiresAt: data['expires_at']?.toString(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> regenerate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final data = await repo.regenerateStartCode(requestId);
      state = StartCodeState(
        code: data['code']?.toString(),
        expiresAt: data['expires_at']?.toString(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final startCodeProvider =
    NotifierProvider.family<StartCodeNotifier, StartCodeState, int>(
  StartCodeNotifier.new,
);

// ── Request Creation Wizard State ─────────────────────────────────────────────

class CreateRequestState {
  final List<int> selectedServiceIds;
  final String selectedCategoryId;
  final int? selectedAddressId;
  final String? approxProvince;
  final String? approxDistrict;
  final String? approxNeighborhood;
  final String paymentMethod;
  final String? customerNote;
  final bool isSubmitting;
  final String? errorMessage;

  const CreateRequestState({
    this.selectedServiceIds = const [],
    this.selectedCategoryId = '',
    this.selectedAddressId,
    this.approxProvince,
    this.approxDistrict,
    this.approxNeighborhood,
    this.paymentMethod = 'CASH',
    this.customerNote,
    this.isSubmitting = false,
    this.errorMessage,
  });

  bool get hasServices => selectedServiceIds.isNotEmpty;
  bool get hasAddress =>
      selectedAddressId != null ||
      (approxProvince != null && approxDistrict != null);

  CreateRequestState copyWith({
    List<int>? selectedServiceIds,
    String? selectedCategoryId,
    int? selectedAddressId,
    String? approxProvince,
    String? approxDistrict,
    String? approxNeighborhood,
    String? paymentMethod,
    String? customerNote,
    bool? isSubmitting,
    String? errorMessage,
    bool clearAddress = false,
    bool clearError = false,
  }) {
    return CreateRequestState(
      selectedServiceIds: selectedServiceIds ?? this.selectedServiceIds,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedAddressId:
          clearAddress ? null : (selectedAddressId ?? this.selectedAddressId),
      approxProvince:
          clearAddress ? null : (approxProvince ?? this.approxProvince),
      approxDistrict:
          clearAddress ? null : (approxDistrict ?? this.approxDistrict),
      approxNeighborhood: clearAddress
          ? null
          : (approxNeighborhood ?? this.approxNeighborhood),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerNote: customerNote ?? this.customerNote,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CreateRequestNotifier extends Notifier<CreateRequestState> {
  @override
  CreateRequestState build() {
    return const CreateRequestState();
  }

  void toggleService(int id) {
    final current = List<int>.from(state.selectedServiceIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedServiceIds: current);
  }

  void selectCategory(String id) {
    state = state.copyWith(selectedCategoryId: id, selectedServiceIds: []);
  }

  void selectAddress(int id) {
    state = state.copyWith(selectedAddressId: id);
  }

  void setManualAddress({
    required String province,
    required String district,
    String? neighborhood,
  }) {
    state = CreateRequestState(
      selectedServiceIds: state.selectedServiceIds,
      selectedCategoryId: state.selectedCategoryId,
      paymentMethod: state.paymentMethod,
      customerNote: state.customerNote,
      isSubmitting: state.isSubmitting,
      approxProvince: province,
      approxDistrict: district,
      approxNeighborhood: neighborhood,
    );
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setCustomerNote(String note) {
    state = state.copyWith(customerNote: note);
  }

  void reset() {
    state = const CreateRequestState();
  }

  Future<ServiceRequestModel?> submit() async {
    if (!state.hasServices) {
      state = state.copyWith(errorMessage: 'Lütfen en az bir hizmet seçin.');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final repo = ref.read(instantRequestRepositoryProvider);
      final result = await repo.createServiceRequest(
        serviceIds: state.selectedServiceIds,
        customerAddressId: state.selectedAddressId,
        approxProvince: state.approxProvince,
        approxDistrict: state.approxDistrict,
        approxNeighborhood: state.approxNeighborhood,
        paymentMethod: state.paymentMethod,
        customerNote: state.customerNote,
      );
      state = state.copyWith(isSubmitting: false);
      ref.invalidate(myServiceRequestsProvider);
      return result;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return null;
    }
  }
}

final createRequestProvider =
    NotifierProvider<CreateRequestNotifier, CreateRequestState>(
  CreateRequestNotifier.new,
);
