import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../customer/models/service_offer.dart';
import '../../../customer/models/service_request_model.dart';
import '../models/provider_profile_model.dart';
import '../models/provider_shared_location_model.dart';
import '../repositories/provider_instant_repository.dart';

// ── Repository Provider ─────────────────────────────────────────────────────

final providerInstantRepositoryProvider = Provider<ProviderInstantRepository>((
  ref,
) {
  ref.watch(authNotifierProvider.select((state) => state.user?.id));
  final api = ref.watch(apiClientProvider);
  return ProviderInstantRepository(api);
});

// ── Provider Profile Notifier (Online / Offline State) ──────────────────────

final providerProfileNotifierProvider =
    AsyncNotifierProvider<ProviderProfileNotifier, ProviderProfileModel>(
      ProviderProfileNotifier.new,
    );

class ProviderProfileNotifier extends AsyncNotifier<ProviderProfileModel> {
  @override
  Future<ProviderProfileModel> build() async {
    final repo = ref.watch(providerInstantRepositoryProvider);
    return repo.getProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(providerInstantRepositoryProvider);
      return repo.getProfile();
    });
  }

  /// Reason of the last failed [setOnline] call, ready to show to the user.
  /// Null after a successful toggle.
  String? lastOnlineError;

  /// Toggle online status. Canonical state is refreshed from server response.
  ///
  /// A failed toggle keeps the last known profile on screen (the status simply
  /// does not change) instead of turning the whole profile into an error state.
  Future<bool> setOnline(bool isOnline) async {
    final previous = state.value;
    lastOnlineError = null;
    try {
      final repo = ref.read(providerInstantRepositoryProvider);
      final updatedProfile = await repo.updateOnlineStatus(isOnline);
      // providerMarketplaceRequestsProvider watches this profile, so it reloads by itself
      // when the state changes. Invalidating it here as well made Riverpod throw a
      // CircularDependencyError while that provider was on screen (İşler tab).
      state = AsyncData(updatedProfile);
      return true;
    } catch (e, st) {
      lastOnlineError = e is AppException
          ? e.message
          : 'Hizmet durumu güncellenemedi. Lütfen tekrar deneyin.';
      state = previous != null ? AsyncData(previous) : AsyncError(e, st);
      return false;
    }
  }
}

// ── Marketplace Requests Provider ───────────────────────────────────────────

final providerMarketplaceRequestsProvider =
    FutureProvider<List<ServiceRequestModel>>((ref) async {
      final profileAsync = ref.watch(providerProfileNotifierProvider);
      final profile = profileAsync.value;

      // If provider is offline, never show open marketplace requests
      if (profile != null && !profile.isOnline) {
        return const [];
      }

      final repo = ref.watch(providerInstantRepositoryProvider);
      return repo.getMarketplaceRequests();
    });

// ── Assigned Requests Provider (Active & Past Jobs) ─────────────────────────

final providerAssignedRequestsProvider =
    AsyncNotifierProvider<
      ProviderAssignedRequestsNotifier,
      List<ServiceRequestModel>
    >(ProviderAssignedRequestsNotifier.new);

class ProviderAssignedRequestsNotifier
    extends AsyncNotifier<List<ServiceRequestModel>> {
  @override
  Future<List<ServiceRequestModel>> build() async {
    final repo = ref.watch(providerInstantRepositoryProvider);
    return repo.getAssignedRequests();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      final repo = ref.read(providerInstantRepositoryProvider);
      return repo.getAssignedRequests();
    });
  }
}

// ── My Offers Provider ──────────────────────────────────────────────────────

final providerMyOffersProvider =
    AsyncNotifierProvider<ProviderMyOffersNotifier, List<ServiceOffer>>(
      ProviderMyOffersNotifier.new,
    );

class ProviderMyOffersNotifier extends AsyncNotifier<List<ServiceOffer>> {
  @override
  Future<List<ServiceOffer>> build() async {
    final repo = ref.watch(providerInstantRepositoryProvider);
    return repo.getMyOffers();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      final repo = ref.read(providerInstantRepositoryProvider);
      return repo.getMyOffers();
    });
  }
}

// ── Active Job Detail Notifier (Family per requestId) ─────────────────────────

final activeJobDetailNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveJobDetailNotifier, ServiceRequestModel, int>(
      ActiveJobDetailNotifier.new,
    );

class ActiveJobDetailNotifier extends AsyncNotifier<ServiceRequestModel> {
  final int requestId;

  ActiveJobDetailNotifier(this.requestId);

  @override
  Future<ServiceRequestModel> build() async {
    final repo = ref.watch(providerInstantRepositoryProvider);
    return repo.getMarketplaceRequest(requestId);
  }

  Future<void> refresh() async {
    // Keep the detail subtree mounted during polling so code input and scroll
    // position survive. Errors still replace stale data with the retry state.
    if (!state.hasValue) state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(providerInstantRepositoryProvider);
      return repo.getMarketplaceRequest(requestId);
    });
  }

  /// Verify 4-digit start code with backend and refetch canonical state.
  Future<Map<String, dynamic>> verifyStartCode(String code) async {
    final repo = ref.read(providerInstantRepositoryProvider);
    final result = await repo.verifyStartCode(requestId, code);
    await refresh();
    await ref.read(providerAssignedRequestsProvider.notifier).refresh();
    return result;
  }

  /// Mark service as finished by provider and refetch canonical state.
  Future<Map<String, dynamic>> finishService() async {
    final repo = ref.read(providerInstantRepositoryProvider);
    final result = await repo.finishService(requestId);
    await refresh();
    await ref.read(providerAssignedRequestsProvider.notifier).refresh();
    return result;
  }
}

