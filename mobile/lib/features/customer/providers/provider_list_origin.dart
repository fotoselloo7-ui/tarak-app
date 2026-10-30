import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/providers/auth_provider.dart';
import 'instant_request_provider.dart';

/// Where the customer is, for the distance filter / "en yakın" sorting of the provider lists.
/// Providers' own coordinates never reach the app; the API returns `distance_km` per card.
class ListOrigin {
  final double lat;
  final double lng;

  /// Taken from the device (true) or from the customer's default saved address (false).
  final bool fromDevice;
  const ListOrigin({required this.lat, required this.lng, this.fromDevice = false});

  @override
  bool operator ==(Object other) => other is ListOrigin && other.lat == lat && other.lng == lng && other.fromDevice == fromDevice;

  @override
  int get hashCode => Object.hash(lat, lng, fromDevice);
}

enum DeviceLocationStatus { idle, locating, denied, unavailable }

/// Reads the approximate device position; replaced in tests (no plugin there).
abstract class DeviceLocator {
  /// Throws [DeviceLocationStatus.denied] / [DeviceLocationStatus.unavailable] as a [DeviceLocationException].
  Future<ListOrigin> locate();
}

class DeviceLocationException implements Exception {
  final DeviceLocationStatus status;
  const DeviceLocationException(this.status);
}

class GeolocatorDeviceLocator implements DeviceLocator {
  const GeolocatorDeviceLocator();

  @override
  Future<ListOrigin> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(DeviceLocationStatus.unavailable);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(DeviceLocationStatus.denied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );
      return ListOrigin(lat: position.latitude, lng: position.longitude, fromDevice: true);
    } catch (_) {
      throw const DeviceLocationException(DeviceLocationStatus.unavailable);
    }
  }
}

final deviceLocatorProvider = Provider<DeviceLocator>((ref) => const GeolocatorDeviceLocator());

class ProviderListOriginState {
  final ListOrigin? device;
  final DeviceLocationStatus status;
  const ProviderListOriginState({this.device, this.status = DeviceLocationStatus.idle});
}

final providerListOriginProvider = NotifierProvider<ProviderListOriginNotifier, ProviderListOriginState>(ProviderListOriginNotifier.new);

class ProviderListOriginNotifier extends Notifier<ProviderListOriginState> {
  int _locationRequest = 0;

  @override
  ProviderListOriginState build() {
    ref.watch(authNotifierProvider.select((s) => s.user?.id));
    ++_locationRequest;
    return const ProviderListOriginState();
  }

  void useSavedAddress() {
    ++_locationRequest;
    state = const ProviderListOriginState();
  }

  /// "Konumumu kullan": asks for the permission (once) and remembers the position for every list.
  Future<void> useDevice() async {
    if (state.status == DeviceLocationStatus.locating) return;
    final userId = ref.read(authNotifierProvider).user?.id;
    final request = ++_locationRequest;
    state = ProviderListOriginState(device: state.device, status: DeviceLocationStatus.locating);
    try {
      final origin = await ref.read(deviceLocatorProvider).locate().timeout(const Duration(seconds: 15));
      if (!ref.mounted || request != _locationRequest || ref.read(authNotifierProvider).user?.id != userId) return;
      state = ProviderListOriginState(device: origin);
    } on DeviceLocationException catch (e) {
      if (!ref.mounted || request != _locationRequest || ref.read(authNotifierProvider).user?.id != userId) return;
      state = ProviderListOriginState(device: state.device, status: e.status);
    } catch (_) {
      if (!ref.mounted || request != _locationRequest || ref.read(authNotifierProvider).user?.id != userId) return;
      state = ProviderListOriginState(device: state.device, status: DeviceLocationStatus.unavailable);
    }
  }
}

/// The origin every list measures from: the device position once the customer allowed it,
/// otherwise the default saved address that has coordinates (signed-in customers only).
final listOriginProvider = Provider<ListOrigin?>((ref) {
  final device = ref.watch(providerListOriginProvider).device;
  if (device != null) return device;
  final isCustomer = ref.watch(authNotifierProvider.select((s) => s.isCustomer));
  if (!isCustomer) return null;
  final addressState = ref.watch(customerAddressesProvider);
  if (addressState.isLoading || addressState.hasError) return null;
  final addresses = addressState.value;
  if (addresses == null) return null;
  // The default address has priority, including when it lacks coordinates.
  // Falling back to an old address silently shows the wrong city (e.g. Alanya
  // instead of a newly selected address in Şişli).
  final defaults = addresses.where((a) => a.isDefault).toList();
  final chosen = defaults.firstOrNull;
  if (chosen?.latitude == null || chosen?.longitude == null) return null;
  return ListOrigin(lat: chosen!.latitude!, lng: chosen.longitude!);
});
