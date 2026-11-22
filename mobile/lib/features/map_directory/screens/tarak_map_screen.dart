import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:dio/dio.dart' show CancelToken, DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../../core/widgets/verified_tick.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../customer/appointments/screens/create_appointment_screen.dart';
import '../../customer/models/customer_address.dart';
import '../../customer/providers/instant_request_provider.dart';
import '../../customer/providers/provider_list_origin.dart';
import '../../customer/screens/service_selection_screen.dart';
import '../../customer/services/geo_service.dart';
import '../models/map_business_model.dart';
import '../models/map_route_model.dart';
import '../providers/map_directory_providers.dart';
import '../services/directions_launcher.dart';
import '../services/map_route_service.dart';
import '../services/tarak_marker_renderer.dart';
import '../services/turkey_province_centers.dart';
import '../widgets/map_business_sheet.dart';

typedef TarakMapWidgetBuilder = Widget Function(
  BuildContext context,
  List<MapBusinessSummary> pins,
  MapBusinessSummary? selected,
  void Function(MapBusinessSummary business) onSelectBusiness,
);

typedef DevicePositionFetcher = Future<({double lat, double lng})?> Function();

enum _MapLocationStatus { idle, locating, ready, denied, timeout, unavailable }

class TarakMapScreen extends ConsumerStatefulWidget {
  final bool isGuest;
  final MapBusinessFilter? initialFilter;
  final TarakMapWidgetBuilder? mapBuilder;
  final ExternalUriLauncher? directionsLauncher;
  final DevicePositionFetcher? positionFetcher;
  final MapRouteFetcher? routeFetcher;
  final AssetBundle? markerAssetBundle;
  final bool autoLocateOnOpen;
  final void Function(double lat, double lng, double zoom)?
      onCameraTargetChanged;

  const TarakMapScreen({
    super.key,
    this.isGuest = false,
    this.initialFilter,
    this.mapBuilder,
    this.directionsLauncher,
    this.positionFetcher,
    this.routeFetcher,
    this.markerAssetBundle,
    this.autoLocateOnOpen = true,
    this.onCameraTargetChanged,
  });

  static List<Map<String, dynamic>> _buildTarakFeatures(
    List<MapBusinessSummary> tarakPins, {
    String? selectedFeatureKey,
  }) {
    final features = <Map<String, dynamic>>[];

    for (var i = 0; i < tarakPins.length; i++) {
      final b = tarakPins[i];
      if (!b.hasPublicPin || b.latitude == null || b.longitude == null) {
        continue;
      }
      final featureKey = 'tarak:${b.userId}';
      final category = b.providerType == 'coiffeur' ? 'coiffeur' : 'barber';
      final iconId = TarakMarkerRenderer.spriteIdFor(
        category: category,
        isVerified: b.isVerified,
        isSelected: selectedFeatureKey == featureKey,
      );
      final numericId = int.tryParse(b.userId) ?? (i + 1);

      features.add({
        'type': 'Feature',
        'id': numericId,
        'geometry': {
          'type': 'Point',
          'coordinates': [b.longitude!, b.latitude!],
        },
        'properties': {
          'feature_key': featureKey,
          'source': 'tarak',
          'user_id': b.userId,
          'profile_id': b.id,
          'slug': b.slug,
          'category': category,
          'business_name': b.businessName,
          'icon_id': iconId,
        },
      });
    }
    return features;
  }

  /// Builds GeoJSON FeatureCollection containing ONLY verified/directory Tarak pins.
  static Map<String, dynamic> buildTarakGeoJson(
    List<MapBusinessSummary> tarakPins, {
    String? selectedFeatureKey,
  }) {
    return {
      'type': 'FeatureCollection',
      'features': _buildTarakFeatures(
        tarakPins,
        selectedFeatureKey: selectedFeatureKey,
      ),
    };
  }

  @override
  ConsumerState<TarakMapScreen> createState() => _TarakMapScreenState();
}

class _TarakMapScreenState extends ConsumerState<TarakMapScreen> {
  static const String _defaultStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
  static const String _sourceId = 'tarak-businesses';
  static const String _clusterLayerId = 'tarak-clusters';
  static const String _pinLayerId = 'tarak-pins';
  static const String _routeSourceId = 'tarak-active-route';
  static const String _routeCasingLayerId = 'tarak-route-casing';
  static const String _routeLineLayerId = 'tarak-route-line';
  static const String _routeEndpointsSourceId = 'tarak-active-route-endpoints';
  static const String _routeOriginLayerId = 'tarak-route-origin';
  static const String _routeDestLayerId = 'tarak-route-dest';

  static const LatLng _turkeyCenter = LatLng(39.9255, 32.8663);
  static const double _turkeyZoom = 5.8;
  static const double _userFocusZoom = 14.0;

  final TextEditingController _searchController = TextEditingController();
  late final TarakMarkerRenderer _markerRenderer =
      TarakMarkerRenderer(bundle: widget.markerAssetBundle);

  Timer? _searchDebounce;
  CancelToken? _routeCancelToken;
  CancelToken? _areaGeocodeCancelToken;
  CancelToken? _searchGeocodeCancelToken;
  DateTime? _lastTapHandledAt;

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _sourceAdded = false;
  bool _routeSourceAdded = false;
  bool _syncInFlight = false;
  bool _syncQueued = false;
  bool _showListView = false;
  bool _locatingUser = false;
  bool _searchingLocation = false;
  bool _initialLocateAttempted = false;
  bool _cameraMovedSinceFetch = false;
  bool _suppressNextCameraIdle = false;

  LatLng _cameraTarget = _turkeyCenter;
  double _cameraZoom = _turkeyZoom;
  LatLng? _userLocation;
  LatLng? _deviceGpsLocation;
  LatLng? _savedDefaultAddressLocation;
  String? _savedDefaultAddressLabel;
  _MapLocationStatus _locationStatus = _MapLocationStatus.idle;
  bool _locationBannerDismissed = false;

  bool _routeLoading = false;
  MapRouteResult? _activeRoute;
  String _routeOriginMode = 'auto'; // 'auto' | 'gps' | 'saved'
  String _activeRouteOriginLabel = '';
  LatLng? _activeRouteOrigin;
  LatLng? _preRouteCameraTarget;
  double? _preRouteCameraZoom;
  String? _pendingAreaCameraCity;
  String? _pendingAreaCameraDistrict;

  List<MapBusinessSummary> _currentTarakPins = const <MapBusinessSummary>[];
  MapBusinessSummary? _selectedBusiness;

  final GlobalKey _mapViewportKey = GlobalKey();
  OverlayEntry? _androidMapTouchOverlay;
  bool _selectedSheetExpanded = false;
  int? _trackedPointerId;
  int? _lastOverlayPointerId;
  Offset? _pointerDownLocalPos;
  DateTime? _pointerDownTime;
  double _pointerMaxMoveLogical = 0.0;
  LatLng? _pointerDownCameraTarget;
  double _pointerDownZoom = 12.0;

  DateTime? _lastEmptyMapTapAt;
  Offset? _lastEmptyMapTapLocalPos;
  final Map<int, Offset> _activeMapPointers = <int, Offset>{};
  bool _isPinchZooming = false;
  double _pinchStartDist = 0.0;
  Offset _pinchStartMid = Offset.zero;
  double _pinchStartZoom = 12.0;
  LatLng _pinchStartTarget = _turkeyCenter;
  DateTime? _lastLiveCameraMoveAt;

  String? get _currentSelectedFeatureKey {
    if (_selectedBusiness != null) return 'tarak:${_selectedBusiness!.userId}';
    return null;
  }

