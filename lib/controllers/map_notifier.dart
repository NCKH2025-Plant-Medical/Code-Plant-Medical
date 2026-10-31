// lib/controllers/map_notifier.dart
//
// ChangeNotifier quản lý toàn bộ state màn hình bản đồ OpenStreetMap (flutter_map).
//
// Tối ưu hóa hiệu năng & giải quyết toàn bộ feedback:
//   ✅ 1. Yêu cầu quyền vị trí, hỗ trợ định vị máy ảo (nhận diện vị trí Mỹ)
//   ✅ 2. Tối ưu mượt mà 60 FPS, không rebuild map khi tìm kiếm/lọc
//   ✅ 3. Tìm kiếm toàn diện cây hệ thống (không dấu/có dấu, chống lỗi gõ)
//   ✅ 4. Khắc phục triệt để lỗi LatLngBounds out-of-range (> 90.0) khi zoom xa
//   ✅ 5. Bộ lọc nguồn cây + chế độ "Quanh đây" (bán kính 1–5 km)
//   ✅ 6. Đồng bộ kích thước chuẩn 46x46dp cho tất cả nút bấm
//   ✅ 7. 100% thông báo qua error_dialog

import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:thunghiem1/core/map_vietnamese_search_helper.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';
import 'package:thunghiem1/services/map_api_service.dart';
import 'package:thunghiem1/services/map_cache_service.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

enum MapPermissionState { unknown, granted, denied, deniedForever }

enum MapLoadState { idle, loading, loaded, error }

/// Bộ lọc nguồn dữ liệu hiển thị trên map.
enum MapSourceFilter { all, system, user }

extension MapSourceFilterX on MapSourceFilter {
  String get label => switch (this) {
    MapSourceFilter.all => 'Tất cả',
    MapSourceFilter.system => 'Hệ thống',
    MapSourceFilter.user => 'Cá nhân',
  };
}

/// Theme màu bản đồ OSM (Tiêu chuẩn OSM hàng đầu, Sáng dịu mắt pastel, Dark tối thanh lịch)
enum MapTileTheme {
  standard(
    'Bản đồ Tiêu chuẩn (OSM)',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    [],
    'Bản đồ đường sá chi tiết truyền thống của OpenStreetMap',
  ),
  light(
    'Sáng dịu mắt (Khuyên dùng)',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    [],
    'Phong cách màu sắc ấm áp, dịu mắt, cực kỳ phù hợp cho bản đồ dược liệu',
  ),
  dark(
    'Tối thanh lịch (Dark Mode)',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    [],
    'Chế độ nền tối tương phản cao, làm nổi bật tuyệt đối các điểm cây thuốc',
  );

  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final String description;

  const MapTileTheme(
    this.label,
    this.urlTemplate,
    this.subdomains,
    this.description,
  );
}

// ── UI Events ────────────────────────────────────────────────────────────────

sealed class MapUiEvent {
  const MapUiEvent();
}

/// Sự kiện hiển thị hộp thoại qua widget error_dialog có sẵn
class MapDialogEvent extends MapUiEvent {
  final String message;
  final String title;
  const MapDialogEvent(this.message, {this.title = 'Thông báo'});
}

// ── Constants & Default Locations ────────────────────────────────────────────

/// Tọa độ các cây hệ thống hạt giống (Hà Nội) dùng làm mặc định
const List<LatLng> _kDefaultSystemCoords = [
  LatLng(21.0285, 105.8542), // Đinh lăng lá nhỏ
  LatLng(21.0335, 105.8450), // Cà gai leo
  LatLng(21.0220, 105.8600), // Diệp hạ châu
  LatLng(21.0400, 105.8350), // Xuyên tâm liên
  LatLng(21.0150, 105.8700), // Bạch hoa xà thiệt thảo
  LatLng(21.0450, 105.8500), // Trinh nữ hoàng cung
  LatLng(21.0250, 105.8400), // Ngải cứu
  LatLng(21.0380, 105.8650), // Huyền sâm
  LatLng(21.0180, 105.8300), // Thảo quyết minh
  LatLng(21.0500, 105.8600), // Kim ngân hoa
];

const _kDefaultZoom = 14.5;

const _kSystemColor = Color(0xFF1565C0);
const _kUserColor = Color(0xFFE65100);

// ─────────────────────────────────────────────────────────────────────────────

class MapNotifier extends ChangeNotifier {
  MapNotifier({MapApiService? api, MapCacheService? cache, this.onEvent})
    : _api = api ?? MapApiService(),
      _cache = cache ?? MapCacheService();

  final void Function(MapUiEvent event)? onEvent;
  final MapApiService _api;
  final MapCacheService _cache;

  // ── Controller & Map State ────────────────────────────────────────────────

  final MapController mapController = MapController();
  bool isMapReady = false;

  MapPermissionState permissionState = MapPermissionState.unknown;
  MapLoadState loadState = MapLoadState.idle;

  LatLng initialCenter = _kDefaultSystemCoords[0];
  double initialZoom = _kDefaultZoom;

