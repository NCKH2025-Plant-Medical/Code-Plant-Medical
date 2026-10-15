// lib/controllers/map_notifier.dart
//
// ChangeNotifier quản lý toàn bộ state màn hình bản đồ.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:thunghiem1/core/cluster/cluster.dart';
import 'package:thunghiem1/core/cluster/cluster_manager.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';
import 'package:thunghiem1/services/map_api_service.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

enum MapPermissionState { unknown, granted, denied, deniedForever }

enum MapLoadState { idle, loading, loaded, error }

// ── Constants ────────────────────────────────────────────────────────────────

const _kDefaultLatLng = LatLng(21.0285, 105.8542);
const _kDefaultZoom = 12.0;

// ─────────────────────────────────────────────────────────────────────────────

class MapNotifier extends ChangeNotifier {
  final MapApiService _api;

  MapNotifier({MapApiService? api}) : _api = api ?? MapApiService();

  // ── State ─────────────────────────────────────────────────────────────────

  MapPermissionState permissionState = MapPermissionState.unknown;
  MapLoadState loadState = MapLoadState.idle;

  CameraPosition initialCamera = const CameraPosition(
    target: _kDefaultLatLng,
    zoom: _kDefaultZoom,
  );

  Set<Marker> markers = {};
  String? partialError;
  bool showLocationBanner = false;
  bool isOffline = false;

  // ── Pre-loaded Icons ──────────────────────────────────────────────────────

  BitmapDescriptor? _systemIcon;
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _clusterIcon;

  // ── ClusterManager ────────────────────────────────────────────────────────

  MapClusterManager<PlantMapMarker>? _clusterManager;
  GoogleMapController? _mapController;

  // ── Debounce ──────────────────────────────────────────────────────────────

  Timer? _debounceTimer;
  static const _kDebounceMs = 500;