// ── Transient Exact Shared Location Provider (Family per requestId) ─────────
// Privacy Rule: Never persisted to storage, immediately disposed when leaving screen.

final transientSharedLocationProvider = AsyncNotifierProvider.autoDispose
    .family<TransientSharedLocationNotifier, ProviderSharedLocationModel?, int>(
      TransientSharedLocationNotifier.new,
    );

class TransientSharedLocationNotifier
    extends AsyncNotifier<ProviderSharedLocationModel?> {
  final int requestId;

  TransientSharedLocationNotifier(this.requestId);

  @override
  Future<ProviderSharedLocationModel?> build() async {
    final repo = ref.watch(providerInstantRepositoryProvider);
    return repo.getSharedLocation(requestId);
  }

  Future<void> fetch() async {
    if (!state.hasValue) state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(providerInstantRepositoryProvider);
      return repo.getSharedLocation(requestId);
    });
  }
}

// ── Provider Wallet (real balances for the profile tab) ──────────────────────

class ProviderWalletSummary {
  final double cashBalance;
  final double promoBalance;
  final double pendingBalance;
  final double withdrawable;
  final String? iban;

  /// "İlk 500 TL komisyon Tarak.app'ten!": a commission-only gift right, never withdrawable cash.
  final ProviderGiftSummary gift;

  /// Bank-paid commission credit (deposited), what is held for accepted cash jobs and what is free for new ones.
  final double depositedBalance;
  final double reservedTotal;
  final double usableCommission;
  final List<ProviderReservation> reservations;

  const ProviderWalletSummary({
    this.cashBalance = 0,
    this.promoBalance = 0,
    this.pendingBalance = 0,
    this.withdrawable = 0,
    this.iban,
    this.gift = const ProviderGiftSummary(),
    this.depositedBalance = 0,
    this.reservedTotal = 0,
    this.usableCommission = 0,
    this.reservations = const [],
  });
}

class ProviderGiftSummary {
  final double granted;
  final double used;
  final double remaining;
  final bool hasGift;
  final bool isDepleted;
  final String campaignMessage;

  const ProviderGiftSummary({
    this.granted = 0,
    this.used = 0,
    this.remaining = 0,
    this.hasGift = false,
    this.isDepleted = false,
    this.campaignMessage = "İlk 500 TL komisyon Tarak.app'ten!",
  });

  /// 0..1 share of the gift that is already used.
  double get usedShare => granted <= 0 ? 0 : (used / granted).clamp(0, 1).toDouble();

  factory ProviderGiftSummary.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    final message = json['campaign_message']?.toString();
    return ProviderGiftSummary(
      granted: n(json['granted']),
      used: n(json['used']),
      remaining: n(json['remaining']),
      hasGift: json['has_gift'] == true,
      isDepleted: json['is_depleted'] == true,
      campaignMessage: message == null || message.isEmpty ? "İlk 500 TL komisyon Tarak.app'ten!" : message,
    );
  }
}

class ProviderReservation {
  final String label;
  final String status;
  final double commission;
  final double promoPart;
  final double cashPart;

  const ProviderReservation({
    required this.label,
    required this.status,
    required this.commission,
    required this.promoPart,
    required this.cashPart,
  });

  bool get inDispute => status == 'HELD_DISPUTE';

  factory ProviderReservation.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return ProviderReservation(
      label: json['label']?.toString() ?? 'Rezervasyon',
      status: json['status']?.toString() ?? 'RESERVED',
      commission: n(json['commission_amount']),
      promoPart: n(json['reserved_promo_amount']),
      cashPart: n(json['reserved_cash_amount']),
    );
  }
}

final providerWalletSummaryProvider = FutureProvider<ProviderWalletSummary>((
  ref,
) async {
  ref.watch(authNotifierProvider.select((state) => state.user?.id));
  final api = ref.watch(apiClientProvider);
  double num0(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  String? iban;
  double cash = 0, promo = 0, pending = 0, withdrawable = 0;
  final w = (await api.get('/provider/wallet')).data as Map<String, dynamic>;
  final d = w['data'];
  if (d is! Map) throw const FormatException('Cüzdan bilgileri yüklenemedi.');
  cash = num0(d['cash_balance'] ?? d['balance']);
  promo = num0(d['promo_balance']);
  pending = num0(d['pending_balance'] ?? d['reserved_cash_balance']);
  withdrawable = num0(d['withdrawable_balance']);
  final giftJson = d['gift'];
  final gift = giftJson is Map
      ? ProviderGiftSummary.fromJson(Map<String, dynamic>.from(giftJson))
      : const ProviderGiftSummary();
  final reservations = d['active_reservations'] is List
      ? (d['active_reservations'] as List)
          .whereType<Map>()
          .map((e) => ProviderReservation.fromJson(Map<String, dynamic>.from(e)))
          .toList()
      : <ProviderReservation>[];
  final p =
      (await api.get('/provider/payout-account')).data as Map<String, dynamic>;
  if (p['success'] != true) {
    throw const FormatException('Hakediş hesabı yüklenemedi.');
  }
  // The payout endpoint exposes only the masked IBAN — never the full one.
  iban = (p['data'] as Map<String, dynamic>?)?['iban_masked']?.toString();
  return ProviderWalletSummary(
    cashBalance: cash,
    promoBalance: promo,
    pendingBalance: pending,
    withdrawable: withdrawable,
    iban: iban,
    gift: gift,
    depositedBalance: num0(d['deposited_balance'] ?? d['cash_balance']),
    reservedTotal: num0(d['reserved_total']),
    usableCommission: num0(d['usable_commission_balance'] ?? d['available_for_commission']),
    reservations: reservations,
  );
}, retry: (_, _) => null);