  void _clearAndroidPlatformViewFocus() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        widget.mapBuilder != null) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _syncAndroidMapTouchOverlay() {
    if (!mounted ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        widget.mapBuilder != null ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    if (_androidMapTouchOverlay == null) {
      _androidMapTouchOverlay = OverlayEntry(
        builder: _buildAndroidMapTouchOverlay,
      );
      overlay.insert(_androidMapTouchOverlay!);
    } else {
      _androidMapTouchOverlay!.markNeedsBuild();
    }
  }

  Widget _buildAndroidMapTouchOverlay(BuildContext overlayContext) {
    if (!mounted || _showListView || _selectedSheetExpanded) {
      return const SizedBox.shrink();
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return const SizedBox.shrink();
    }
    final ro = _mapViewportKey.currentContext?.findRenderObject();
    final mapOriginY =
        (ro is RenderBox && ro.hasSize) ? ro.localToGlobal(Offset.zero).dy : 212.0;
    final mapHeight =
        (ro is RenderBox && ro.hasSize) ? ro.size.height : 678.0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final mapBottomMargin = max(0.0, screenHeight - (mapOriginY + mapHeight));

    double topOffset = mapOriginY;
    if (_cameraMovedSinceFetch) {
      topOffset += 56.0;
    }

    double bottomOffset = mapBottomMargin;
    if (_selectedBusiness != null) {
      bottomOffset = mapBottomMargin + (mapHeight * 0.43);
    }

    if (topOffset >= screenHeight - bottomOffset - 40.0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      bottom: bottomOffset,
      child: BlockSemantics(
        blocking: true,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (e) => _handleMapPointerSignal(e, mapOriginY),
          onPointerDown: (e) {
            final box = _mapViewportKey.currentContext?.findRenderObject();
            final local = (box is RenderBox && box.hasSize)
                ? box.globalToLocal(e.position)
                : Offset(e.position.dx, e.position.dy - mapOriginY);
            _activeMapPointers[e.pointer] = local;
            if (_activeMapPointers.length == 2) {
              _beginPinchGesture();
            } else if (_activeMapPointers.length == 1 && !_isPinchZooming) {
              _startMapPointerTracking(
                pointer: e.pointer,
                localPos: local,
                globalPos: e.position,
                source: 'overlayEntry',
              );
            }
          },
          onPointerMove: (e) {
            final box = _mapViewportKey.currentContext?.findRenderObject();
            final local = (box is RenderBox && box.hasSize)
                ? box.globalToLocal(e.position)
                : Offset(e.position.dx, e.position.dy - mapOriginY);
            if (_activeMapPointers.containsKey(e.pointer)) {
              _activeMapPointers[e.pointer] = local;
            }
            if (_isPinchZooming && _activeMapPointers.length >= 2) {
              _updatePinchGesture();
            } else if (!_isPinchZooming &&
                e.pointer == _trackedPointerId &&
                _pointerDownLocalPos != null) {
              _updateLiveDragGesture(local);
            }
          },
          onPointerUp: (e) {
            _activeMapPointers.remove(e.pointer);
            if (_isPinchZooming) {
              if (_activeMapPointers.isEmpty) {
                _finishPinchGesture();
              }
              return;
            }
            if (e.pointer != _trackedPointerId) return;
            final box = _mapViewportKey.currentContext?.findRenderObject();
            final local = (box is RenderBox && box.hasSize)
                ? box.globalToLocal(e.position)
                : Offset(e.position.dx, e.position.dy - mapOriginY);
            _finishMapPointerTracking(local);
          },
          onPointerCancel: (e) {
            _activeMapPointers.remove(e.pointer);
            if (_isPinchZooming) {
              if (_activeMapPointers.isEmpty) {
                _finishPinchGesture();
              }
              return;
            }
            if (e.pointer != _trackedPointerId) return;
            _handleMapPointerCancel(e);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (_) {},
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      MapLibreMap.useHybridComposition = false;
    }
    GestureBinding.instance.pointerRouter.addGlobalRoute(
      _handleGlobalPointerEvent,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAndroidMapTouchOverlay();
      _bootstrapInitialState();
    });
  }

  @override
  void dispose() {
    _androidMapTouchOverlay?.remove();
    _androidMapTouchOverlay = null;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handleGlobalPointerEvent,
    );
    _searchDebounce?.cancel();
    _routeCancelToken?.cancel('disposed');
    _areaGeocodeCancelToken?.cancel('disposed');
    _searchGeocodeCancelToken?.cancel('disposed');
    _searchController.dispose();
    final ctrl = _mapController;
    if (ctrl != null) {
      ctrl.onFeatureTapped.remove(_onFeatureTapped);
    }
    super.dispose();
  }

  Future<void> _bootstrapInitialState() async {
    final initFilter = widget.initialFilter;
    if (initFilter != null) {
      ref.read(mapFilterProvider.notifier).setFilter(initFilter);
      if (initFilter.q.isNotEmpty) {
        _searchController.text = initFilter.q;
      }
      if (initFilter.hasOrigin) {
        _focusOnCoordinates(
          initFilter.lat!,
          initFilter.lng!,
          zoom: _userFocusZoom,
          updateFilterOrigin: false,
        );
        return;
      }
    }

    // Rule #1: Logged-in customer's default saved address opens immediately.
    if (await _tryFocusCustomerDefaultAddress()) {
      return;
    }

    // Reuse existing Tarak device location state if already granted/cached.
    final existingOrigin = ref.read(listOriginProvider);
    if (existingOrigin != null && existingOrigin.fromDevice) {
      _focusOnCoordinates(
        existingOrigin.lat,
        existingOrigin.lng,
        zoom: _userFocusZoom,
        updateFilterOrigin: true,
      );
      return;
    }

    if (widget.autoLocateOnOpen && !_initialLocateAttempted) {
      _initialLocateAttempted = true;
      await _locateMe(isInitialAutoLocate: true);
    } else {
      widget.onCameraTargetChanged?.call(
        _turkeyCenter.latitude,
        _turkeyCenter.longitude,
        _turkeyZoom,
      );
    }
  }

  Future<bool> _tryFocusCustomerDefaultAddress() async {
    if (widget.isGuest) return false;
    final authState = ref.read(authNotifierProvider);
    if (!authState.isCustomer) return false;

    List<CustomerAddress> addresses;
    try {
      addresses = ref.read(customerAddressesProvider).asData?.value ??
          await ref
              .read(customerAddressesProvider.future)
              .timeout(const Duration(seconds: 10));
    } catch (_) {
      try {
        addresses = await ref
            .refresh(customerAddressesProvider.future)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        return false;
      }
    }
    if (!mounted) return false;

    CustomerAddress? defaultAddr;
    for (final addr in addresses) {
      if (addr.isDefault) {
        defaultAddr = addr;
        break;
      }
    }
    if (defaultAddr == null) return false;

    final addressLabel = [
      defaultAddr.district?.trim(),
      defaultAddr.province?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    if (defaultAddr.latitude != null && defaultAddr.longitude != null) {
      _savedDefaultAddressLocation = LatLng(
        defaultAddr.latitude!,
        defaultAddr.longitude!,
      );
      _savedDefaultAddressLabel =
          addressLabel.isNotEmpty ? addressLabel : (defaultAddr.title ?? 'Kayıtlı adres');
      _focusOnCoordinates(
        defaultAddr.latitude!,
        defaultAddr.longitude!,
        zoom: _userFocusZoom,
        updateFilterOrigin: true,
      );
      return true;
    }

    final province = defaultAddr.province?.trim();
    if (province != null && province.isNotEmpty) {
      final district = defaultAddr.district?.trim();
      if (district != null &&
          district.isNotEmpty &&
          geoKey(district) != 'merkez') {
        final repo = ref.read(mapDirectoryRepositoryProvider);
        final parts = <String>[
          if (defaultAddr.neighborhood != null &&
              defaultAddr.neighborhood!.trim().isNotEmpty)
            defaultAddr.neighborhood!.trim(),
          district,
          province,
        ];
        final detailedQuery = '${parts.join(', ')}, Türkiye';
        var coords = await repo
            .geocodePlace(detailedQuery)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (coords == null && mounted && parts.length > 2) {
          coords = await repo
              .geocodePlace('$district, $province, Türkiye')
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
        }
        if (!mounted) return false;
        if (coords != null) {
          _savedDefaultAddressLocation = LatLng(coords.lat, coords.lng);
          _savedDefaultAddressLabel =
              addressLabel.isNotEmpty ? addressLabel : '$district, $province';
          _focusOnCoordinates(
            coords.lat,
            coords.lng,
            zoom: _userFocusZoom,
            updateFilterOrigin: true,
          );
          return true;
        }
      }

      final center = provinceCenterFor(province);
      if (center != null && mounted) {
        _savedDefaultAddressLocation = LatLng(center.lat, center.lng);
        _savedDefaultAddressLabel =
            addressLabel.isNotEmpty ? addressLabel : province;
        _focusOnCoordinates(
          center.lat,
          center.lng,
          zoom: 12.6,
          updateFilterOrigin: true,
        );
        return true;
      }
    }

    return false;
  }

  void _focusOnCoordinates(
    double lat,
    double lng, {
    double zoom = _userFocusZoom,
    bool updateFilterOrigin = true,
  }) {
    final target = LatLng(lat, lng);
    setState(() {
      _userLocation = target;
      _cameraTarget = target;
      _cameraZoom = zoom;
      _locationStatus = _MapLocationStatus.ready;
      _locationBannerDismissed = true;
    });

    if (updateFilterOrigin) {
      ref.read(mapFilterProvider.notifier).setOrigin(lat: lat, lng: lng);
    }

    widget.onCameraTargetChanged?.call(lat, lng, zoom);

    if (_mapController != null) {
      _suppressNextCameraIdle = true;
      final update = CameraUpdate.newLatLngZoom(target, zoom);
      if (_styleLoaded) {
        unawaited(_mapController!.animateCamera(update));
      } else {
        unawaited(_mapController!.moveCamera(update));
      }
    }
  }

  void _onSearchChanged(String value) {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(mapFilterProvider.notifier).setSearchQuery(value);
      unawaited(_syncSourceWithFeatures());
    });
  }

  Future<void> _submitSearch() async {
    FocusScope.of(context).unfocus();
    _searchDebounce?.cancel();
    _searchGeocodeCancelToken?.cancel('new_search');

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ref.read(mapFilterProvider.notifier).setSearchQuery('');
      await _syncSourceWithFeatures();
      return;
    }

    final current = ref.read(mapFilterProvider);
    final geoService = ref.read(geoServiceProvider);
    final token = CancelToken();
    _searchGeocodeCancelToken = token;

    if (mounted) setState(() => _searchingLocation = true);
    try {
      // 1. Exact Turkish province match (works online and offline via provinces.json + fallback lookup)
      final matchedProvince = await geoService.findProvince(query);
      if (!mounted || token.isCancelled) return;
      final knownCenter = provinceCenterFor(matchedProvince?.name ?? query);
      if (matchedProvince != null || knownCenter != null) {
        final provinceName = matchedProvince?.name ?? query;
        ref.read(mapFilterProvider.notifier).setFilter(
              current.copyWith(
                city: provinceName,
                clearDistrict: true,
                clearNeighborhood: true,
                clearBounds: true,
                clearRadiusKm: true,
                q: '',
              ),
            );
        await _focusCameraOnSelectedRegion(city: provinceName, district: null);
        return;
      }

      // 2. Exact Turkish district match (e.g. "Alanya", "Kadıköy", "Konyaaltı")
      final districtMatch = await geoService.findDistrictMatch(query);
      if (!mounted || token.isCancelled) return;
      if (districtMatch != null) {
        ref.read(mapFilterProvider.notifier).setFilter(
              current.copyWith(
                city: districtMatch.province,
                district: districtMatch.district,
                clearNeighborhood: true,
                clearBounds: true,
                clearRadiusKm: true,
                q: '',
              ),
            );
        await _focusCameraOnSelectedRegion(
          city: districtMatch.province,
          district: districtMatch.district,
        );
        return;
      }

      // 3. Place / neighborhood / street or business/service query
      ref.read(mapFilterProvider.notifier).setFilter(
            current.copyWith(
              q: query,
              clearCity: true,
              clearDistrict: true,
              clearNeighborhood: true,
              clearBounds: true,
              clearRadiusKm: true,
            ),
          );

      final repo = ref.read(mapDirectoryRepositoryProvider);
      final coords = await repo.geocodePlace(
        '$query, Türkiye',
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) return;

      final validTrCoords = coords != null &&
          coords.lat >= 35.5 &&
          coords.lat <= 42.5 &&
          coords.lng >= 25.5 &&
          coords.lng <= 45.5;

      if (validTrCoords) {
        _pendingAreaCameraCity = null;
        _pendingAreaCameraDistrict = null;
        await _moveAndFetchAt(coords.lat, coords.lng, zoom: 13.8);
        if (!mounted || token.isCancelled) return;

        // If `q` didn't match any salon by business/service text, switch to the
        // searched neighborhood's viewport bounds so salons in that area appear.
        try {
          final resp = await ref.read(mapBusinessesProvider.future);
          if (!mounted || token.isCancelled) return;
          if (resp.pins.isEmpty && resp.mobileProviders.isEmpty) {
            final cur = ref.read(mapFilterProvider);
            if (cur.q == query) {
              ref.read(mapFilterProvider.notifier).setFilter(
                    cur.copyWith(
                      q: '',
                      minLat: coords.lat - 0.055,
                      maxLat: coords.lat + 0.055,
                      minLng: coords.lng - 0.07,
                      maxLng: coords.lng + 0.07,
                    ),
                  );
            }
          }
        } catch (_) {}
        return;
      }

      // 4. Fallback: focus camera onto first matching Tarak pin if text matches one
      final qKey = geoKey(query);
      for (final pin in _currentTarakPins) {
        if (pin.latitude == null || pin.longitude == null) continue;
        final hay = geoKey(
          '${pin.businessName} ${pin.city ?? ''} ${pin.district ?? ''} ${pin.neighborhood ?? ''}',
        );
        if (hay.contains(qKey)) {
          await _moveAndFetchAt(pin.latitude!, pin.longitude!, zoom: 14.5);
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    controller.onFeatureTapped.remove(_onFeatureTapped);
    controller.onFeatureTapped.add(_onFeatureTapped);
    _clearAndroidPlatformViewFocus();
    if (_userLocation != null || _cameraTarget != _turkeyCenter) {
      _suppressNextCameraIdle = true;
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(_cameraTarget, _cameraZoom),
      );
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null || !mounted) return;

    _styleLoaded = false;
    _sourceAdded = false;
    _routeSourceAdded = false;

    try {
      final sprites = await _markerRenderer.buildAllSprites();
      if (!mounted) return;
      for (final entry in sprites.entries) {
        await controller.addImage(entry.key, entry.value);
      }
    } catch (_) {
      // Ignore if native surface is torn down during style load.
    }

    if (!mounted) return;
    _suppressNextCameraIdle = true;
    try {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(_cameraTarget, _cameraZoom),
      );
    } catch (_) {}

    if (!mounted) return;
    _styleLoaded = true;

    await _syncSourceWithFeatures();
    if (_activeRoute != null) {
      await _syncRouteLayer();
    }
  }

  Future<void> _syncSourceWithFeatures() async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || !mounted) return;
    if (_syncInFlight) {
      _syncQueued = true;
      return;
    }

    _syncInFlight = true;
    try {
      final latestPins = ref.read(mapBusinessesProvider).asData?.value.pins;
      if (latestPins != null) {
        _currentTarakPins = latestPins;
      }
      final tarakGeoJson = TarakMapScreen.buildTarakGeoJson(
        _currentTarakPins,
        selectedFeatureKey: _currentSelectedFeatureKey,
      );

      if (!_sourceAdded) {
        await controller.addSource(
          _sourceId,
          GeojsonSourceProperties(
            data: tarakGeoJson,
            cluster: true,
            clusterRadius: 42,
            clusterMaxZoom: 13,
            clusterProperties: {
              'barber_count': [
                '+',
                [
                  'case',
                  ['==', ['get', 'category'], 'barber'],
                  1,
                  0,
                ],
              ],
              'coiffeur_count': [
                '+',
                [
                  'case',
                  ['==', ['get', 'category'], 'coiffeur'],
                  1,
                  0,
                ],
              ],
            },
          ),
        );

        // Tarak clusters use official Tarak icon circles with ZERO numbers.
        await controller.addSymbolLayer(
          _sourceId,
          _clusterLayerId,
          const SymbolLayerProperties(
            iconImage: [
              'case',
              [
                'all',
                ['>', ['coalesce', ['get', 'barber_count'], 0], 0],
                ['==', ['coalesce', ['get', 'coiffeur_count'], 0], 0],
              ],
              TarakMarkerRenderer.spriteClusterBarber,
              [
                'all',
                ['>', ['coalesce', ['get', 'coiffeur_count'], 0], 0],
                ['==', ['coalesce', ['get', 'barber_count'], 0], 0],
              ],
              TarakMarkerRenderer.spriteClusterCoiffeur,
              TarakMarkerRenderer.spriteClusterMixed,
            ],
            iconSize: 0.66,
            iconAnchor: 'center',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
          ),
          filter: ['has', 'point_count'],
        );

        // Single unclustered Tarak pins render ABOVE clusters for strict tap priority.
        await controller.addSymbolLayer(
          _sourceId,
          _pinLayerId,
          const SymbolLayerProperties(
            iconImage: ['get', 'icon_id'],
            iconSize: 0.62,
            iconAnchor: 'center',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
          ),
          filter: [
            '!',
            ['has', 'point_count'],
          ],
        );

        _sourceAdded = true;
      } else {
        await controller.setGeoJsonSource(_sourceId, tarakGeoJson);
      }
      _clearAndroidPlatformViewFocus();
      _logVisiblePinScreenCoords();
    } catch (_) {
      // Ignore transient style reload exceptions.
    } finally {
      _syncInFlight = false;
      if (_syncQueued && mounted) {
        _syncQueued = false;
        unawaited(_syncSourceWithFeatures());
      }
    }
  }

  static double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLng = (lng2 - lng1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadiusM * 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
  }

  Future<void> _syncRouteLayer() async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || !mounted) return;
    final routeGeoJson = _activeRoute != null
        ? _activeRoute!.toGeoJsonFeatureCollection()
        : const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <Map<String, dynamic>>[],
          };

    final endpointsGeoJson = _activeRoute != null && _activeRouteOrigin != null
        ? <String, dynamic>{
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'id': 1,
                'geometry': {
                  'type': 'Point',
                  'coordinates': [
                    _activeRouteOrigin!.longitude,
                    _activeRouteOrigin!.latitude,
                  ],
                },
                'properties': {'role': 'origin'},
              },
              {
                'type': 'Feature',
                'id': 2,
                'geometry': {
                  'type': 'Point',
                  'coordinates': [
                    _activeRoute!.destinationLng,
                    _activeRoute!.destinationLat,
                  ],
                },
                'properties': {'role': 'dest'},
              },
            ],
          }
        : const <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <Map<String, dynamic>>[],
          };

    try {
      if (!_routeSourceAdded) {
        if (_activeRoute == null) return;
        await controller.addSource(
          _routeSourceId,
          GeojsonSourceProperties(data: routeGeoJson),
        );
        await controller.addSource(
          _routeEndpointsSourceId,
          GeojsonSourceProperties(data: endpointsGeoJson),
        );
        await controller.addLineLayer(
          _routeSourceId,
          _routeCasingLayerId,
          const LineLayerProperties(
            lineColor: '#FFFFFF',
            lineWidth: 7.0,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
        await controller.addLineLayer(
          _routeSourceId,
          _routeLineLayerId,
          const LineLayerProperties(
            lineColor: '#2563EB',
            lineWidth: 4.5,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
        await controller.addCircleLayer(
          _routeEndpointsSourceId,
          _routeOriginLayerId,
          const CircleLayerProperties(
            circleColor: '#2563EB',
            circleRadius: 7.5,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2.5,
          ),
          filter: [
            '==',
            ['get', 'role'],
            'origin',
          ],
        );
        await controller.addCircleLayer(
          _routeEndpointsSourceId,
          _routeDestLayerId,
          const CircleLayerProperties(
            circleColor: '#FF5722',
            circleRadius: 8.5,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2.5,
          ),
          filter: [
            '==',
            ['get', 'role'],
            'dest',
          ],
        );
        _routeSourceAdded = true;
      } else {
        await controller.setGeoJsonSource(_routeSourceId, routeGeoJson);
        await controller.setGeoJsonSource(
          _routeEndpointsSourceId,
          endpointsGeoJson,
        );
      }
    } catch (_) {}
  }

  Future<LatLng?> _probeLiveDeviceGpsQuietly() async {
    try {
      if (widget.positionFetcher != null) {
        final coords = await widget.positionFetcher!();
        if (coords != null) {
          _deviceGpsLocation = LatLng(coords.lat, coords.lng);
        }
        return _deviceGpsLocation;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {}
      pos ??= await Geolocator.getLastKnownPosition();
      if (pos != null) {
        _deviceGpsLocation = LatLng(pos.latitude, pos.longitude);
      }
      return _deviceGpsLocation;
    } catch (_) {
      return null;
    }
  }

  Future<MapRouteResult> _fetchRouteFromBackend({
    required LatLng origin,
    required double destLat,
    required double destLng,
    required String destLabel,
    required String profile,
    required CancelToken cancelToken,
  }) {
    if (widget.routeFetcher != null) {
      return widget.routeFetcher!(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: destLat,
        destLng: destLng,
        destinationName: destLabel,
        profile: profile,
        cancelToken: cancelToken,
      );
    }
    return ref.read(mapRouteServiceProvider).fetchRoute(
          originLat: origin.latitude,
          originLng: origin.longitude,
          destLat: destLat,
          destLng: destLng,
          destinationName: destLabel,
          profile: profile,
          cancelToken: cancelToken,
        );
  }

  Future<void> _startInAppRoute({
    required double destLat,
    required double destLng,
    required String destLabel,
    String profile = 'driving',
    String? originPreference,
  }) async {
    final mode = originPreference ?? _routeOriginMode;
    if (_activeRoute == null) {
      _preRouteCameraTarget = _cameraTarget;
      _preRouteCameraZoom = _cameraZoom;
    }
    if (_showListView && mounted) {
      setState(() => _showListView = false);
    }

    final filter = ref.read(mapFilterProvider);
    LatLng? origin;
    String originLabel;

    if (mode == 'saved' && _savedDefaultAddressLocation != null) {
      origin = _savedDefaultAddressLocation;
      originLabel = _savedDefaultAddressLabel?.isNotEmpty == true
          ? 'Kayıtlı adres (${_savedDefaultAddressLabel!})'
          : 'Kayıtlı adresiniz';
    } else {
      final liveGps = await _probeLiveDeviceGpsQuietly();
      if (!mounted) return;
      if (liveGps != null) {
        origin = liveGps;
        originLabel = 'Mevcut konumunuz';
      } else if (_savedDefaultAddressLocation != null) {
        origin = _savedDefaultAddressLocation;
        originLabel = _savedDefaultAddressLabel?.isNotEmpty == true
            ? 'Kayıtlı adres (${_savedDefaultAddressLabel!})'
            : 'Kayıtlı adresiniz';
      } else if (_userLocation != null) {
        origin = _userLocation;
        originLabel = 'Harita başlangıç konumu';
      } else if (filter.hasOrigin) {
        origin = LatLng(filter.lat!, filter.lng!);
        originLabel = 'Seçili konum';
      } else {
        originLabel = '';
      }
    }

    if (origin == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Rota çizebilmek için konum veya kayıtlı adres gerekli.',
            ),
            action: SnackBarAction(
              label: 'Dış Harita',
              onPressed: () => _launchDirectionsToCoords(
                latitude: destLat,
                longitude: destLng,
                label: destLabel,
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _routeCancelToken?.cancel('superseded');
    final token = CancelToken();
    _routeCancelToken = token;

    setState(() => _routeLoading = true);

    try {
      MapRouteResult route;
      try {
        route = await _fetchRouteFromBackend(
          origin: origin,
          destLat: destLat,
          destLng: destLng,
          destLabel: destLabel,
          profile: profile,
          cancelToken: token,
        );
      } on MapRouteException catch (e) {
        final canFallbackSaved = mode != 'saved' &&
            _savedDefaultAddressLocation != null &&
            (origin.latitude != _savedDefaultAddressLocation!.latitude ||
                origin.longitude != _savedDefaultAddressLocation!.longitude) &&
            e.isNoRoute;
        if (!canFallbackSaved) rethrow;
        origin = _savedDefaultAddressLocation!;
        originLabel = _savedDefaultAddressLabel?.isNotEmpty == true
            ? 'Kayıtlı adres (${_savedDefaultAddressLabel!})'
            : 'Kayıtlı adresiniz';
        route = await _fetchRouteFromBackend(
          origin: origin,
          destLat: destLat,
          destLng: destLng,
          destLabel: destLabel,
          profile: profile,
          cancelToken: token,
        );
      }
      if (!mounted || token.isCancelled) return;

      setState(() {
        _routeLoading = false;
        _activeRoute = route;
        _routeOriginMode = mode;
        _activeRouteOrigin = origin;
        _activeRouteOriginLabel = originLabel;
        _selectedBusiness = null;
      });

      unawaited(_syncSourceWithFeatures());
      await _syncRouteLayer();

      final controller = _mapController;
      if (controller != null) {
        _suppressNextCameraIdle = true;
        final minLat = min(route.bounds.south, origin.latitude);
        final maxLat = max(route.bounds.north, origin.latitude);
        final minLng = min(route.bounds.west, origin.longitude);
        final maxLng = max(route.bounds.east, origin.longitude);
        final bounds = LatLngBounds(
          southwest: LatLng(min(minLat, destLat), min(minLng, destLng)),
          northeast: LatLng(max(maxLat, destLat), max(maxLng, destLng)),
        );
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 48,
            top: 136,
            right: 48,
            bottom: 64,
          ),
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || !mounted) return;
      setState(() => _routeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yol tarifi servisine şu anda ulaşılamıyor.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on MapRouteException catch (e) {
      if (!mounted || token.isCancelled) return;
      setState(() => _routeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'Dış Haritada Aç',
            onPressed: () => _launchDirectionsToCoords(
              latitude: destLat,
              longitude: destLng,
              label: destLabel,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() => _routeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Yol tarifi servisine şu anda ulaşılamıyor.'),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'Dış Haritada Aç',
            onPressed: () => _launchDirectionsToCoords(
              latitude: destLat,
              longitude: destLng,
              label: destLabel,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearInAppRoute() {
    _routeCancelToken?.cancel('cleared');
    final restoreTarget = _preRouteCameraTarget;
    final restoreZoom = _preRouteCameraZoom;
    setState(() {
      _routeLoading = false;
      _activeRoute = null;
      _activeRouteOrigin = null;
      _activeRouteOriginLabel = '';
      _preRouteCameraTarget = null;
      _preRouteCameraZoom = null;
    });
    unawaited(_syncRouteLayer());
    if (restoreTarget != null && restoreZoom != null) {
      _cameraTarget = restoreTarget;
      _cameraZoom = restoreZoom;
      widget.onCameraTargetChanged?.call(
        restoreTarget.latitude,
        restoreTarget.longitude,
        restoreZoom,
      );
      if (_mapController != null) {
        _suppressNextCameraIdle = true;
        unawaited(
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(restoreTarget, restoreZoom),
          ),
        );
      }
    }
  }

  bool _recentlyHandledTap() {
    final last = _lastTapHandledAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(milliseconds: 180);
  }

  void _markTapHandled() {
    _lastTapHandledAt = DateTime.now();
  }

  Size _currentMapLogicalSize() {
    final ro = _mapViewportKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize && !ro.size.isEmpty) {
      return ro.size;
    }
    final mq = MediaQuery.maybeSizeOf(context);
    if (mq != null && !mq.isEmpty) {
      return Size(mq.width, max(300.0, mq.height - 212.0));
    }
    return const Size(411.4, 678.0);
  }

  LatLng _localOffsetToLatLng(
    Offset localPos, {
    Size? mapSize,
    LatLng? cameraTarget,
    double? cameraZoom,
  }) {
    final size = mapSize ?? _currentMapLogicalSize();
    final target = cameraTarget ?? _cameraTarget;
    final zoom = cameraZoom ?? _cameraZoom;
    final worldPx = 512.0 * pow(2.0, zoom);
    final dx = localPos.dx - (size.width / 2.0);
    final dy = localPos.dy - (size.height / 2.0);
    final lng = (target.longitude + (dx / worldPx) * 360.0).clamp(-180.0, 180.0);
    final centerLatRad = target.latitude.clamp(-85.0511, 85.0511) * pi / 180.0;
    final centerMercY =
        0.5 - log(tan((pi / 4.0) + (centerLatRad / 2.0))) / (2.0 * pi);
    final ptMercY = (centerMercY + (dy / worldPx)).clamp(0.0001, 0.9999);
    final latRad = 2.0 * atan(exp((0.5 - ptMercY) * 2.0 * pi)) - (pi / 2.0);
    final lat = (latRad * 180.0 / pi).clamp(-85.0511, 85.0511);
    return LatLng(lat, lng);
  }

  LatLng _cameraTargetKeepingPointAtLocalOffset(
    LatLng worldPt,
    Offset localPos,
    Size mapSize,
    double zoom,
  ) {
    final worldPx = 512.0 * pow(2.0, zoom);
    final dx = localPos.dx - (mapSize.width / 2.0);
    final dy = localPos.dy - (mapSize.height / 2.0);
    final lng = (worldPt.longitude - (dx / worldPx) * 360.0).clamp(-180.0, 180.0);
    final latRad = worldPt.latitude.clamp(-85.0511, 85.0511) * pi / 180.0;
    final ptMercY = 0.5 - log(tan((pi / 4.0) + (latRad / 2.0))) / (2.0 * pi);
    final targetMercY = (ptMercY - (dy / worldPx)).clamp(0.0001, 0.9999);
    final targetLatRad = 2.0 * atan(exp((0.5 - targetMercY) * 2.0 * pi)) - (pi / 2.0);
    final lat = (targetLatRad * 180.0 / pi).clamp(-85.0, 85.0);
    return LatLng(lat, lng);
  }

  Offset _latLngToLocalOffset(LatLng target, {Size? mapSize}) {
    final size = mapSize ?? _currentMapLogicalSize();
    final worldPx = 512.0 * pow(2.0, _cameraZoom);
    final dx = ((target.longitude - _cameraTarget.longitude) / 360.0) * worldPx;
    final centerLatRad =
        _cameraTarget.latitude.clamp(-85.0511, 85.0511) * pi / 180.0;
    final targetLatRad =
        target.latitude.clamp(-85.0511, 85.0511) * pi / 180.0;
    final centerMercY =
        0.5 - log(tan((pi / 4.0) + (centerLatRad / 2.0))) / (2.0 * pi);
    final targetMercY =
        0.5 - log(tan((pi / 4.0) + (targetLatRad / 2.0))) / (2.0 * pi);
    final dy = (targetMercY - centerMercY) * worldPx;
    return Offset((size.width / 2.0) + dx, (size.height / 2.0) + dy);
  }

  void _logVisiblePinScreenCoords() {
    if (!kDebugMode || !mounted) return;
    final size = _currentMapLogicalSize();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final ro = _mapViewportKey.currentContext?.findRenderObject();
    final mapOriginPx = (ro is RenderBox && ro.hasSize)
        ? ro.localToGlobal(Offset.zero).dy * dpr
        : (212.0 * dpr);
    var loggedTarak = 0;
    for (final b in _currentTarakPins) {
      if (!b.hasPublicPin || b.latitude == null || b.longitude == null) {
        continue;
      }
      final local = _latLngToLocalOffset(
        LatLng(b.latitude!, b.longitude!),
        mapSize: size,
      );
      if (local.dx >= -20 &&
          local.dx <= size.width + 20 &&
          local.dy >= -20 &&
          local.dy <= size.height + 20) {
        final pxX = (local.dx * dpr).round();
        final pxY = ((local.dy * dpr) + mapOriginPx).round();
        debugPrint(
          '[TarakMap] visible Tarak "${b.businessName}" (user=${b.userId}, bookings=${b.acceptsTarakBookings}) screenPx=($pxX, $pxY)',
        );
        if (++loggedTarak >= 6) break;
      }
    }
  }

  void _moveLiveCameraThrottled(LatLng nextTarget, double nextZoom) {
    _cameraTarget = nextTarget;
    _cameraZoom = nextZoom;
    widget.onCameraTargetChanged?.call(
      nextTarget.latitude,
      nextTarget.longitude,
      nextZoom,
    );
    final now = DateTime.now();
    if (_lastLiveCameraMoveAt != null &&
        now.difference(_lastLiveCameraMoveAt!).inMilliseconds < 28) {
      return;
    }
    _lastLiveCameraMoveAt = now;
    final ctrl = _mapController;
    if (ctrl != null) {
      _suppressNextCameraIdle = true;
      unawaited(
        ctrl.moveCamera(CameraUpdate.newLatLngZoom(nextTarget, nextZoom)),
      );
    }
  }

  void _beginPinchGesture() {
    if (_activeMapPointers.length < 2) return;
    final pts = _activeMapPointers.values.toList(growable: false);
    _isPinchZooming = true;
    _trackedPointerId = null;
    _pointerDownLocalPos = null;
    _pointerDownTime = null;
    _pinchStartDist = max(24.0, (pts[0] - pts[1]).distance);
    _pinchStartMid = Offset(
      (pts[0].dx + pts[1].dx) / 2.0,
      (pts[0].dy + pts[1].dy) / 2.0,
    );
    _pinchStartZoom = _cameraZoom;
    _pinchStartTarget = _cameraTarget;
  }

  void _updatePinchGesture() {
    if (!_isPinchZooming || _activeMapPointers.length < 2 || !mounted) return;
    final pts = _activeMapPointers.values.toList(growable: false);
    final curDist = max(12.0, (pts[0] - pts[1]).distance);
    final curMid = Offset(
      (pts[0].dx + pts[1].dx) / 2.0,
      (pts[0].dy + pts[1].dy) / 2.0,
    );
    final scale = (curDist / _pinchStartDist).clamp(0.25, 4.0);
    final nextZoom = (_pinchStartZoom + log(scale) / ln2).clamp(5.0, 18.5);
    final mapSize = _currentMapLogicalSize();
    final anchor = _localOffsetToLatLng(
      _pinchStartMid,
      mapSize: mapSize,
      cameraTarget: _pinchStartTarget,
      cameraZoom: _pinchStartZoom,
    );
    final nextTarget = _cameraTargetKeepingPointAtLocalOffset(
      anchor,
      curMid,
      mapSize,
      nextZoom,
    );
    _moveLiveCameraThrottled(nextTarget, nextZoom);
  }

  void _finishPinchGesture() {
    _isPinchZooming = false;
    if (!mounted) return;
    setState(() => _cameraMovedSinceFetch = true);
    final ctrl = _mapController;
    final finalTarget = _cameraTarget;
    final finalZoom = _cameraZoom;
    Future<void>(() async {
      if (ctrl != null) {
        _suppressNextCameraIdle = true;
        try {
          await ctrl
              .moveCamera(CameraUpdate.newLatLngZoom(finalTarget, finalZoom))
              .timeout(const Duration(milliseconds: 500));
        } catch (_) {}
      }
      if (!mounted) return;
      _logVisiblePinScreenCoords();
    });
  }

  void _updateLiveDragGesture(Offset localPos) {
    if (_pointerDownLocalPos == null) return;
    final dist = (localPos - _pointerDownLocalPos!).distance;
    if (dist > _pointerMaxMoveLogical) {
      _pointerMaxMoveLogical = dist;
    }
    if (_pointerMaxMoveLogical < 8.0) return;

    final mapSize = _currentMapLogicalSize();
    final baseCam = _pointerDownCameraTarget ?? _cameraTarget;
    final downLatLng = _localOffsetToLatLng(
      _pointerDownLocalPos!,
      mapSize: mapSize,
      cameraTarget: baseCam,
      cameraZoom: _pointerDownZoom,
    );
    final curLatLng = _localOffsetToLatLng(
      localPos,
      mapSize: mapSize,
      cameraTarget: baseCam,
      cameraZoom: _pointerDownZoom,
    );
    final nextTarget = LatLng(
      (baseCam.latitude + (downLatLng.latitude - curLatLng.latitude))
          .clamp(-85.0, 85.0),
      (baseCam.longitude + (downLatLng.longitude - curLatLng.longitude))
          .clamp(-180.0, 180.0),
    );
    _moveLiveCameraThrottled(nextTarget, _pointerDownZoom);
  }

  Future<void> _zoomMapTowardLocalPoint(
    Offset localPos, {
    required double deltaZoom,
    bool animate = true,
  }) async {
    if (!mounted) return;
    final mapSize = _currentMapLogicalSize();
    final tapCoords = _localOffsetToLatLng(localPos, mapSize: mapSize);
    final nextZoom = (_cameraZoom + deltaZoom).clamp(5.0, 18.5);
    final nextTarget = deltaZoom > 0 ? tapCoords : _cameraTarget;

    if (kDebugMode) {
      debugPrint(
        '[TarakMap] zoomToward local=$localPos zoom=$nextZoom target=(${nextTarget.latitude}, ${nextTarget.longitude})',
      );
    }

    setState(() {
      _cameraTarget = nextTarget;
      _cameraZoom = nextZoom;
      _cameraMovedSinceFetch = true;
    });
    widget.onCameraTargetChanged?.call(
      nextTarget.latitude,
      nextTarget.longitude,
      nextZoom,
    );

    final ctrl = _mapController;
    if (ctrl != null) {
      _suppressNextCameraIdle = true;
      final update = CameraUpdate.newLatLngZoom(nextTarget, nextZoom);
      try {
        if (animate) {
          await ctrl.animateCamera(update).timeout(const Duration(milliseconds: 600));
        } else {
          await ctrl.moveCamera(update).timeout(const Duration(milliseconds: 500));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    _logVisiblePinScreenCoords();
  }

  void _handleMapPointerSignal(PointerSignalEvent event, double mapOriginY) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      final box = _mapViewportKey.currentContext?.findRenderObject();
      final local = (box is RenderBox && box.hasSize)
          ? box.globalToLocal(event.position)
          : Offset(event.position.dx, event.position.dy - mapOriginY);
      unawaited(
        _zoomMapTowardLocalPoint(
          local,
          deltaZoom: event.scrollDelta.dy < 0 ? 0.85 : -0.85,
          animate: false,
        ),
      );
    }
  }

  void _startMapPointerTracking({
    required int pointer,
    required Offset localPos,
    required Offset globalPos,
    required String source,
  }) {
    if (_trackedPointerId == pointer) return;
    _trackedPointerId = pointer;
    _pointerDownLocalPos = localPos;
    _pointerDownTime = DateTime.now();
    _pointerMaxMoveLogical = 0.0;
    _pointerDownCameraTarget = _cameraTarget;
    _pointerDownZoom = _cameraZoom;
    if (kDebugMode) {
      debugPrint(
        '[TarakMap] pointerDown($source) local=$localPos global=$globalPos',
      );
    }
  }

  void _handleMapPointerDown(PointerDownEvent e) {
    if (_lastOverlayPointerId == e.pointer) return;
    _startMapPointerTracking(
      pointer: e.pointer,
      localPos: e.localPosition,
      globalPos: e.position,
      source: 'listener',
    );
  }

  void _handleMapPointerMove(PointerMoveEvent e) {
    if (e.pointer != _trackedPointerId || _pointerDownLocalPos == null) return;
    _updateLiveDragGesture(e.localPosition);
  }

  void _handleMapPointerCancel(PointerCancelEvent e) {
    if (kDebugMode) {
      debugPrint('[TarakMap] pointerCancel local=${e.localPosition}');
    }
    _trackedPointerId = null;
    _pointerDownLocalPos = null;
    _pointerDownTime = null;
    _pointerMaxMoveLogical = 0.0;
    _pointerDownCameraTarget = null;
  }

  void _handleMapPointerUp(PointerUpEvent e) {
    if (e.pointer != _trackedPointerId) return;
    _finishMapPointerTracking(e.localPosition);
  }

  void _handleGlobalPointerEvent(PointerEvent event) {
    if (!mounted ||
        _showListView ||
        _selectedSheetExpanded ||
        (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            _androidMapTouchOverlay != null) ||
        widget.mapBuilder != null) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }
    if (event is PointerDownEvent) {
      if (_lastOverlayPointerId == event.pointer ||
          _trackedPointerId == event.pointer) {
        return;
      }
      final ro = _mapViewportKey.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize || ro.size.isEmpty) return;
      final local = ro.globalToLocal(event.position);
      if (local.dx < 0 ||
          local.dy < 0 ||
          local.dx > ro.size.width ||
          local.dy > ro.size.height) {
        return;
      }
      _startMapPointerTracking(
        pointer: event.pointer,
        localPos: local,
        globalPos: event.position,
        source: 'globalRoute',
      );
    } else if (event is PointerMoveEvent) {
      if (event.pointer != _trackedPointerId || _pointerDownLocalPos == null) {
        return;
      }
      final ro = _mapViewportKey.currentContext?.findRenderObject();
      final local = (ro is RenderBox && ro.hasSize)
          ? ro.globalToLocal(event.position)
          : event.localPosition;
      _updateLiveDragGesture(local);
    } else if (event is PointerUpEvent) {
      if (event.pointer != _trackedPointerId) return;
      final ro = _mapViewportKey.currentContext?.findRenderObject();
      final local = (ro is RenderBox && ro.hasSize)
          ? ro.globalToLocal(event.position)
          : event.localPosition;
      _finishMapPointerTracking(local);
    } else if (event is PointerCancelEvent) {
      if (event.pointer != _trackedPointerId) return;
      _handleMapPointerCancel(event);
    }
  }

  void _finishMapPointerTracking(Offset upPos) {
    if (_pointerDownLocalPos == null || _pointerDownTime == null) {
      return;
    }
    final downPos = _pointerDownLocalPos!;
    final elapsedMs =
        DateTime.now().difference(_pointerDownTime!).inMilliseconds;
    final maxMove = max(_pointerMaxMoveLogical, (upPos - downPos).distance);
    final downCam = _pointerDownCameraTarget;
    final downZoom = _pointerDownZoom;

    _trackedPointerId = null;
    _pointerDownLocalPos = null;
    _pointerDownTime = null;
    _pointerMaxMoveLogical = 0.0;
    _pointerDownCameraTarget = null;

    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final mapSize = _currentMapLogicalSize();
    if (kDebugMode) {
      debugPrint(
        '[TarakMap] pointerUp local=$upPos maxMove=${maxMove.toStringAsFixed(1)} elapsed=${elapsedMs}ms styleLoaded=$_styleLoaded',
      );
    }

    // 1. Tap & Double-Tap handling (works both natively and inside Android VirtualDisplay).
    if (maxMove < 22.0 && elapsedMs < 700) {
      final now = DateTime.now();
      if (_lastEmptyMapTapAt != null &&
          now.difference(_lastEmptyMapTapAt!).inMilliseconds <= 380 &&
          _lastEmptyMapTapLocalPos != null &&
          (upPos - _lastEmptyMapTapLocalPos!).distance <= 52.0) {
        _lastEmptyMapTapAt = null;
        _lastEmptyMapTapLocalPos = null;
        _markTapHandled();
        unawaited(_zoomMapTowardLocalPoint(upPos, deltaZoom: 1.6));
        return;
      }

      final baseCam = downCam ?? _cameraTarget;
      final fallbackLatLng = _localOffsetToLatLng(
        upPos,
        mapSize: mapSize,
        cameraTarget: baseCam,
        cameraZoom: downZoom,
      );
      final physPt = Point<double>(upPos.dx * dpr, upPos.dy * dpr);

      Future<void> dispatchSingleTap() async {
        if (!mounted || _recentlyHandledTap()) return;
        final hit = await _onMapClickAtPoint(
          physPt,
          fallbackLatLng,
          localOffset: upPos,
        );
        if (!mounted) return;
        if (hit) {
          _lastEmptyMapTapAt = null;
          _lastEmptyMapTapLocalPos = null;
        } else {
          _lastEmptyMapTapAt = DateTime.now();
          _lastEmptyMapTapLocalPos = upPos;
        }
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        unawaited(dispatchSingleTap());
      } else {
        Future<void>.delayed(const Duration(milliseconds: 55), dispatchSingleTap);
      }
      return;
    }

    // 2. Single-finger pan/swipe commit (no upper timeout so deliberate slow drags always commit).
    if (maxMove >= 22.0) {
      final baseCam = downCam ?? _cameraTarget;
      final downLatLng = _localOffsetToLatLng(
        downPos,
        mapSize: mapSize,
        cameraTarget: baseCam,
        cameraZoom: downZoom,
      );
      final upLatLng = _localOffsetToLatLng(
        upPos,
        mapSize: mapSize,
        cameraTarget: baseCam,
        cameraZoom: downZoom,
      );
      final dLat = downLatLng.latitude - upLatLng.latitude;
      final dLng = downLatLng.longitude - upLatLng.longitude;
      final nextTarget = LatLng(
        (baseCam.latitude + dLat).clamp(-85.0, 85.0),
        (baseCam.longitude + dLng).clamp(-180.0, 180.0),
      );
      _lastEmptyMapTapAt = null;
      _lastEmptyMapTapLocalPos = null;
      setState(() {
        _cameraTarget = nextTarget;
        _cameraMovedSinceFetch = true;
      });
      widget.onCameraTargetChanged?.call(
        nextTarget.latitude,
        nextTarget.longitude,
        downZoom,
      );
      Future<void>(() async {
        final ctrl = _mapController;
        if (ctrl != null) {
          _suppressNextCameraIdle = true;
          try {
            await ctrl
                .moveCamera(CameraUpdate.newLatLngZoom(nextTarget, downZoom))
                .timeout(const Duration(milliseconds: 600));
          } catch (_) {}
        }
        if (!mounted) return;
        _logVisiblePinScreenCoords();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _queryFeaturesWithTolerance(
    MapLibreMapController controller,
    Point<double> point,
    List<String> layerIds,
  ) async {
    final hitRadius = mounted
        ? (24.0 * MediaQuery.devicePixelRatioOf(context)).clamp(36.0, 72.0)
        : 48.0;
    final rect = Rect.fromCircle(
      center: Offset(point.x, point.y),
      radius: hitRadius,
    );
    List raw = const [];
    try {
      raw = await controller
          .queryRenderedFeaturesInRect(rect, layerIds, null)
          .timeout(const Duration(milliseconds: 160));
    } catch (_) {
      raw = const [];
    }
    if (raw.isEmpty) {
      try {
        raw = await controller
            .queryRenderedFeatures(point, layerIds, null)
            .timeout(const Duration(milliseconds: 160));
      } catch (_) {
        raw = const [];
      }
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Map<String, dynamic>? _closestRenderedFeature(
    List<Map<String, dynamic>> features,
    LatLng tapCoords,
  ) {
    if (features.isEmpty) return null;
    if (features.length == 1) return features.first;
    Map<String, dynamic> best = features.first;
    var bestDist = double.infinity;
    for (final feat in features) {
      final geom = feat['geometry'];
      if (geom is Map && geom['coordinates'] is List) {
        final coords = geom['coordinates'] as List;
        if (coords.length >= 2 && coords[0] is num && coords[1] is num) {
          final d = _distanceMeters(
            tapCoords.latitude,
            tapCoords.longitude,
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
          if (d < bestDist) {
            bestDist = d;
            best = feat;
          }
        }
      }
    }
    return best;
  }

  void _selectFeatureAtCoords({
    String? userId,
    String? profileId,
    required LatLng fallbackCoords,
  }) {
    double targetLat = fallbackCoords.latitude;
    double targetLng = fallbackCoords.longitude;
    MapBusinessSummary? primaryBusiness;

    if (userId != null && userId.isNotEmpty) {
      // Strictly match Tarak user_id (never mix provider_profiles.id with user_id).
      for (final b in _currentTarakPins) {
        if (b.userId == userId) {
          primaryBusiness = b;
          if (b.latitude != null && b.longitude != null) {
            targetLat = b.latitude!;
            targetLng = b.longitude!;
          }
          break;
        }
      }
    } else if (profileId != null && profileId.isNotEmpty) {
      for (final b in _currentTarakPins) {
        if (b.id == profileId) {
          primaryBusiness = b;
          if (b.latitude != null && b.longitude != null) {
            targetLat = b.latitude!;
            targetLng = b.longitude!;
          }
          break;
        }
      }
    }

    if (primaryBusiness == null) {
      return;
    }

    final nearbyTarak = <MapBusinessSummary>[
      for (final b in _currentTarakPins)
        if (b.hasPublicPin &&
            b.latitude != null &&
            b.longitude != null &&
            _distanceMeters(targetLat, targetLng, b.latitude!, b.longitude!) <=
                25.0)
          b,
    ];

    if (nearbyTarak.length > 1 && mounted) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusSheet),
        builder: (_) => CoLocatedBusinessesSheet(
          tarakPins: nearbyTarak,
          onSelectBusiness: (b) => _selectBusiness(b, animateCamera: true),
        ),
      );
      return;
    }

    if (mounted) {
      _selectBusiness(primaryBusiness, animateCamera: true);
    }
  }

  Future<bool> _handleClusterExpansion(
    MapLibreMapController controller,
    LatLng coordinates, {
    Map<String, dynamic>? clusterFeat,
  }) async {
    final currentZoom = controller.cameraPosition?.zoom ?? _cameraZoom;
    final props = clusterFeat?['properties'];
    final clusterId =
        props is Map ? (props['cluster_id'] as num?)?.toInt() : null;

    int? expZoom;
    if (clusterId != null) {
      try {
        expZoom = await controller.getClusterExpansionZoom(_sourceId, clusterId);
      } catch (_) {}
    }

    final double targetZoom = max(
      currentZoom + 2.2,
      (expZoom != null && expZoom > 0) ? (expZoom + 0.8) : (currentZoom + 2.2),
    ).clamp(8.0, 17.5);

    // If zoomed deeply and identical coords still cluster together, open picker sheet.
    if (currentZoom >= 16.2) {
      final nearbyTarak = [
        for (final b in _currentTarakPins)
          if (b.hasPublicPin &&
              b.latitude != null &&
              b.longitude != null &&
              _distanceMeters(
                    coordinates.latitude,
                    coordinates.longitude,
                    b.latitude!,
                    b.longitude!,
                  ) <=
                  45.0)
            b,
      ];
      if (nearbyTarak.length > 1 && mounted) {
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: AppTheme.radiusSheet,
            ),
            builder: (_) => CoLocatedBusinessesSheet(
              tarakPins: nearbyTarak,
              onSelectBusiness: (b) => _selectBusiness(b, animateCamera: true),
            ),
          ),
        );
        return true;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[TarakMap] Cluster tap zoom $currentZoom -> $targetZoom at (${coordinates.latitude}, ${coordinates.longitude})',
      );
    }
    if (mounted) {
      setState(() {
        _cameraTarget = coordinates;
        _cameraZoom = targetZoom;
      });
    }
    _suppressNextCameraIdle = true;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(coordinates, targetZoom),
    );
    return true;
  }

  bool _selectNearestWithinThreshold(
    LatLng coordinates, {
    required double zoom,
  }) {
    final metersPerPx =
        156543.03392 * cos(coordinates.latitude * pi / 180.0) / pow(2.0, zoom);
    final thresholdM = (32.0 * metersPerPx).clamp(25.0, 320.0);

    MapBusinessSummary? nearestTarak;
    var minTarakDist = thresholdM;
    for (final b in _currentTarakPins) {
      if (!b.hasPublicPin || b.latitude == null || b.longitude == null) {
        continue;
      }
      final d = _distanceMeters(
        coordinates.latitude,
        coordinates.longitude,
        b.latitude!,
        b.longitude!,
      );
      if (d <= minTarakDist) {
        minTarakDist = d;
        nearestTarak = b;
      }
    }

    if (nearestTarak != null) {
      _markTapHandled();
      _selectFeatureAtCoords(
        userId: nearestTarak.userId,
        profileId: nearestTarak.id,
        fallbackCoords: coordinates,
      );
      return true;
    }
    return false;
  }

  Future<bool> _selectByScreenProjection(
    Offset localOffset,
    LatLng tapCoords,
    double currentZoom,
  ) async {
    final mapSize = _currentMapLogicalSize();
    final tarakCandidates = <({MapBusinessSummary pin, Offset screen, double dist})>[];
    for (final b in _currentTarakPins) {
      if (!b.hasPublicPin || b.latitude == null || b.longitude == null) {
        continue;
      }
      final pos = _latLngToLocalOffset(
        LatLng(b.latitude!, b.longitude!),
        mapSize: mapSize,
      );
      final d = (pos - localOffset).distance;
      if (d <= 64.0) {
        tarakCandidates.add((pin: b, screen: pos, dist: d));
      }
    }
    tarakCandidates.sort((a, b) => a.dist.compareTo(b.dist));

    // At zoom <= 13.0, MapLibre clusters nearby Tarak pins (clusterMaxZoom: 13, clusterRadius: 42).
    if (currentZoom <= 13.0 && tarakCandidates.isNotEmpty) {
      final lead = tarakCandidates.first;
      final clusterMembers = <MapBusinessSummary>[];
      for (final b in _currentTarakPins) {
        if (!b.hasPublicPin || b.latitude == null || b.longitude == null) {
          continue;
        }
        final pos = _latLngToLocalOffset(
          LatLng(b.latitude!, b.longitude!),
          mapSize: mapSize,
        );
        if ((pos - lead.screen).distance <= 52.0) {
          clusterMembers.add(b);
        }
      }
      if (clusterMembers.length > 1 && _mapController != null) {
        var sumLat = 0.0;
        var sumLng = 0.0;
        for (final m in clusterMembers) {
          sumLat += m.latitude!;
          sumLng += m.longitude!;
        }
        final center = LatLng(
          sumLat / clusterMembers.length,
          sumLng / clusterMembers.length,
        );
        _markTapHandled();
        await _handleClusterExpansion(_mapController!, center);
        return true;
      }
    }

    if (tarakCandidates.isNotEmpty && tarakCandidates.first.dist <= 48.0) {
      final hit = tarakCandidates.first.pin;
      _markTapHandled();
      _selectFeatureAtCoords(
        userId: hit.userId,
        profileId: hit.id,
        fallbackCoords: tapCoords,
      );
      return true;
    }

    return false;
  }

  Future<bool> _onMapClickAtPoint(
    Point<double> point,
    LatLng coordinates, {
    Offset? localOffset,
  }) async {
    if (_recentlyHandledTap()) return false;
    final controller = _mapController;
    final currentZoom = _cameraZoom;
    final dpr = mounted ? MediaQuery.devicePixelRatioOf(context) : 2.625;
    final effectiveLocal =
        localOffset ?? Offset(point.x / dpr, point.y / dpr);

    if (kDebugMode) {
      debugPrint(
        '[TarakMap] onMapClick local=$effectiveLocal pt=(${point.x}, ${point.y}) coords=(${coordinates.latitude}, ${coordinates.longitude}) zoom=$currentZoom',
      );
    }

    try {
      // 1. Direct screen-projection & geographic hit-test (instant & 100% reliable on Android VirtualDisplay).
      if (await _selectByScreenProjection(
        effectiveLocal,
        coordinates,
        currentZoom,
      )) {
        return true;
      }

      if (controller != null &&
          (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
        // 2. Single unclustered Tarak pins take strict priority over clusters.
        final pinFeats = await _queryFeaturesWithTolerance(
          controller,
          point,
          [_pinLayerId],
        );
        final bestPin = _closestRenderedFeature(pinFeats, coordinates);
        if (bestPin != null) {
          final props = bestPin['properties'];
          if (props is Map) {
            _markTapHandled();
            _selectFeatureAtCoords(
              userId: props['user_id']?.toString(),
              profileId: props['profile_id']?.toString(),
              fallbackCoords: coordinates,
            );
            return true;
          }
        }

        // 3. Cluster tap zooms to split individual Tarak pins cleanly.
        final clusterFeats = await _queryFeaturesWithTolerance(
          controller,
          point,
          [_clusterLayerId],
        );
        final bestCluster = _closestRenderedFeature(clusterFeats, coordinates);
        if (bestCluster != null &&
            await _handleClusterExpansion(
              controller,
              coordinates,
              clusterFeat: bestCluster,
            )) {
          _markTapHandled();
          return true;
        }
      }

      // 4. Geographic proximity fallback if rendered symbol rects missed.
      if (currentZoom >= 10.0 &&
          _selectNearestWithinThreshold(coordinates, zoom: currentZoom)) {
        return true;
      }
    } catch (_) {}

    if (_selectedBusiness != null && mounted) {
      setState(() {
        _selectedBusiness = null;
      });
      unawaited(_syncSourceWithFeatures());
    }
    return false;
  }

  Future<void> _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) async {
    if (_recentlyHandledTap()) return;
    final controller = _mapController;
    if (controller == null) return;

    final currentZoom = controller.cameraPosition?.zoom ?? _cameraZoom;
    if (kDebugMode) {
      debugPrint(
        '[TarakMap] onFeatureTapped layer=$layerId id=$id pt=(${point.x}, ${point.y}) coords=(${coordinates.latitude}, ${coordinates.longitude})',
      );
    }

    try {
      // 1. Single unclustered Tarak pins take priority over everything.
      final pinFeats = await _queryFeaturesWithTolerance(
        controller,
        point,
        [_pinLayerId],
      );
      final bestPin = _closestRenderedFeature(pinFeats, coordinates);
      if (bestPin != null) {
        final props = bestPin['properties'];
        if (props is Map) {
          _markTapHandled();
          _selectFeatureAtCoords(
            userId: props['user_id']?.toString(),
            profileId: props['profile_id']?.toString(),
            fallbackCoords: coordinates,
          );
          return;
        }
      }

      // 2. Cluster symbol tap: zoom cleanly even if queryRenderedFeaturesInRect was empty.
      if (layerId == _clusterLayerId) {
        final clusterFeats = await _queryFeaturesWithTolerance(
          controller,
          point,
          [_clusterLayerId],
        );
        final bestCluster = _closestRenderedFeature(clusterFeats, coordinates);
        if (await _handleClusterExpansion(
          controller,
          coordinates,
          clusterFeat: bestCluster,
        )) {
          _markTapHandled();
        }
        return;
      }

      // 3. Single Tarak pin layer fallback by numeric GeoJSON feature ID or proximity.
      if (layerId == _pinLayerId) {
        final numeric = int.tryParse(id);
        if (numeric != null && numeric > 0 && numeric < 10000000) {
          _markTapHandled();
          _selectFeatureAtCoords(
            userId: '$numeric',
            fallbackCoords: coordinates,
          );
          return;
        }
        if (_selectNearestWithinThreshold(
          coordinates,
          zoom: currentZoom,
        )) {
          return;
        }
      }

      final numeric = int.tryParse(id);
      if (numeric != null && numeric > 0 && numeric < 10000000) {
        _markTapHandled();
        _selectFeatureAtCoords(
          userId: '$numeric',
          fallbackCoords: coordinates,
        );
      }
    } catch (_) {}
  }

  void _selectBusiness(MapBusinessSummary b, {bool animateCamera = false}) {
    setState(() {
      _selectedBusiness = b;
      _selectedSheetExpanded = false;
    });
    if (animateCamera &&
        b.hasPublicPin &&
        b.latitude != null &&
        b.longitude != null) {
      final target = LatLng(b.latitude!, b.longitude!);
      final nextZoom = max(_cameraZoom, 14.5);
      _cameraTarget = target;
      _cameraZoom = nextZoom;
      widget.onCameraTargetChanged?.call(
        target.latitude,
        target.longitude,
        nextZoom,
      );
      _suppressNextCameraIdle = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, nextZoom),
      );
    }
    unawaited(_syncSourceWithFeatures());
  }

  Future<void> _locateMe({bool isInitialAutoLocate = false}) async {
    if (_locatingUser) return;
    setState(() {
      _locatingUser = true;
      _locationStatus = _MapLocationStatus.locating;
    });

    try {
      if (widget.positionFetcher != null) {
        final coords = await widget.positionFetcher!();
        if (!mounted) return;
        if (coords == null) {
          _handleLocationFailure(
            _MapLocationStatus.denied,
            showSnack: !isInitialAutoLocate,
          );
        } else {
          _deviceGpsLocation = LatLng(coords.lat, coords.lng);
          _focusOnCoordinates(coords.lat, coords.lng, zoom: _userFocusZoom);
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _handleLocationFailure(
          _MapLocationStatus.unavailable,
          showSnack: !isInitialAutoLocate,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _handleLocationFailure(
          _MapLocationStatus.denied,
          showSnack: !isInitialAutoLocate,
        );
        return;
      }

      Position? pos;
      Object? gpsError;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 7),
          ),
        );
      } catch (e) {
        gpsError = e;
      }

      if (pos == null) {
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (!mounted) return;
      if (pos != null) {
        _deviceGpsLocation = LatLng(pos.latitude, pos.longitude);
        _focusOnCoordinates(pos.latitude, pos.longitude, zoom: _userFocusZoom);
        return;
      }

      _handleLocationFailure(
        gpsError is TimeoutException
            ? _MapLocationStatus.timeout
            : _MapLocationStatus.unavailable,
        showSnack: !isInitialAutoLocate,
      );
    } on TimeoutException {
      if (mounted) {
        _handleLocationFailure(
          _MapLocationStatus.timeout,
          showSnack: !isInitialAutoLocate,
        );
      }
    } catch (_) {
      if (mounted) {
        _handleLocationFailure(
          _MapLocationStatus.unavailable,
          showSnack: !isInitialAutoLocate,
        );
      }
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  void _handleLocationFailure(
    _MapLocationStatus status, {
    required bool showSnack,
  }) {
    setState(() {
      _locationStatus = status;
      _locationBannerDismissed = false;
      if (_userLocation == null) {
        _cameraTarget = _turkeyCenter;
        _cameraZoom = _turkeyZoom;
      }
    });

    if (_userLocation == null) {
      widget.onCameraTargetChanged?.call(
        _turkeyCenter.latitude,
        _turkeyCenter.longitude,
        _turkeyZoom,
      );
    }

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == _MapLocationStatus.timeout
                ? 'Konum zaman aşımına uğradı. Türkiye görünümü açıldı.'
                : 'Konum izni verilmedi. İl ve ilçe filtresiyle arama yapabilirsiniz.',
          ),
          action: SnackBarAction(
            label: 'İl / İlçe Seç',
            onPressed: _openAreaAndRadiusSheet,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onMapCameraIdle() async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || !mounted) return;

    final cam = controller.cameraPosition;
    if (cam != null) {
      _cameraTarget = cam.target;
      _cameraZoom = cam.zoom;
    }

    if (_suppressNextCameraIdle) {
      _suppressNextCameraIdle = false;
    } else if (_sourceAdded && !_cameraMovedSinceFetch) {
      setState(() => _cameraMovedSinceFetch = true);
    }
  }

  Future<void> _searchVisibleArea() async {
    final controller = _mapController;
    if (controller == null) return;
    setState(() => _cameraMovedSinceFetch = false);
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      final south = min(bounds.southwest.latitude, bounds.northeast.latitude);
      final north = max(bounds.southwest.latitude, bounds.northeast.latitude);
      final west = min(bounds.southwest.longitude, bounds.northeast.longitude);
      final east = max(bounds.southwest.longitude, bounds.northeast.longitude);

      final filter = ref.read(mapFilterProvider);
      ref.read(mapFilterProvider.notifier).setFilter(
            filter.copyWith(
              minLat: south,
              maxLat: north,
              minLng: west,
              maxLng: east,
            ),
          );
    } catch (_) {}
  }

  Future<void> _openAreaAndRadiusSheet() async {
    final filter = ref.read(mapFilterProvider);
    final geoService = ref.read(geoServiceProvider);
    List<GeoProvince> provinces = const [];
    try {
      provinces = await geoService.getProvinces();
    } catch (_) {
      provinces = const [];
    }
    if (!mounted) return;

    GeoProvince? pickedProvince;
    if (filter.city != null && filter.city!.isNotEmpty) {
      for (final p in provinces) {
        if (geoKey(p.name) == geoKey(filter.city!)) {
          pickedProvince = p;
          break;
        }
      }
    }

    String? selectedCity = pickedProvince?.name ?? filter.city;
    String? selectedDistrict = filter.district;
    int? selectedRadius = filter.radiusKm;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusSheet),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentProvince = provinces.where(
            (p) =>
                selectedCity != null && geoKey(p.name) == geoKey(selectedCity!),
          );
          final districts = currentProvince.isNotEmpty
              ? currentProvince.first.districts
              : const <GeoDistrict>[];

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Konum & Mesafe Filtresi',
                        style: AppTheme.headingMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          selectedCity = null;
                          selectedDistrict = null;
                          selectedRadius = null;
                        });
                      },
                      child: const Text('Sıfırla'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: const Key('map_city_dropdown'),
                  initialValue: provinces.any((p) => p.name == selectedCity)
                      ? selectedCity
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'İl',
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tüm İller'),
                    ),
                    ...provinces.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p.name,
                        child: Text(p.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setSheetState(() {
                      selectedCity = value;
                      selectedDistrict = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: const Key('map_district_dropdown'),
                  initialValue:
                      districts.any((d) => d.name == selectedDistrict)
                          ? selectedDistrict
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tüm İlçeler'),
                    ),
                    ...districts.map(
                      (d) => DropdownMenuItem<String?>(
                        value: d.name,
                        child: Text(d.name),
                      ),
                    ),
                  ],
                  onChanged: selectedCity == null
                      ? null
                      : (value) =>
                          setSheetState(() => selectedDistrict = value),
                ),
                if (filter.hasOrigin) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Konumuma Göre Maksimum Mesafe',
                    style: AppTheme.headingSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [null, 5, 10, 15, 25, 50].map((km) {
                      final active = selectedRadius == km;
                      return ChoiceChip(
                        label: Text(km == null ? 'Tümü' : '$km km'),
                        selected: active,
                        onSelected: (_) =>
                            setSheetState(() => selectedRadius = km),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('apply_area_filter_btn'),
                  onPressed: () {
                    final hasExplicitArea = selectedCity != null;
                    ref.read(mapFilterProvider.notifier).setFilter(
                          filter.copyWith(
                            city: selectedCity,
                            clearCity: selectedCity == null,
                            district: selectedDistrict,
                            clearDistrict: selectedDistrict == null,
                            clearNeighborhood: true,
                            radiusKm: hasExplicitArea ? null : selectedRadius,
                            clearRadiusKm:
                                hasExplicitArea || selectedRadius == null,
                            clearBounds: true,
                          ),
                        );
                    Navigator.pop(ctx);
                    unawaited(
                      _focusCameraOnSelectedRegion(
                        city: selectedCity,
                        district: selectedDistrict,
                      ),
                    );
                  },
                  child: const Text('Filtreyi Uygula'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _moveAndFetchAt(
    double lat,
    double lng, {
    required double zoom,
  }) async {
    final target = LatLng(lat, lng);
    setState(() {
      _cameraTarget = target;
      _cameraZoom = zoom;
      _cameraMovedSinceFetch = false;
    });
    widget.onCameraTargetChanged?.call(lat, lng, zoom);

    final controller = _mapController;
    if (controller != null) {
      _suppressNextCameraIdle = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(target, zoom),
        );
      } catch (_) {}
    }
  }

  Future<void> _focusCameraOnSelectedRegion({
    required String? city,
    required String? district,
  }) async {
    _areaGeocodeCancelToken?.cancel('new_region');
    _pendingAreaCameraCity = city;
    _pendingAreaCameraDistrict = district;

    if (city == null || city.trim().isEmpty) {
      _pendingAreaCameraCity = null;
      _pendingAreaCameraDistrict = null;
      final target = _userLocation ?? _turkeyCenter;
      final zoom = _userLocation != null ? _userFocusZoom : _turkeyZoom;
      await _moveAndFetchAt(target.latitude, target.longitude, zoom: zoom);
      return;
    }

    unawaited(_syncSourceWithFeatures());

    final hasDistrict = district != null && district.trim().isNotEmpty;
    final isProvinceCenterDistrict =
        hasDistrict && geoKey(district) == 'merkez';
    final provinceCenter = provinceCenterFor(city);

    if (hasDistrict && !isProvinceCenterDistrict) {
      final token = CancelToken();
      _areaGeocodeCancelToken = token;
      final ownsSpinner = !_searchingLocation;
      if (ownsSpinner && mounted) setState(() => _searchingLocation = true);
      ({double lat, double lng})? coords;
      try {
        final repo = ref.read(mapDirectoryRepositoryProvider);
        coords = await repo.geocodePlace(
          '${district.trim()}, ${city.trim()}, Türkiye',
          cancelToken: token,
        );
        if (coords == null && !token.isCancelled && mounted) {
          coords = await repo.geocodePlace(
            '${district.trim()}, Türkiye',
            cancelToken: token,
          );
        }
      } finally {
        if (ownsSpinner && mounted && _areaGeocodeCancelToken == token) {
          setState(() => _searchingLocation = false);
        }
      }
      if (!mounted || token.isCancelled) return;
      final currentFilter = ref.read(mapFilterProvider);
      if (currentFilter.city == null ||
          geoKey(currentFilter.city!) != geoKey(city)) {
        return;
      }
      if (currentFilter.district == null ||
          geoKey(currentFilter.district!) != geoKey(district)) {
        return;
      }

      if (coords != null) {
        _pendingAreaCameraCity = null;
        _pendingAreaCameraDistrict = null;
        await _moveAndFetchAt(coords.lat, coords.lng, zoom: 13.4);
        return;
      }

      if (provinceCenter != null) {
        _pendingAreaCameraDistrict = null;
        await _moveAndFetchAt(
          provinceCenter.lat,
          provinceCenter.lng,
          zoom: 12.4,
        );
      }
      return;
    }

    _pendingAreaCameraDistrict = null;
    if (provinceCenter != null) {
      await _moveAndFetchAt(
        provinceCenter.lat,
        provinceCenter.lng,
        zoom: isProvinceCenterDistrict ? 13.0 : 12.0,
      );
    }
  }

  void _openMobileProvidersSheet(List<MapBusinessSummary> providers) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusSheet),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.home_repair_service_outlined,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adrese Gelen ${providers.length} Uzman',
                          style: AppTheme.headingMedium,
                        ),
                        const Text(
                          'Gizlilik gereği gezici uzmanların konumları haritada pin olarak gösterilmez.',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: providers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = providers[index];
                  return _BusinessListTileCard(
                    business: item,
                    onTap: () {
                      Navigator.pop(ctx);
                      _selectBusiness(item, animateCamera: item.hasPublicPin);
                    },
                    onDirections: null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDirectionsToCoords({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    final ok = await DirectionsLauncher.openDirections(
      latitude: latitude,
      longitude: longitude,
      label: label,
      launcher: widget.directionsLauncher,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harita uygulaması açılamadı.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDirectBooking(MapBusinessSummary business, {int? staffId}) {
    if (widget.isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final userId = int.tryParse(business.userId);
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAppointmentScreen(
          initialProviderUserId: userId,
          initialStaffId: staffId,
        ),
      ),
    );
  }

  void _openInstantCall() {
    if (widget.isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(mapFilterProvider);
    final businessesAsync = ref.watch(mapBusinessesProvider);

    ref.listen<AsyncValue<MapBusinessesResponse>>(
      mapBusinessesProvider,
      (_, next) {
        next.whenData((resp) {
          _currentTarakPins = resp.pins;
          if (_selectedBusiness != null &&
              !resp.pins.any((p) => p.userId == _selectedBusiness!.userId)) {
            setState(() => _selectedBusiness = null);
          }
          _syncSourceWithFeatures();

          final pendingCity = _pendingAreaCameraCity;
          if (pendingCity != null &&
              _pendingAreaCameraDistrict == null &&
              resp.pins.isNotEmpty) {
            _pendingAreaCameraCity = null;
            final withCoords = resp.pins
                .where((p) => p.latitude != null && p.longitude != null)
                .toList();
            if (withCoords.isNotEmpty) {
              final avgLat = withCoords
                      .map((p) => p.latitude!)
                      .reduce((a, b) => a + b) /
                  withCoords.length;
              final avgLng = withCoords
                      .map((p) => p.longitude!)
                      .reduce((a, b) => a + b) /
                  withCoords.length;
              unawaited(
                _moveAndFetchAt(
                  avgLat,
                  avgLng,
                  zoom: ref.read(mapFilterProvider).district != null
                      ? 13.0
                      : 12.2,
                ),
              );
            }
          }
        });
      },
    );

    final pins =
        businessesAsync.asData?.value.pins ?? _currentTarakPins;
    final mobileProviders =
        businessesAsync.asData?.value.mobileProviders ??
            const <MapBusinessSummary>[];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tarak Harita'),
        actions: [
          Semantics(
            button: true,
            label:
                _showListView ? 'Harita görünümüne geç' : 'Liste görünümüne geç',
            child: TextButton.icon(
              key: const Key('map_toggle_view_button'),
              onPressed: () => setState(() => _showListView = !_showListView),
              icon: Icon(
                _showListView ? Icons.map_rounded : Icons.view_list_rounded,
                size: 18,
              ),
              label: Text(_showListView ? 'Harita' : 'Liste'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search + Quick Filter Strip (design strictly preserved)
          Material(
            color: Colors.white,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('map_search_field'),
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => unawaited(_submitSearch()),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText:
                                'Şehir, ilçe, berber veya kuaför ara...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: (_searchController.text.isNotEmpty ||
                                    filter.q.isNotEmpty)
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      ref
                                          .read(mapFilterProvider.notifier)
                                          .setSearchQuery('');
                                      unawaited(_syncSourceWithFeatures());
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        button: true,
                        label: 'Ara',
                        child: InkWell(
                          key: const Key('map_search_submit_btn'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _searchingLocation
                              ? null
                              : () => unawaited(_submitSearch()),
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AppTheme.darkNavy,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _searchingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        button: true,
                        label: 'Konumumu kullan',
                        child: InkWell(
                          key: const Key('map_locate_me_button'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _locatingUser
                              ? null
                              : () {
                                  if (filter.city != null ||
                                      filter.district != null ||
                                      filter.hasBounds) {
                                    ref.read(mapFilterProvider.notifier).setFilter(
                                          filter.copyWith(
                                            clearCity: true,
                                            clearDistrict: true,
                                            clearNeighborhood: true,
                                            clearBounds: true,
                                            clearRadiusKm: true,
                                          ),
                                        );
                                  }
                                  _locateMe();
                                },
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: filter.hasOrigin
                                  ? AppTheme.primary
                                  : AppTheme.slate100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: filter.hasOrigin
                                    ? AppTheme.primary
                                    : AppTheme.slate200,
                              ),
                            ),
                            child: _locatingUser
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.my_location_rounded,
                                    size: 20,
                                    color: filter.hasOrigin
                                        ? Colors.white
                                        : AppTheme.slate800,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GroupedDropdownPill(
                          key: const Key('map_area_filter_chip'),
                          icon: Icons.location_on_outlined,
                          label: filter.district ?? filter.city ?? 'İl / İlçe',
                          selected:
                              filter.city != null || filter.radiusKm != null,
                          onTap: _openAreaAndRadiusSheet,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: PopupMenuButton<String>(
                          key: const Key('map_category_filter_dropdown'),
                          position: PopupMenuPosition.under,
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (value) {
                            ref.read(mapFilterProvider.notifier).setFilter(
                                  filter.copyWith(
                                    type: value == 'all' ? null : value,
                                    clearType: value == 'all',
                                  ),
                                );
                            unawaited(_syncSourceWithFeatures());
                          },
                          itemBuilder: (ctx) => [
                            _buildDropdownMenuItem(
                              value: 'all',
                              label: 'Tüm Kategoriler',
                              selected: filter.type == null,
                            ),
                            _buildDropdownMenuItem(
                              itemKey: const Key('map_filter_barber_chip'),
                              value: 'barber',
                              label: 'Erkek Berber',
                              selected: filter.type == 'barber',
                            ),
                            _buildDropdownMenuItem(
                              itemKey: const Key('map_filter_coiffeur_chip'),
                              value: 'coiffeur',
                              label: 'Kadın Kuaför',
                              selected: filter.type == 'coiffeur',
                            ),
                          ],
                          child: _GroupedDropdownPill(
                            label: filter.type == 'barber'
                                ? 'Erkek Berber'
                                : (filter.type == 'coiffeur'
                                    ? 'Kadın Kuaför'
                                    : 'Kategori'),
                            selected: filter.type != null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: PopupMenuButton<String>(
                          key: const Key('map_service_filter_dropdown'),
                          position: PopupMenuPosition.under,
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (value) {
                            if (value == 'mode_all') {
                              ref.read(mapFilterProvider.notifier).setFilter(
                                    filter.copyWith(clearWorkMode: true),
                                  );
                            } else if (value == 'mode_venue') {
                              ref.read(mapFilterProvider.notifier).setFilter(
                                    filter.copyWith(
                                      workMode: 'venue',
                                      clearWorkMode:
                                          filter.workMode == 'venue',
                                    ),
                                  );
                            } else if (value == 'mode_mobile') {
                              ref.read(mapFilterProvider.notifier).setFilter(
                                    filter.copyWith(
                                      workMode: 'mobile',
                                      clearWorkMode:
                                          filter.workMode == 'mobile',
                                    ),
                                  );
                            } else if (value == 'toggle_booking') {
                              ref.read(mapFilterProvider.notifier).setFilter(
                                    filter.copyWith(
                                      bookingOnly: !filter.bookingOnly,
                                    ),
                                  );
                            }
                            unawaited(_syncSourceWithFeatures());
                          },
                          itemBuilder: (ctx) => [
                            _buildDropdownMenuItem(
                              value: 'mode_all',
                              label: 'Tüm Hizmet Şekilleri',
                              selected: filter.workMode == null,
                            ),
                            _buildDropdownMenuItem(
                              itemKey: const Key('map_filter_venue_chip'),
                              value: 'mode_venue',
                              label: 'İşletmede',
                              selected: filter.workMode == 'venue',
                            ),
                            _buildDropdownMenuItem(
                              itemKey: const Key('map_filter_mobile_chip'),
                              value: 'mode_mobile',
                              label: 'Eve / Adrese Servis',
                              selected: filter.workMode == 'mobile',
                            ),
                            const PopupMenuDivider(),
                            _buildDropdownMenuItem(
                              itemKey: const Key('map_filter_booking_chip'),
                              value: 'toggle_booking',
                              label: 'Tarak Randevulu',
                              selected: filter.bookingOnly,
                            ),
                          ],
                          child: _GroupedDropdownPill(
                            label: _serviceFilterSummary(filter),
                            selected:
                                filter.workMode != null || filter.bookingOnly,
                          ),
                        ),
                      ),
                      if (filter.hasActiveFilters) ...[
                        const SizedBox(width: 6),
                        Semantics(
                          button: true,
                          label: 'Filtreleri temizle',
                          child: InkWell(
                            key: const Key('map_clear_filters_chip'),
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              _searchController.clear();
                              ref.read(mapFilterProvider.notifier).clearAll();
                              unawaited(_syncSourceWithFeatures());
                            },
                            child: Container(
                              height: 32,
                              width: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.slate100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.slate200),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppTheme.slate700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Body: Map or Accessible List View
          Expanded(
            child: _showListView
                ? _buildListBody(
                    businessesAsync,
                    pins,
                    mobileProviders,
                  )
                : _buildMapBody(
                    businessesAsync,
                    pins,
                    mobileProviders,
                  ),
          ),
          if (!_showListView && _activeRoute != null) _buildActiveRouteBar(),
        ],
      ),
    );
  }

  Widget _buildMapBody(
    AsyncValue<MapBusinessesResponse> businessesAsync,
    List<MapBusinessSummary> pins,
    List<MapBusinessSummary> mobileProviders,
  ) {
    final styleUrl =
        businessesAsync.asData?.value.mapStyleUrl ?? _defaultStyleUrl;
    final hasBottomCard = _selectedBusiness != null;

    final showLocationBanner = !_locationBannerDismissed &&
        (_locationStatus == _MapLocationStatus.denied ||
            _locationStatus == _MapLocationStatus.timeout ||
            _locationStatus == _MapLocationStatus.unavailable);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncAndroidMapTouchOverlay();
      }
    });

    return Stack(
      children: [
        if (widget.mapBuilder != null)
          widget.mapBuilder!(
            context,
            pins,
            _selectedBusiness,
            (b) => _selectBusiness(b),
          )
        else ...[
          SizedBox.expand(
            key: _mapViewportKey,
            child: ExcludeFocus(
              excluding:
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
              child: ExcludeSemantics(
                excluding:
                    !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
                child: IgnorePointer(
                  ignoring:
                      !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
                  child: MapLibreMap(
                    styleString: styleUrl,
                    initialCameraPosition: CameraPosition(
                      target: _cameraTarget,
                      zoom: _cameraZoom,
                    ),
                    trackCameraPosition: true,
                    dragEnabled: false,
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    onCameraIdle: _onMapCameraIdle,
                    onMapClick: _onMapClickAtPoint,
                    featureTapsTriggersMapClick: true,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        EagerGestureRecognizer.new,
                      ),
                    },
                    myLocationEnabled: _deviceGpsLocation != null &&
                        (!kIsWeb && (Platform.isAndroid || Platform.isIOS)),
                    rotateGesturesEnabled: false,
                    compassEnabled: true,
                  ),
                ),
              ),
            ),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handleMapPointerDown,
                onPointerMove: _handleMapPointerMove,
                onPointerUp: _handleMapPointerUp,
                onPointerCancel: _handleMapPointerCancel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
        ],

        // Top Layer Status & Isolated Error Bars (tiles stay open!)
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _lastOverlayPointerId = e.pointer,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              if (businessesAsync.isLoading || _routeLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _routeLoading
                                  ? 'Kara yolu rotası hesaplanıyor...'
                                  : 'Tarak işletmeleri yükleniyor...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Isolated Tarak Layer Error
              if (businessesAsync.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _IsolatedLayerErrorBanner(
                    key: const Key('tarak_layer_error_banner'),
                    message: 'Tarak işletmeleri yüklenemedi',
                    retryKey: const Key('retry_tarak_layer_btn'),
                    onRetry: () => ref.invalidate(mapBusinessesProvider),
                  ),
                ),

              // Isolated Location Status Notice
              if (showLocationBanner)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    key: const Key('location_layer_error_banner'),
                    elevation: 2,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_searching_rounded,
                            size: 16,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Konum alınamadı',
                              style: AppTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            key: const Key('location_fallback_area_btn'),
                            onPressed: _openAreaAndRadiusSheet,
                            child: const Text('İl / İlçe Seç'),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () => setState(
                              () => _locationBannerDismissed = true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (widget.mapBuilder == null &&
                  _cameraMovedSinceFetch &&
                  !businessesAsync.isLoading)
                Center(
                  child: ElevatedButton.icon(
                    key: const Key('map_search_this_area_btn'),
                    onPressed: _searchVisibleArea,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkNavy,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Bu Alanda Ara',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
            ),
          ),
        ),

        // Mobile-only providers floating privacy-safe pill
        if (mobileProviders.isNotEmpty)
          Positioned(
            left: 14,
            bottom: hasBottomCard ? 204 : 18,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _lastOverlayPointerId = e.pointer,
              child: ElevatedButton.icon(
                key: const Key('mobile_providers_pill'),
                onPressed: () => _openMobileProvidersSheet(mobileProviders),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkNavy,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.home_repair_service_outlined, size: 16),
                label: Text(
                  'Adrese gelen ${mobileProviders.length} uzman',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        // Calm empty-results indicator
        if (!businessesAsync.isLoading &&
            !businessesAsync.hasError &&
            pins.isEmpty &&
            mobileProviders.isEmpty &&
            _activeRoute == null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Center(
              child: Material(
                key: const Key('map_empty_results_banner'),
                elevation: 3,
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Bu bölgede uygun işletme bulunamadı',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),

        // Selected Tarak Business Expandable Original Profile Sheet
        if (_selectedBusiness != null)
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _lastOverlayPointerId = e.pointer,
            child: TarakBusinessDetailSheet(
              key: const Key('tarak_map_preview_card'),
              business: _selectedBusiness!,
              isGuest: widget.isGuest,
              uriLauncher: widget.directionsLauncher,
              onOpenShowcase: () {
                setState(() => _selectedSheetExpanded = true);
              },
              onExpansionChanged: (expanded) {
                if (_selectedSheetExpanded != expanded && mounted) {
                  setState(() => _selectedSheetExpanded = expanded);
                }
              },
              onClose: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                setState(() {
                  _selectedBusiness = null;
                  _selectedSheetExpanded = false;
                });
                unawaited(_syncSourceWithFeatures());
              },
              onInAppDirections: _selectedBusiness!.canGetDirections &&
                      _selectedBusiness!.latitude != null &&
                      _selectedBusiness!.longitude != null
                  ? () => _startInAppRoute(
                        destLat: _selectedBusiness!.latitude!,
                        destLng: _selectedBusiness!.longitude!,
                        destLabel: _selectedBusiness!.businessName,
                      )
                  : null,
              onDirectBooking: _selectedBusiness!.acceptsTarakBookings
                  ? () => _openDirectBooking(_selectedBusiness!)
                  : null,
              onInstantCall: _selectedBusiness!.acceptsTarakBookings
                  ? _openInstantCall
                  : null,
              onSelectStaff: _selectedBusiness!.acceptsTarakBookings
                  ? (staff) => _openDirectBooking(
                        _selectedBusiness!,
                        staffId: staff.id,
                      )
                  : null,
            ),
          ),
      ],
    );
  }

  /// Docked bottom summary panel for the active in-app road route.
  /// Kept outside [_buildMapBody]'s Stack so it sits reliably below the
  /// Android MapLibre surface without z-order or touch-overlay conflicts.
  Widget _buildActiveRouteBar() {
    final route = _activeRoute!;
    return Material(
      key: const Key('map_active_route_bar'),
      elevation: 8,
      color: Colors.white,
      shadowColor: const Color(0x240F172A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      route.profile == 'walking'
                          ? Icons.directions_walk_rounded
                          : Icons.directions_car_rounded,
                      color: TarakMarkerRenderer.barberColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.destinationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headingSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${route.formattedDistance} • ${route.formattedDuration}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TarakMarkerRenderer.barberColor,
                          ),
                        ),
                        if (_activeRouteOriginLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Başlangıç: $_activeRouteOriginLabel',
                            key: const Key('map_route_origin_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Harici Haritada Aç',
                    onPressed: () => _launchDirectionsToCoords(
                      latitude: route.destinationLat,
                      longitude: route.destinationLng,
                      label: route.destinationName,
                    ),
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (_savedDefaultAddressLocation != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      key: const Key('map_route_origin_gps_chip'),
                      label: const Text('Mevcut Konum'),
                      selected: _routeOriginMode != 'saved',
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => _startInAppRoute(
                        destLat: route.destinationLat,
                        destLng: route.destinationLng,
                        destLabel: route.destinationName,
                        profile: route.profile,
                        originPreference: 'gps',
                      ),
                    ),
                    ChoiceChip(
                      key: const Key('map_route_origin_saved_chip'),
                      label: const Text('Kayıtlı Adres'),
                      selected: _routeOriginMode == 'saved',
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => _startInAppRoute(
                        destLat: route.destinationLat,
                        destLng: route.destinationLng,
                        destLabel: route.destinationName,
                        profile: route.profile,
                        originPreference: 'saved',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Araç'),
                          selected: route.profile != 'walking',
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) => _startInAppRoute(
                            destLat: route.destinationLat,
                            destLng: route.destinationLng,
                            destLabel: route.destinationName,
                            profile: 'driving',
                            originPreference: _routeOriginMode,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Yürüyüş'),
                          selected: route.profile == 'walking',
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (_) => _startInAppRoute(
                            destLat: route.destinationLat,
                            destLng: route.destinationLng,
                            destLabel: route.destinationName,
                            profile: 'walking',
                            originPreference: _routeOriginMode,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('map_close_route_btn'),
                    onPressed: _clearInAppRoute,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Rotayı Kapat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListBody(
    AsyncValue<MapBusinessesResponse> businessesAsync,
    List<MapBusinessSummary> pins,
    List<MapBusinessSummary> mobileProviders,
  ) {
    if (businessesAsync.isLoading &&
        pins.isEmpty &&
        mobileProviders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (businessesAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _IsolatedLayerErrorBanner(
              message: 'Tarak işletmeleri yüklenemedi',
              retryKey: const Key('retry_tarak_list_btn'),
              onRetry: () => ref.invalidate(mapBusinessesProvider),
            ),
          ),
        if (!businessesAsync.hasError &&
            pins.isEmpty &&
            mobileProviders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu bölgede uygun işletme bulunamadı',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium,
            ),
          ),
        if (pins.isNotEmpty) ...[
          Text(
            'Tarak İşletmeleri (${pins.length})',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 10),
          for (final b in pins.take(150)) ...[
            _BusinessListTileCard(
              business: b,
              onTap: () {
                setState(() => _showListView = false);
                _selectBusiness(b, animateCamera: b.hasPublicPin);
              },
              onDirections: b.canGetDirections &&
                      b.latitude != null &&
                      b.longitude != null
                  ? () => _startInAppRoute(
                        destLat: b.latitude!,
                        destLng: b.longitude!,
                        destLabel: b.businessName,
                      )
                  : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (mobileProviders.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Adrese Gelen Uzmanlar (${mobileProviders.length})',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Gezici hizmet verenlerin açık adresi gizli tutulur.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final b in mobileProviders) ...[
            _BusinessListTileCard(
              business: b,
              onTap: () {
                setState(() => _showListView = false);
                _selectBusiness(b, animateCamera: false);
              },
              onDirections: null,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _IsolatedLayerErrorBanner extends StatelessWidget {
  final String message;
  final Key retryKey;
  final VoidCallback onRetry;

  const _IsolatedLayerErrorBanner({
    super.key,
    required this.message,
    required this.retryKey,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: AppTheme.errorLight,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.error,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              key: retryKey,
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedDropdownPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _GroupedDropdownPill({
    super.key,
    this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: selected ? AppTheme.darkNavy : AppTheme.slate100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppTheme.darkNavy : AppTheme.slate200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AppTheme.slate700,
            ),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.slate800,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: selected ? Colors.white : AppTheme.slate600,
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: child,
    );
  }
}

String _serviceFilterSummary(MapBusinessFilter filter) {
  if (filter.workMode == 'venue' && filter.bookingOnly) {
    return 'İşletme • Randevu';
  }
  if (filter.workMode == 'mobile' && filter.bookingOnly) {
    return 'Eve • Randevu';
  }
  if (filter.workMode == 'venue') return 'İşletmede';
  if (filter.workMode == 'mobile') return 'Eve Servis';
  if (filter.bookingOnly) return 'Randevulu';
  return 'Hizmet Şekli';
}

PopupMenuItem<String> _buildDropdownMenuItem({
  Key? itemKey,
  required String value,
  required String label,
  required bool selected,
}) {
  return PopupMenuItem<String>(
    key: itemKey,
    value: value,
    height: 40,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
        ),
        if (selected)
          const Icon(
            Icons.check_rounded,
            size: 17,
            color: AppTheme.primary,
          ),
      ],
    ),
  );
}


class _BusinessListTileCard extends StatelessWidget {
  final MapBusinessSummary business;
  final VoidCallback onTap;
  final VoidCallback? onDirections;

  const _BusinessListTileCard({
    required this.business,
    required this.onTap,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = business.displayImageUrl;
    final categoryColor = business.providerType == 'coiffeur'
        ? TarakMarkerRenderer.coiffeurColor
        : TarakMarkerRenderer.barberColor;

    return Material(
      color: Colors.white,
      borderRadius: AppTheme.radiusCard,
      child: InkWell(
        borderRadius: AppTheme.radiusCard,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppTheme.radiusCard,
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    border: Border.all(color: categoryColor, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: TarakMark(size: 24),
                          ),
                        )
                      : const Center(
                          child: TarakMark(size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            business.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headingSmall,
                          ),
                        ),
                        if (business.isVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedTick(size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (business.reviewCount > 0 && business.rating != null)
                          Flexible(
                            child: TarakRatingLabel(
                              value: business.rating!,
                              count: business.reviewCount,
                              size: 11.5,
                              style: AppTheme.caption,
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              '${business.typeLabel} • ${business.workModeLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.caption,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      business.publicLocationSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onDirections != null)
                IconButton(
                  tooltip: 'Yol Tarifi Al',
                  onPressed: onDirections,
                  icon: const Icon(
                    Icons.directions_rounded,
                    color: AppTheme.primary,
                  ),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
            ],
          ),
        ),
      ),
    );
  }
}