  LatLngBounds? _currentBounds;
  List<PlantMapMarker> _cachedItems = [];

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _preloadMarkerIcons();
    await _requestLocationPermission();
  }

  // ── Pre-load Icons (phải gọi ở initState, KHÔNG trong build) ─────────────

  Future<void> _preloadMarkerIcons() async {
    if (_systemIcon != null) return;
    _systemIcon = await _buildMarkerIcon(
      color: const Color(0xFF1565C0),
      label: 'S',
    );
    _userIcon = await _buildMarkerIcon(
      color: const Color(0xFFE65100),
      label: 'U',
    );
    _clusterIcon = await _buildClusterIcon(color: const Color(0xFF37474F));
  }

  Future<BitmapDescriptor> _buildMarkerIcon(
      {required Color color, required String label}) async {
    const sz = 96.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    canvas.drawCircle(const Offset(sz / 2, sz * 0.42), sz * 0.38,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4));
    canvas.drawCircle(const Offset(sz / 2, sz * 0.38), sz * 0.36,
        Paint()..color = color);
    canvas.drawPath(
        Path()
          ..moveTo(sz / 2 - sz * 0.14, sz * 0.70)
          ..lineTo(sz / 2, sz * 0.93)
          ..lineTo(sz / 2 + sz * 0.14, sz * 0.70)
          ..close(),
        Paint()..color = color);
    canvas.drawCircle(const Offset(sz / 2, sz * 0.38), sz * 0.20,
        Paint()..color = Colors.white);

    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
              color: color,
              fontSize: sz * 0.22,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(sz / 2 - tp.width / 2, sz * 0.38 - tp.height / 2));

    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _buildClusterIcon({required Color color}) async {
    const sz = 80.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawCircle(
        const Offset(sz / 2, sz / 2), sz / 2, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(sz / 2, sz / 2), sz / 2 - 3, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
          text: '•••',
          style: TextStyle(
              color: Colors.white,
              fontSize: sz * 0.28,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(sz / 2 - tp.width / 2, sz / 2 - tp.height / 2));
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handlePermissionDenied();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _handlePermissionDenied(
            forever: perm == LocationPermission.deniedForever);
        return;
      }
      permissionState = MapPermissionState.granted;
      showLocationBanner = false;
      notifyListeners();
      await _focusCurrentLocation();
    } catch (_) {
      _handlePermissionDenied();
    }
  }

  void _handlePermissionDenied({bool forever = false}) {
    permissionState =
        forever ? MapPermissionState.deniedForever : MapPermissionState.denied;
    showLocationBanner = true;
    notifyListeners();
  }

  Future<void> _focusCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final target = LatLng(position.latitude, position.longitude);
      initialCamera = CameraPosition(target: target, zoom: 15.0);
      await _mapController
          ?.animateCamera(CameraUpdate.newCameraPosition(initialCamera));
      notifyListeners();
    } catch (_) {}
  }

  // ── Map Lifecycle ─────────────────────────────────────────────────────────

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    _clusterManager = MapClusterManager<PlantMapMarker>(
      _cachedItems,
      _updateMarkers,
      markerBuilder: _buildClusterMarker,
    );
    _clusterManager!.setMapController(controller);
  }

  // ── Camera Events (Debounce 500ms) ────────────────────────────────────────

  void onCameraIdle() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: _kDebounceMs),
      _fetchMarkersForCurrentBounds,
    );
  }

  void onCameraMoveStarted() => _debounceTimer?.cancel();

  // ── Fetch API ─────────────────────────────────────────────────────────────

  Future<void> _fetchMarkersForCurrentBounds() async {
    if (_mapController == null || _clusterManager == null) return;

    try {
      _currentBounds = await _mapController!.getVisibleRegion();
    } catch (_) {
      return;
    }
    if (_currentBounds == null) return;

    // Connectivity check
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasNetwork =
        connectivityResult.any((c) => c != ConnectivityResult.none);

    if (!hasNetwork) {
      isOffline = true;
      if (_cachedItems.isNotEmpty) _clusterManager!.setItems(_cachedItems);
      notifyListeners();
      return;
    }

    isOffline = false;
    loadState = MapLoadState.loading;
    partialError = null;
    notifyListeners();

    try {
      final result = await _api.fetchMarkersInBounds(
        minLat: _currentBounds!.southwest.latitude,
        maxLat: _currentBounds!.northeast.latitude,
        minLng: _currentBounds!.southwest.longitude,
        maxLng: _currentBounds!.northeast.longitude,
      );
      _cachedItems = result.markers;
      partialError = result.partialErrorMessage;
      loadState = MapLoadState.loaded;
      _clusterManager!.setItems(result.markers);
    } catch (e) {
      loadState = MapLoadState.error;
      partialError = 'Không thể tải dữ liệu bản đồ';
    }

    notifyListeners();
  }

  // ── Cluster Marker Builder ────────────────────────────────────────────────

  Future<Marker> _buildClusterMarker(
      PlantCluster<PlantMapMarker> cluster) async {
    final icon = cluster.isMultiple
        ? (_clusterIcon ?? BitmapDescriptor.defaultMarker)
        : _iconForSource(cluster.items.first.source);

    return Marker(
      markerId: MarkerId(cluster.getId()),
      position: cluster.location,
      icon: icon,
      infoWindow: cluster.isMultiple
          ? InfoWindow(title: '${cluster.count} cây')
          : InfoWindow(
              title: cluster.items.first.name,
              snippet: cluster.items.first.source == PlantSource.system
                  ? 'Cây hệ thống'
                  : 'Cây cá nhân',
            ),
    );
  }

  BitmapDescriptor _iconForSource(PlantSource source) =>
      source == PlantSource.system
          ? (_systemIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue))
          : (_userIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange));

  void _updateMarkers(Set<Marker> updated) {
    markers = updated;
    notifyListeners();
  }

  // ── Public Actions ────────────────────────────────────────────────────────

  Future<void> retry() => _fetchMarkersForCurrentBounds();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