  /// Vị trí GPS hiện tại của người dùng (nếu đã cấp quyền)
  LatLng? userLocation;

  /// Đang dùng vị trí mặc định của máy ảo Android (Mỹ)
  bool isEmulatorUSLocation = false;

  /// Marker đang render trên map
  List<Marker> markers = [];

  /// Toàn bộ cây đang nạp từ API trong vùng xem (cả system + user)
  List<PlantMapMarker> items = [];

  /// Cây đang hiển thị sau khi áp dụng bộ lọc (All / System / User)
  List<PlantMapMarker> visibleItems = [];

  /// Master list chứa TOÀN Bộ cây hệ thống trên toàn quốc để tìm kiếm tức thì
  List<PlantMapMarker> _allSystemPlants = [];

  /// Toàn bộ cây cá nhân của user trong cơ sở dữ liệu
  List<PlantMapMarker> _allUserPlants = [];

  bool isOffline = false;
  bool isMockData = false;

  MapSourceFilter filter = MapSourceFilter.all;

  /// Theme hiển thị của bản đồ (Bản đồ Tiêu chuẩn OSM mặc định đầu tiên)
  MapTileTheme currentTheme = MapTileTheme.standard;

  /// Loài cây đang được làm nổi bật (khi bấm vào cây sẽ highlight toàn bộ cây cùng loài)
  String? highlightedSpeciesId;
  String? highlightedSpeciesName;

  /// Trạng thái dẫn đường / chỉ đường từ GPS tới cây
  bool isNavigating = false;
  PlantMapMarker? navigationDestination;
  List<LatLng> routePoints = [];
  double navigationDistanceKm = 0.0;
  String navigationDistanceDisplay = '';
  int navigationDurationMinutes = 0;
  String navigationDurationDisplay = '';
  double currentBearing = 0.0;

  /// Chế độ tìm cây gần người dùng
  bool isNearbyActive = false;
  bool isNearbyLoading = false;
  double nearbyRadiusKm = 3.0;
  List<NearbyPlantItem> nearbyPlants = [];

  /// Danh sách cây hiển thị trên thanh Card Carousel ngang ở đáy bản đồ
  List<PlantMapMarker> carouselPlants = [];

  /// Danh sách cây gốc nạp vào Carousel trước khi áp dụng bộ lọc nguồn cây
  List<PlantMapMarker> _rawCarouselPlants = [];

  /// Cây đang được chọn / xem trong Carousel
  PlantMapMarker? selectedCarouselPlant;

  /// Vị trí trang hiện tại của Carousel
  int selectedCarouselIndex = 0;

  /// Trạng thái hiển thị thanh Card Carousel ngang
  bool isCarouselVisible = false;

  /// Sự kiện mở bottom sheet chi tiết khi nhấn vào card trong Carousel
  PlantMapMarker? detailSheetPlant;

  /// Marker đang được chọn
  PlantMapMarker? selectedMarker;

  /// Kết quả tìm kiếm (cây hệ thống)
  List<PlantMapMarker> searchResults = [];

  String searchQuery = '';

  // ── Debounce & Streams ───────────────────────────────────────────────────

  Timer? _debounceTimer;
  static const _kDebounceMs = 400;

  StreamSubscription<Position>? _positionStreamSub;
  DateTime? _lastRouteUpdateTime;

  LatLngBounds? _currentBounds;
  bool _hasLoadedOnce = false;

  LatLng? _pendingFocus;
  double _pendingFocusZoom = 15.0;

  // ── 1. Initialization & Location Request ──────────────────────────────────

  Future<void> initialize() async {
    await _loadCacheIfEmpty();
    // Nạp trước danh sách cây hệ thống để phục vụ tìm kiếm tức thì
    _loadMasterSystemPlants();
    // Nạp toàn bộ cây cá nhân của user (để bay tới khi bấm lọc)
    _loadAllUserPlants();
    await _requestLocationPermission();
    _startLiveLocationTracking();
  }

  /// Tải toàn bộ cây cá nhân của user từ MongoDB (không giới hạn viewport)
  Future<void> _loadAllUserPlants() async {
    try {
      final userPlants = await _api.fetchAllUserPlants();
      if (userPlants.isNotEmpty) {
        _allUserPlants = userPlants;
        final existingIds = items.map((m) => m.id).toSet();
        final missing =
            userPlants.where((p) => !existingIds.contains(p.id)).toList();
        if (missing.isNotEmpty) {
          items.addAll(missing);
          _applyFilter();
        }
      }
    } catch (_) {}
  }

  /// Tải toàn bộ cây hệ thống ở Việt Nam để thanh tìm kiếm luôn có dữ liệu
  Future<void> _loadMasterSystemPlants() async {
    try {
      final res = await _api.fetchMarkersInBounds(
        minLat: 8.0,
        maxLat: 24.0,
        minLng: 102.0,
        maxLng: 110.0,
      );
      if (res.markers.isNotEmpty) {
        _allSystemPlants = res.markers
            .where((m) => m.source == PlantSource.system)
            .toList();
        if (items.isEmpty) {
          items = res.markers;
          _applyFilter();
        }
      }
    } catch (_) {}
  }

  /// Yêu cầu quyền vị trí khi mở màn hình
  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handlePermissionDenied(
          message:
              'Vui lòng bật định vị GPS để hiển thị vị trí của bạn trên bản đồ.',
        );
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _handlePermissionDenied(
          message: 'Hãy cho phép ứng dụng truy cập vị trí.',
        );
        return;
      }

      // Người dùng ĐÃ CHO PHÉP vị trí
      permissionState = MapPermissionState.granted;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final loc = LatLng(pos.latitude, pos.longitude);
      userLocation = loc;

      // Nhận diện toạ độ mặc định của máy ảo Android (Mountain View, California)
      // Lat ~37.42, Lng ~-122.08 hoặc nằm ngoài lãnh thổ Việt Nam
      final isOutsideVietnam =
          loc.latitude < 8.0 ||
          loc.latitude > 24.0 ||
          loc.longitude < 102.0 ||
          loc.longitude > 110.0;

      if (isOutsideVietnam) {
        isEmulatorUSLocation = true;
        // Nếu là máy ảo ở Mỹ: Lưu vị trí người dùng nhưng tâm map ưu tiên mở ở vườn cây Việt Nam
        final random = Random();
        final defaultVN =
            _kDefaultSystemCoords[random.nextInt(_kDefaultSystemCoords.length)];
        initialCenter = defaultVN;
        initialZoom = _kDefaultZoom;

        if (isMapReady) {
          mapController.move(defaultVN, _kDefaultZoom);
        } else {
          _pendingFocus = defaultVN;
          _pendingFocusZoom = _kDefaultZoom;
        }
      } else {
        isEmulatorUSLocation = false;
        initialCenter = loc;
        initialZoom = 15.0;

        if (isMapReady) {
          mapController.move(loc, 15.0);
        } else {
          _pendingFocus = loc;
          _pendingFocusZoom = 15.0;
        }
      }

      notifyListeners();
    } catch (_) {
      _handlePermissionDenied(
        message: 'Hãy cho phép ứng dụng truy cập vị trí.',
      );
    }
  }

  void _handlePermissionDenied({required String message}) {
    permissionState = MapPermissionState.denied;

    final random = Random();
    final systemItems = _allSystemPlants.isNotEmpty
        ? _allSystemPlants
        : items.where((m) => m.source == PlantSource.system).toList();

    final LatLng randomTarget = systemItems.isNotEmpty
        ? systemItems[random.nextInt(systemItems.length)].location
        : _kDefaultSystemCoords[random.nextInt(_kDefaultSystemCoords.length)];

    initialCenter = randomTarget;
    initialZoom = _kDefaultZoom;

    if (isMapReady) {
      mapController.move(randomTarget, _kDefaultZoom);
    } else {
      _pendingFocus = randomTarget;
      _pendingFocusZoom = _kDefaultZoom;
    }

    notifyListeners();

    onEvent?.call(MapDialogEvent(message, title: 'Quyền truy cập vị trí'));
  }

  // ── 4. Nút định vị My Location ────────────────────────────────────────────

  Future<void> focusMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        permissionState = MapPermissionState.denied;
        notifyListeners();
        onEvent?.call(
          const MapDialogEvent(
            'Hãy cho phép ứng dụng truy cập vị trí để định vị vị trí hiện tại của bạn.',
            title: 'Quyền truy cập vị trí',
          ),
        );
        return;
      }

      permissionState = MapPermissionState.granted;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final loc = LatLng(pos.latitude, pos.longitude);
      userLocation = loc;

      if (isMapReady) {
        mapController.move(loc, 16.0);
      }
      notifyListeners();

      // Nếu đang dùng toạ độ máy ảo ở Mỹ, nhắc nhẹ người dùng
      if (loc.latitude < 8.0 || loc.latitude > 24.0) {
        onEvent?.call(
          const MapDialogEvent(
            'Máy ảo Android đang mô phỏng GPS tại Mỹ. Bạn có thể mở cài đặt máy ảo (nút ... trên toolbar máy ảo) > Location để đổi toạ độ về Việt Nam.',
            title: 'Định vị máy ảo',
          ),
        );
      }
    } catch (_) {
      onEvent?.call(
        const MapDialogEvent(
          'Không thể lấy vị trí hiện tại. Hãy kiểm tra lại kết nối GPS.',
          title: 'Thông báo',
        ),
      );
    }
  }

  Future<void> focusOnLocation(LatLng target, {double zoom = 17.0}) async {
    initialCenter = target;
    initialZoom = zoom;

    if (!isMapReady) {
      _pendingFocus = target;
      _pendingFocusZoom = zoom;
      notifyListeners();
      return;
    }

    try {
      mapController.move(target, zoom);
    } catch (_) {
      _pendingFocus = target;
      _pendingFocusZoom = zoom;
    }
    notifyListeners();
  }

  // ── 2. Zoom in, Zoom out ──────────────────────────────────────────────────

  void zoomIn() {
    if (!isMapReady) return;
    try {
      final currentZoom = mapController.camera.zoom;
      mapController.move(
        mapController.camera.center,
        (currentZoom + 1.0).clamp(5.0, 18.0),
      );
    } catch (_) {}
  }

  void zoomOut() {
    if (!isMapReady) return;
    try {
      final currentZoom = mapController.camera.zoom;
      mapController.move(
        mapController.camera.center,
        (currentZoom - 1.0).clamp(5.0, 18.0),
      );
    } catch (_) {}
  }

  // ── Map Ready ─────────────────────────────────────────────────────────────

  void onMapReady() {
    isMapReady = true;
    _rebuildMarkers();

    final pending = _pendingFocus;
    if (pending != null) {
      _pendingFocus = null;
      final zoom = _pendingFocusZoom;
      try {
        mapController.move(pending, zoom);
      } catch (_) {}
    }

    _fetchMarkersForCurrentBounds();
  }

  // ── Camera Events ─────────────────────────────────────────────────────────

  void onPositionChanged(MapCamera camera, bool hasGesture) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _kDebounceMs), () {
      _fetchMarkersForCurrentBounds();
    });
  }

  // ── Fetch API (An toàn tuyệt đối với Bounding Box Clamp) ───────────────────

  Future<void> _fetchMarkersForCurrentBounds() async {
    if (!isMapReady) return;

    try {
      _currentBounds = mapController.camera.visibleBounds;
    } catch (_) {
      return;
    }
    if (_currentBounds == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    final hasNetwork =
        connectivityResult.any((c) => c != ConnectivityResult.none);

    if (!hasNetwork) {
      await _handleOffline();
      return;
    }

    isOffline = false;
    loadState = MapLoadState.loading;
    notifyListeners();

    try {
      // 4. Giới hạn vĩ độ và kinh độ chặt chẽ để không bao giờ vượt quá 90°
      final minLat = _currentBounds!.southWest.latitude.clamp(-85.0, 85.0);
      final maxLat = _currentBounds!.northEast.latitude.clamp(-85.0, 85.0);
      final minLng = _currentBounds!.southWest.longitude.clamp(-180.0, 180.0);
      final maxLng = _currentBounds!.northEast.longitude.clamp(-180.0, 180.0);

      final result = await _api.fetchMarkersInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );

      isMockData = result.isMock;
      items = result.markers;
      _hasLoadedOnce = true;
      loadState = MapLoadState.loaded;

      if (items.isNotEmpty) {
        await _cache.saveMarkers(items);
      }

      _applyFilter();

      if (result.partialErrorMessage != null) {
        onEvent?.call(MapDialogEvent(result.partialErrorMessage!));
      }
    } catch (e) {
      loadState = MapLoadState.error;
      onEvent?.call(
        const MapDialogEvent(
          'Không thể tải dữ liệu bản đồ lúc này. Vui lòng thử lại sau.',
        ),
      );
    }

    notifyListeners();
  }

  Future<void> _handleOffline() async {
    isOffline = true;
    loadState = MapLoadState.loaded;

    if (items.isEmpty) {
      final cached = await _cache.loadMarkers();
      if (cached.isNotEmpty) {
        items = cached;
        _hasLoadedOnce = true;
        _applyFilter();
        onEvent?.call(
          MapDialogEvent(
            'Mất kết nối mạng. Đang hiển thị ${cached.length} cây từ bộ nhớ đệm.',
            title: 'Mất kết nối',
          ),
        );
      } else {
        onEvent?.call(
          const MapDialogEvent(
            'Mất kết nối mạng và chưa có dữ liệu lưu trữ để hiển thị.',
            title: 'Mất kết nối',
          ),
        );
      }
    }

    notifyListeners();
  }

  Future<void> _loadCacheIfEmpty() async {
    if (_hasLoadedOnce) return;
    final cached = await _cache.loadMarkers();
    if (cached.isEmpty) return;
    items = cached;
    _applyFilter();
    notifyListeners();
  }

  // ── 5. Triển khai tính năng lọc (Filter) ──────────────────────────────────

  void setFilter(MapSourceFilter value) {
    if (filter == value) return;

    if (value == MapSourceFilter.user) {
      if (_allUserPlants.isNotEmpty) {
        final existingIds = items.map((m) => m.id).toSet();
        final missing =
            _allUserPlants.where((p) => !existingIds.contains(p.id)).toList();
        if (missing.isNotEmpty) {
          items.addAll(missing);
        }
      } else {
        _loadAllUserPlants().then((_) {
          _applyFilter();
          notifyListeners();
          if (_allUserPlants.isEmpty) {
            onEvent?.call(
              const MapDialogEvent(
                'Bạn chưa có cây cá nhân nào được lưu. Hãy nhận diện và bấm "Lưu vào Bản đồ" để lưu cây của bạn.',
                title: 'Cây cá nhân',
              ),
            );
          }
        });
      }
    }

    filter = value;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    var result = items;
    switch (filter) {
      case MapSourceFilter.all:
        break;
      case MapSourceFilter.system:
        result = result.where((m) => m.source == PlantSource.system).toList();
        break;
      case MapSourceFilter.user:
        result = result.where((m) => m.source == PlantSource.user).toList();
        break;
    }

    visibleItems = result;
    _syncCarouselWithFilter();
    _rebuildMarkers();
    _recomputeSearchResults();
  }

  /// Đồng bộ danh sách Card Carousel với bộ lọc nguồn cây hiện tại (Tất cả / Hệ thống / Cá nhân)
  void _syncCarouselWithFilter() {
    if (_rawCarouselPlants.isEmpty) {
      carouselPlants = [];
      isCarouselVisible = false;
      selectedCarouselPlant = null;
      selectedCarouselIndex = 0;
      return;
    }

    switch (filter) {
      case MapSourceFilter.all:
        carouselPlants = List.from(_rawCarouselPlants);
        break;
      case MapSourceFilter.system:
        carouselPlants = _rawCarouselPlants
            .where((p) => p.source == PlantSource.system)
            .toList();
        break;
      case MapSourceFilter.user:
        carouselPlants = _rawCarouselPlants
            .where((p) => p.source == PlantSource.user)
            .toList();
        break;
    }

    if (carouselPlants.isNotEmpty) {
      isCarouselVisible = true;
      if (selectedCarouselIndex >= carouselPlants.length) {
        selectedCarouselIndex = 0;
      }
      selectedCarouselPlant = carouselPlants[selectedCarouselIndex];
    } else {
      isCarouselVisible = false;
      selectedCarouselPlant = null;
      selectedCarouselIndex = 0;
    }
  }

  // ── 3. Tìm kiếm cây hệ thống theo tên (không dấu/có dấu, chống lỗi gõ) ─────

  void setSearchQuery(String query) {
    searchQuery = query;
    _recomputeSearchResults();
    notifyListeners();
  }

  void clearSearch() {
    if (searchQuery.isEmpty && searchResults.isEmpty) return;
    searchQuery = '';
    searchResults = [];
    notifyListeners();
  }

  void _recomputeSearchResults() {
    final q = searchQuery.trim();
    if (q.isEmpty) {
      searchResults = [];
      return;
    }

    // Tìm kiếm trên toàn bộ cây hệ thống (ưu tiên master list)
    final pool = _allSystemPlants.isNotEmpty
        ? _allSystemPlants
        : items.where((m) => m.source == PlantSource.system).toList();

    final scored = <({PlantMapMarker plant, double score})>[];
    for (final plant in pool) {
      final score = VietnameseSearchHelper.matchScore(
        q,
        plant.name,
        plant.scientificName,
      );
      if (score > 0) {
        scored.add((plant: plant, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Loại bỏ kết quả trùng lặp tên loài cây (Deduplication)
    final seenNames = <String>{};
    final uniqueList = <PlantMapMarker>[];
    for (final item in scored) {
      final key = item.plant.name.trim().toLowerCase();
      if (seenNames.add(key)) {
        uniqueList.add(item.plant);
      }
    }

    searchResults = uniqueList.take(15).toList();
  }

  // ── 4. Chức năng Định vị Cây quanh đây (Tuỳ chỉnh bán kính) ──────────────

  Future<void> findNearbyPlants({double radiusKm = 3.0}) async {
    if (userLocation == null) {
      await _requestLocationPermission();
      if (userLocation == null) {
        onEvent?.call(
          const MapDialogEvent(
            'Vui lòng cho phép ứng dụng truy cập vị trí GPS để tìm cây quanh bạn.',
            title: 'Quyền vị trí',
          ),
        );
        return;
      }
    }

    isNearbyLoading = true;
    nearbyRadiusKm = radiusKm;
    notifyListeners();

    try {
      final results = await _api.fetchNearbyPlants(
        lat: userLocation!.latitude,
        lng: userLocation!.longitude,
        radiusKm: radiusKm,
      );

      nearbyPlants = results;
      isNearbyActive = true;
      isNearbyLoading = false;

      // Nạp danh sách cây vào Card Carousel ngang (áp dụng bộ lọc nguồn cây)
      final newMarkers = results
          .map(
            (n) => PlantMapMarker(
              id: n.id,
              plantId: n.id,
              name: n.name,
              scientificName: n.scientificName,
              description: n.description,
              source: n.source,
              latitude: n.latitude,
              longitude: n.longitude,
              imageUrl: n.thumbnailUrl ?? n.imageUrl,
            ),
          )
          .toList();

      final existingIds = items.map((m) => m.id).toSet();
      final missing = newMarkers.where((m) => !existingIds.contains(m.id)).toList();
      if (missing.isNotEmpty) {
        items.addAll(missing);
        _applyFilter();
      }

      _rawCarouselPlants = newMarkers;
      selectedCarouselIndex = 0;
      _syncCarouselWithFilter();

      _rebuildMarkers();

      if (nearbyPlants.isEmpty) {
        onEvent?.call(
          MapDialogEvent(
            'Không tìm thấy cây thuốc nào trong bán kính ${radiusKm.toInt()} km quanh bạn.',
            title: 'Cây quanh bạn (${radiusKm.toInt()} km)',
          ),
        );
      }

      // Đưa vị trí GPS của người dùng vào chính giữa màn hình và hiển thị rõ ràng trọn vẹn vòng tròn bán kính
      if (isMapReady && userLocation != null) {
        final zoom = _getZoomForRadius(radiusKm);
        mapController.move(userLocation!, zoom);
      }
    } catch (e) {
      isNearbyLoading = false;
      onEvent?.call(
        const MapDialogEvent(
          'Không thể tìm kiếm cây quanh đây lúc này. Vui lòng thử lại sau.',
          title: 'Lỗi',
        ),
      );
    }
    notifyListeners();
  }

  Future<void> setNearbyRadius(double km) async {
    nearbyRadiusKm = km;
    await findNearbyPlants(radiusKm: km);
  }

  double _getZoomForRadius(double radiusKm) {
    if (radiusKm <= 1.0) return 14.8;
    if (radiusKm <= 2.0) return 13.8;
    if (radiusKm <= 3.0) return 13.2;
    if (radiusKm <= 4.0) return 12.8;
    return 12.4;
  }

  void exitNearbyMode() {
    isNearbyActive = false;
    nearbyPlants = [];
    isCarouselVisible = false;
    selectedCarouselPlant = null;
    selectedCarouselIndex = 0;
    _rawCarouselPlants = [];
    carouselPlants = [];
    _rebuildMarkers();
    notifyListeners();
  }

  // ── Marker & Carousel Interaction ──────────────────────────────────────────

  void onMarkerTap(String markerId) {
    final plant = visibleItems.firstWhere(
      (m) => m.id == markerId,
      orElse: () => items.firstWhere(
        (m) => m.id == markerId,
        orElse: () => _emptyMarker,
      ),
    );
    if (plant.id.isEmpty) return;

    // Nếu đang trong trạng thái chỉ đường: chuyển lộ trình sang cây này tiếp tục dẫn đường mượt mà
    if (isNavigating) {
      startNavigationTo(plant);
      return;
    }

    // Highlight loài cây cùng loại
    highlightSpecies(plant);

    // Tìm tất cả các cây cùng loài này (cùng 1 loại cây nhưng có nhiều định vị)
    final sameSpecies = visibleItems.where((p) => _isSameSpecies(p, plant)).toList();

    // Tìm thêm các cây nằm đè nhau tại cùng vị trí (khoảng cách <= 50 mét) nếu có
    final overlapping = visibleItems.where((p) {
      if (p.id == plant.id) return false;
      final dist = Geolocator.distanceBetween(
        plant.latitude,
        plant.longitude,
        p.latitude,
        p.longitude,
      );
      return dist <= 50.0;
    }).toList();

    // Sắp xếp đưa cây được bấm lên đầu, theo sau là các vị trí của cùng loài cây này và các cây đè nhau
    final combined = <PlantMapMarker>[plant];
    for (final p in sameSpecies) {
      if (p.id != plant.id && !combined.any((c) => c.id == p.id)) {
        combined.add(p);
      }
    }
    for (final p in overlapping) {
      if (!combined.any((c) => c.id == p.id)) {
        combined.add(p);
      }
    }

    _rawCarouselPlants = combined;
    selectedCarouselIndex = 0;
    _syncCarouselWithFilter();

    _rebuildMarkers();
    notifyListeners();
  }

  void onCarouselPageChanged(int index) {
    if (index < 0 || index >= carouselPlants.length) return;
    selectedCarouselIndex = index;
    selectedCarouselPlant = carouselPlants[index];

    // Lướt đến box của ô nào thì map bay đến định vị của ô đó
    if (isMapReady && selectedCarouselPlant != null) {
      mapController.move(selectedCarouselPlant!.location, 16.5);
    }

    _rebuildMarkers();
    notifyListeners();
  }

  void openPlantDetailFromCard(PlantMapMarker plant) {
    detailSheetPlant = plant;
    notifyListeners();
  }

  void clearDetailSheetEvent() {
    detailSheetPlant = null;
  }

  void closeCarousel() {
    isCarouselVisible = false;
    selectedCarouselPlant = null;
    selectedCarouselIndex = 0;
    _rawCarouselPlants = [];
    carouselPlants = [];
    clearSpeciesHighlight();
    _rebuildMarkers();
    notifyListeners();
  }

  // ── Theme Switcher ────────────────────────────────────────────────────────

  void setTheme(MapTileTheme theme) {
    if (currentTheme == theme) return;
    currentTheme = theme;
    notifyListeners();
  }

  // ── Species Highlighting / Dimming (Một cây nhiều vị trí) ──────────────────

  void highlightSpecies(PlantMapMarker plant) {
    final targetId = plant.plantId.isNotEmpty ? plant.plantId : plant.id;
    highlightedSpeciesId = targetId;
    highlightedSpeciesName = plant.name;
    _rebuildMarkers();
    notifyListeners();
  }

  void clearSpeciesHighlight() {
    if (highlightedSpeciesId == null) return;
    highlightedSpeciesId = null;
    highlightedSpeciesName = null;
    _rebuildMarkers();
    notifyListeners();
  }

  // ── Dẫn đường / Chỉ đường (Backend Routing & Live Bearing Update) ──────────

  void _startLiveLocationTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Cập nhật vị trí khi di chuyển từ 3m trở lên
      ),
    ).listen((Position pos) {
      final newLoc = LatLng(pos.latitude, pos.longitude);
      userLocation = newLoc;

      // Cập nhật hướng xoay la bàn thiết bị nếu cảm biến cung cấp
      if (pos.heading >= 0) {
        currentBearing = pos.heading;
      }

      // Nếu đang trong chế độ dẫn đường: Tự động cập nhật lại lộ trình & khoảng cách realtime từ Backend
      if (isNavigating && navigationDestination != null) {
        _updateLiveRoute(newLoc, navigationDestination!);
      }

      notifyListeners();
    });
  }

  Future<void> _updateLiveRoute(LatLng currentLoc, PlantMapMarker dest) async {
    final now = DateTime.now();
    if (_lastRouteUpdateTime != null &&
        now.difference(_lastRouteUpdateTime!).inMilliseconds < 2500) {
      return;
    }
    _lastRouteUpdateTime = now;

    final dir = await _api.fetchDirections(
      startLat: currentLoc.latitude,
      startLng: currentLoc.longitude,
      endLat: dest.latitude,
      endLng: dest.longitude,
    );

    if (dir != null && isNavigating) {
      routePoints = dir.points;
      navigationDistanceKm = dir.distanceKm;
      navigationDistanceDisplay = dir.distanceDisplay;
      navigationDurationMinutes = dir.durationMinutes;
      navigationDurationDisplay = dir.durationDisplay;
      if (dir.bearing > 0) {
        currentBearing = dir.bearing;
      }
      notifyListeners();
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180.0);
    final startLng = start.longitude * (pi / 180.0);
    final endLat = end.latitude * (pi / 180.0);
    final endLng = end.longitude * (pi / 180.0);

    final dLng = endLng - startLng;

    final y = sin(dLng) * cos(endLat);
    final x =
        cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(dLng);

    final bearing = atan2(y, x);
    return (bearing * (180.0 / pi) + 360.0) % 360.0;
  }

  Future<void> startNavigationTo(PlantMapMarker plant) async {
    if (userLocation == null) {
      onEvent?.call(
        const MapDialogEvent(
          'Không thể định vị được vị trí GPS hiện tại của bạn. Vui lòng bật GPS và thử lại.',
          title: 'Chỉ đường',
        ),
      );
      return;
    }

    isNavigating = true;
    navigationDestination = plant;
    isCarouselVisible = false;
    _rawCarouselPlants = [];
    carouselPlants = [];
    selectedCarouselPlant = null;
    notifyListeners();

    // Gọi Backend Directions API xử lý lộ trình OSRM
    final dir = await _api.fetchDirections(
      startLat: userLocation!.latitude,
      startLng: userLocation!.longitude,
      endLat: plant.latitude,
      endLng: plant.longitude,
    );

    if (dir != null) {
      routePoints = dir.points;
      navigationDistanceKm = dir.distanceKm;
      navigationDistanceDisplay = dir.distanceDisplay;
      navigationDurationMinutes = dir.durationMinutes;
      navigationDurationDisplay = dir.durationDisplay;
      currentBearing = dir.bearing;
    } else {
      routePoints = [userLocation!, plant.location];
      final distMeters = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation!.longitude,
        plant.latitude,
        plant.longitude,
      );
      navigationDistanceKm = distMeters / 1000.0;
      navigationDistanceDisplay = navigationDistanceKm < 1.0
          ? '${distMeters.round()} m'
          : '${navigationDistanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';
      navigationDurationMinutes =
          (navigationDistanceKm / 35.0 * 60.0).ceil().clamp(1, 9999);
      navigationDurationDisplay = '$navigationDurationMinutes phút';
      currentBearing = _calculateBearing(userLocation!, plant.location);
    }

    try {
      final bounds = LatLngBounds.fromPoints([userLocation!, plant.location]);
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 180, 40, 180),
        ),
      );
    } catch (_) {}

    notifyListeners();
  }

  void stopNavigation() {
    isNavigating = false;
    navigationDestination = null;
    routePoints = [];
    navigationDistanceKm = 0.0;
    navigationDistanceDisplay = '';
    navigationDurationMinutes = 0;
    navigationDurationDisplay = '';
    notifyListeners();
  }

  static final PlantMapMarker _emptyMarker = PlantMapMarker(
    id: '',
    name: '',
    source: PlantSource.system,
    latitude: 0,
    longitude: 0,
  );

  /// 4. Bay tới vị trí cây khi bấm gợi ý tìm kiếm:
  /// Làm sáng các cây cùng loài (vd Chỉ Thiên), làm mờ các cây khác,
  /// đưa các điểm cây đó vào Card Carousel và bay tới vị trí.
  void focusPlant(PlantMapMarker plant) {
    clearSearch();

    // 1. Highlight loài cây này (làm sáng tất cả cây cùng loài, làm mờ các cây khác)
    highlightSpecies(plant);

    // 2. Tìm tất cả các điểm cây cùng loài này đang có trên bản đồ
    final targetKey = plant.plantId.isNotEmpty
        ? plant.plantId
        : plant.name.toLowerCase();
    final sameSpecies = visibleItems.where((p) {
      final pKey = p.plantId.isNotEmpty ? p.plantId : p.name.toLowerCase();
      return pKey == targetKey || p.name.toLowerCase() == plant.name.toLowerCase();
    }).toList();

    _rawCarouselPlants = sameSpecies.isNotEmpty ? sameSpecies : [plant];
    selectedCarouselIndex = 0;
    _syncCarouselWithFilter();

    // 3. Map bay tới tọa độ cây
    if (isMapReady && carouselPlants.isNotEmpty) {
      mapController.move(carouselPlants.first.location, 16.0);
    }

    _rebuildMarkers();
    notifyListeners();
  }

  void clearSelection() {
    if (selectedMarker == null) return;
    selectedMarker = null;
    notifyListeners();
  }

  // ── Exact Plant Marker Builder (Không gộp số lượng, làm mờ ngoài bán kính) ──

  /// Kiểm tra 2 marker có phải là cùng 1 loại cây hay không (theo plantId, tên tiếng Việt, hoặc tên khoa học)
  bool _isSameSpecies(PlantMapMarker a, PlantMapMarker b) {
    if (a.id == b.id) return true;

    // 1. So khớp theo plantId nếu cả 2 đều có
    if (a.plantId.isNotEmpty && b.plantId.isNotEmpty && a.plantId == b.plantId) {
      return true;
    }

    // 2. So khớp theo tên tiếng Việt (chuẩn hóa chữ thường, bỏ khoảng trắng thừa)
    final nameA = a.name.trim().toLowerCase();
    final nameB = b.name.trim().toLowerCase();
    if (nameA.isNotEmpty && nameA == nameB) {
      return true;
    }

    // 3. So khớp theo tên khoa học
    if (a.scientificName != null &&
        b.scientificName != null &&
        a.scientificName!.trim().isNotEmpty &&
        a.scientificName!.trim().toLowerCase() ==
            b.scientificName!.trim().toLowerCase()) {
      return true;
    }

    return false;
  }

  Marker _buildPlantMarker(PlantMapMarker plant) {
    final isSystem = plant.source == PlantSource.system;
    final isSelected = selectedCarouselPlant?.id == plant.id;
    final speciesKey = plant.plantId.isNotEmpty ? plant.plantId : plant.id;
    final bool isMatchingSpecies =
        highlightedSpeciesId == null ||
        (plant.plantId.isNotEmpty && plant.plantId == highlightedSpeciesId) ||
        (speciesKey == highlightedSpeciesId) ||
        (highlightedSpeciesName != null &&
            plant.name.trim().toLowerCase() ==
                highlightedSpeciesName!.trim().toLowerCase());

    // Kiểm tra chính xác khoảng cách từ GPS người dùng tới cây
    bool isInsideRadius = true;
    if (isNearbyActive && userLocation != null) {
      final distMeters = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation!.longitude,
        plant.latitude,
        plant.longitude,
      );
      isInsideRadius = distMeters <= (nearbyRadiusKm * 1000.0);
    }

    // Làm mờ:
    // 1. Khi bật bán kính (Quanh đây): tất cả các chấm TRONG BÁN KÍNH LUÔN LUÔN SÁNG (100% không mờ)
    //    Chỉ làm mờ những chấm NẰM NGOÀI BÁN KÍNH.
    // 2. Khi không bật bán kính: làm mờ các cây không khớp loài đang highlight.
    final bool isDimmed = isNearbyActive ? !isInsideRadius : !isMatchingSpecies;

    final double opacity = isDimmed ? 0.22 : 1.0;

    // Màu sắc chuẩn rõ ràng: Cây hệ thống (xanh) / Cây cá nhân (cam)
    final Color markerColor = isSystem ? _kSystemColor : _kUserColor;
    final IconData markerIcon = isSystem
        ? Icons.eco_rounded
        : Icons.camera_alt_rounded;

    final size = isSelected ? 42.0 : 34.0;

    return Marker(
      point: plant.location,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: () => onMarkerTap(plant.id),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.amber.shade700 : markerColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Colors.amber.withValues(alpha: 0.6)
                      : Colors.black26,
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              markerIcon,
              color: Colors.white,
              size: isSelected ? 22 : 18,
            ),
          ),
        ),
      ),
    );
  }

  void _rebuildMarkers() {
    markers = visibleItems.map(_buildPlantMarker).toList();
    notifyListeners();
  }

  // ── Public Actions ────────────────────────────────────────────────────────

  Future<void> retry() => _fetchMarkersForCurrentBounds();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _debounceTimer?.cancel();
    mapController.dispose();
    _api.dispose();
    super.dispose();
  }
}
