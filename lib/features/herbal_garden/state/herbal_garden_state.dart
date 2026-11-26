// lib/features/herbal_garden/state/herbal_garden_state.dart
//
// State quản lý cho toàn bộ chức năng Vườn Dược Liệu.
//
// Kiến trúc: 1 ChangeNotifier duy nhất ([HerbalGardenController]) giữ toàn bộ
// state của màn hình vườn, được cấp qua Provider ở cấp cao nhất nơi mở
// màn hình. Nhờ vậy các màn hình con (chi tiết cây, thêm cây) đều đọc được
// cùng một nguồn dữ liệu và tự đồng bộ sau khi ghi.

import 'package:flutter/foundation.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/core/map_vietnamese_search_helper.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/services/herbal_garden_api.dart';

/// Trạng thái tải của một nhóm dữ liệu.
enum GardenLoadState { idle, loading, ready, error }

class HerbalGardenController extends ChangeNotifier {
  HerbalGardenController({HerbalGardenApi? api})
    : _api = api ?? HerbalGardenApi();

  final HerbalGardenApi _api;

  /// API client dùng chung — màn hình con (Thêm cây) dùng luôn client này
  /// để không tạo thêm connection pool không cần thiết.
  HerbalGardenApi get api => _api;

  /// UID dùng cho các lệnh ghi.
  ///
  /// - `AppConfig.gardenPerUser == true` → uid của account đang đăng nhập.
  /// - ngược lại → `AppConfig.gardenUid` (mặc định `demo` — vườn mẫu).
  ///
  /// Khi backend bật `HERBAL_GARDEN_REQUIRE_AUTH=true`, server bỏ qua `uid`
  /// trong query và tự lấy uid từ `Authorization: Bearer`.
  String _uid = AppConfig.gardenUid;

  String get uid => _uid;

  /// Đổi uid (gọi khi biết user đã đăng nhập).
  void setUid(String? userId) {
    final next = (userId != null && userId.isNotEmpty)
        ? userId
        : AppConfig.gardenUid;
    if (_uid == next) return;
    _uid = next;
  }

  // ── Trạng thái tải ──────────────────────────────────────────────────────

  GardenLoadState _listState = GardenLoadState.idle;
  GardenLoadState _careState = GardenLoadState.idle;
  GardenLoadState _weatherState = GardenLoadState.idle;
  GardenLoadState _deletedState = GardenLoadState.idle;

  GardenLoadState get listState => _listState;
  GardenLoadState get careState => _careState;
  GardenLoadState get weatherState => _weatherState;
  GardenLoadState get deletedState => _deletedState;

  bool get isLoadingList => _listState == GardenLoadState.loading;
  bool get isLoadingCare => _careState == GardenLoadState.loading;
  bool get isLoadingWeather => _weatherState == GardenLoadState.loading;
  bool get isLoadingDeleted => _deletedState == GardenLoadState.loading;

  // ── Dữ liệu ─────────────────────────────────────────────────────────────

  List<GardenPlantItem> _plants = <GardenPlantItem>[];
  CareToday _care = CareToday.empty();
  GardenWeather? _weather;
  List<DeletedGardenPlant> _deleted = <DeletedGardenPlant>[];

  List<GardenPlantItem> get plants => _plants;
  CareToday get care => _care;
  GardenWeather? get weather => _weather;
  List<DeletedGardenPlant> get deletedPlants => _deleted;

  int get totalPlants => _plants.length;
  double get tongKhoiLuongThuHoachKg =>
      _plants.fold<double>(0, (sum, p) => sum + p.tongKhoiLuongThuHoachKg);

  // ── Lỗi ─────────────────────────────────────────────────────────────────

  String? _listError;
  String? _careError;
  String? _weatherError;
  String? _deletedError;

  String? get listError => _listError;
  String? get careError => _careError;
  String? get weatherError => _weatherError;
  String? get deletedError => _deletedError;

  bool get hasFatalError =>
      _listState == GardenLoadState.error && _plants.isEmpty;

  // ── Bộ lọc trên UI ──────────────────────────────────────────────────────

  /// null = không lọc.
  String? _stageFilter;
  String? get stageFilter => _stageFilter;

  /// true = chỉ hiện cây đang cần chăm sóc hôm nay.
  bool _onlyNeedsCare = false;
  bool get onlyNeedsCare => _onlyNeedsCare;

  /// Tìm theo tên (không phân biệt hoa thường).
  String _query = '';
  String get query => _query;

  List<GardenPlantItem> get filteredPlants {
    // ⚠️ Tìm kiếm phải BỎ DẤU để "bac" khớp "Bạc hà", "rau ma" khớp
    // "Rau má"… (đồng nhất với ô tìm kiếm trong trang Danh mục dược liệu).
    final q = VietnameseSearchHelper.normalize(_query);
    return _plants.where((p) {
      if (_stageFilter != null && p.stage != _stageFilter) return false;
      if (_onlyNeedsCare && !p.canChamSocHomNay) return false;
      if (q.isEmpty) return true;
      final name = VietnameseSearchHelper.normalize(p.displayName);
      final sci = VietnameseSearchHelper.normalize(p.tenQuocte ?? '');
      if (name.contains(q) || sci.contains(q)) return true;

      // Khớp theo từng từ khoá (vd: gõ "bac ha" → "Bạc hà").
      final tokens = VietnameseSearchHelper.tokenize(_query);
      if (tokens.isEmpty) return false;
      final nameTokens = name.split(' ');
      return tokens.every(
        (t) => nameTokens.any((w) => w.startsWith(t) || _isClose(w, t)),
      );
    }).toList();
  }

  /// So sánh gần đúng 1 ký tự (chống lỗi gõ nhẹ).
  static bool _isClose(String w, String t) {
    if (w.length < 4 || t.length < 4) return false;
    return VietnameseSearchHelper.levenshteinDistance(t, w) <= 1;
  }

  void setStageFilter(String? stage) {
    if (_stageFilter == stage) return;
    _stageFilter = stage;
    notifyListeners();
  }

  void setOnlyNeedsCare(bool value) {
    if (_onlyNeedsCare == value) return;
    _onlyNeedsCare = value;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void clearFilters() {
    _stageFilter = null;
    _onlyNeedsCare = false;
    _query = '';
    notifyListeners();
  }

  /// Đang có bộ lọc nào được áp dụng hay không (để hiện nút "Bỏ lọc").
  bool get hasFilter =>
      _stageFilter != null || _onlyNeedsCare || _query.trim().isNotEmpty;

  // ── Tải dữ liệu ─────────────────────────────────────────────────────────

  /// Tải song song 3 nhóm dữ liệu chính (danh sách + việc hôm nay + thời tiết).
  Future<void> loadAll({
    bool refresh = false,
    double? latitude,
    double? longitude,
  }) async {
    await Future.wait<void>(<Future<void>>[
      loadPlants(refresh: refresh),
      loadCare(refresh: refresh),
      loadWeather(refresh: refresh, latitude: latitude, longitude: longitude),
    ]);
  }

  Future<void> loadPlants({bool refresh = false}) async {
    // Cho phép refresh chồng lên request đang chạy để dữ liệu luôn mới nhất.
    if (_listState == GardenLoadState.loading && !refresh) return;
    _listState = GardenLoadState.loading;
    _listError = null;
    notifyListeners();

    try {
      _plants = await _api.listGarden(uid: _uid);
      _listState = GardenLoadState.ready;
    } on GardenApiException catch (e) {
      _listError = e.message;
      _listState = GardenLoadState.error;
    } catch (_) {
      _listError = 'Không tải được danh sách cây. Vui lòng thử lại.';
      _listState = GardenLoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadCare({bool refresh = false}) async {
    if (_careState == GardenLoadState.loading && !refresh) return;
    _careState = GardenLoadState.loading;
    _careError = null;
    notifyListeners();

    try {
      _care = await _api.careToday(uid: _uid);
      _careState = GardenLoadState.ready;
    } on GardenApiException catch (e) {
      _careError = e.message;
      _careState = GardenLoadState.error;
    } catch (_) {
      _careError = 'Không tải được lịch chăm sóc hôm nay.';
      _careState = GardenLoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadWeather({
    bool refresh = false,
    double? latitude,
    double? longitude,
  }) async {
    if (_weatherState == GardenLoadState.loading && !refresh) return;
    _weatherState = GardenLoadState.loading;
    _weatherError = null;
    notifyListeners();

    try {
      _weather = await _api.weather(
        uid: _uid,
        latitude: latitude,
        longitude: longitude,
      );
      _weatherState = GardenLoadState.ready;
    } on GardenApiException catch (e) {
      _weatherError = e.message;
      _weatherState = GardenLoadState.error;
    } catch (_) {
      _weatherError = 'Không lấy được thời tiết.';
      _weatherState = GardenLoadState.error;
    }
    notifyListeners();
  }

  /// Tải chi tiết 1 cây — `GET /api/v1/herbal-garden/{plant_id}`.
  ///
  /// Dùng chung API client của controller nên không rò rỉ connection.
  Future<GardenPlantDetail> loadDetail(String plantId) {
    return _api.plantDetail(plantId, uid: _uid);
  }

  /// Tải danh sách cây đã xoá — `GET /api/v1/herbal-garden/deleted`.
  ///
  /// [refresh] = true bỏ qua chốt "đang tải" để ép tải lại (dùng sau khi
  /// xoá / khôi phục cây).
  Future<void> loadDeleted({bool refresh = false}) async {
    if (_deletedState == GardenLoadState.loading && !refresh) return;
    _deletedState = GardenLoadState.loading;
    _deletedError = null;
    notifyListeners();

    try {
      _deleted = await _api.deletedPlants(uid: _uid);
      _deletedState = GardenLoadState.ready;
    } on GardenApiException catch (e) {
      _deletedError = e.message;
      _deletedState = GardenLoadState.error;
    } catch (_) {
      _deletedError = 'Không tải được danh sách cây đã xoá.';
      _deletedState = GardenLoadState.error;
    }
    notifyListeners();
  }

  // ── Hành động ghi dữ liệu ──────────────────────────────────────────────

  /// Ghi nhận đã tưới — `POST /{id}/water`.
  Future<String> waterPlant(String plantId, {String? note}) async {
    final message = await _api.waterPlant(plantId, note: note, uid: _uid);
    await _refreshAfterWrite();
    return message;
  }

  /// Đổi mốc giai đoạn — `POST /{id}/stage`.
  Future<String> updateStage(
    String plantId, {
    required String stage,
    String? note,
  }) async {
    final message = await _api.updateStage(
      plantId,
      stage: stage,
      note: note,
      uid: _uid,
    );
    await _refreshAfterWrite();
    return message;
  }

  /// Gỡ thẻ việc — `POST /{id}/task/dismiss`.
  Future<String> dismissTask(
    String plantId, {
    required String taskType,
    String? choiceId,
    String? note,
  }) async {
    final message = await _api.dismissTask(
      plantId,
      taskType: taskType,
      choiceId: choiceId,
      note: note,
      uid: _uid,
    );
    await _refreshAfterWrite();
    return message;
  }

  /// Thêm ảnh nhật ký — `POST /{id}/photo`.
  Future<List<TimelineImage>> addPhoto(
    String plantId, {
    required String filePath,
    String? note,
    double? latitude,
    double? longitude,
    String? addressName,
  }) async {
    final images = await _api.addPhoto(
      plantId,
      filePath: filePath,
      note: note,
      latitude: latitude,
      longitude: longitude,
      addressName: addressName,
      uid: _uid,
    );
    await _refreshAfterWrite();
    return images;
  }

  /// Ghi sổ thu hoạch — `POST /{id}/harvest`.
  Future<({String message, String? warning, HarvestRecord? record})> harvest(
    String plantId, {
    DateTime? harvestedAt,
    double? weightKg,
    String? note,
  }) async {
    final result = await _api.harvest(
      plantId,
      harvestedAt: harvestedAt,
      weightKg: weightKg,
      note: note,
      uid: _uid,
    );
    await _refreshAfterWrite();
    return result;
  }

  /// Thêm cây — `POST /api/v1/herbal-garden`.
  Future<AddPlantResult> addPlant({
    required String tenLabel,
    DateTime? plantedAt,
    String? stage,
    String? notes,
    double? latitude,
    double? longitude,
    String? addressName,
    String? soilType,
    String? plantingMedium,
    String? doAm,
    String? mauDat,
  }) async {
    final result = await _api.addPlant(
      tenLabel: tenLabel,
      plantedAt: plantedAt,
      stage: stage,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      addressName: addressName,
      soilType: soilType,
      plantingMedium: plantingMedium,
      doAm: doAm,
      mauDat: mauDat,
      uid: _uid,
    );
    if (!result.isDuplicate) await _refreshAfterWrite();
    return result;
  }

  /// Xoá cây (xoá mềm) — `DELETE /{id}`.
  Future<String> deletePlant(String plantId) async {
    final message = await _api.deletePlant(plantId, uid: _uid);
    await _refreshAfterWrite();
    return message;
  }

  /// Khôi phục cây đã xoá — `POST /{id}/restore`.
  Future<String> restorePlant(String plantId) async {
    final message = await _api.restorePlant(plantId, uid: _uid);
    await _refreshAfterWrite();
    return message;
  }

  /// Tải lại sau khi ghi — danh sách + việc hôm nay + cây đã xoá.
  ///
  /// ⚠️ Phải gọi cả `loadDeleted()`: nếu không, sau khi xoá/khôi phục cây thì
  /// màn hình "Cây đã xoá" vẫn hiển thị danh sách cũ (và badge đếm cây đã
  /// xoá trên Hub bị sai).
  Future<void> _refreshAfterWrite() async {
    await Future.wait<void>(<Future<void>>[
      loadPlants(refresh: true),
      loadCare(refresh: true),
      loadDeleted(refresh: true),
    ]);
  }

  /// Tải lại TOÀN BỘ dữ liệu — dùng khi quay lại từ màn con.
  ///
  /// ⚠️ Phải gọi cả `loadDeleted()`: nếu chỉ `loadAll()`, badge "Cây đã xoá" trên
  /// Hub vẫn hiện số cũ sau khi xoá/khôi phục cây.
  ///
  /// [withWeather] = false → không gọi lại thời tiết (tiết kiệm request; thời
  /// tiết thay đổi chậm, không cần tải lại mỗi lần quay lại từ màn con).
  Future<void> refreshAll({bool withWeather = false}) async {
    await Future.wait<void>(<Future<void>>[
      loadPlants(refresh: true),
      loadCare(refresh: true),
      loadDeleted(refresh: true),
      if (withWeather) loadWeather(refresh: true),
    ]);
  }

  // ── Hỗ trợ kiểm thử ─────────────────────────────────────────────────────

  /// Nạp dữ liệu trực tiếp vào state — CHỈ dùng cho widget test.
  ///
  /// Cho phép test dựng giao diện với dữ liệu giả lập mà không cần mock
  /// HTTP layer. Không được gọi từ code production.
  @visibleForTesting
  void applyTestData({
    List<GardenPlantItem>? plants,
    CareToday? care,
    GardenWeather? weather,
    List<DeletedGardenPlant>? deleted,
  }) {
    if (plants != null) _plants = plants;
    if (care != null) _care = care;
    if (weather != null) _weather = weather;
    if (deleted != null) _deleted = deleted;
    _listState = GardenLoadState.ready;
    _careState = GardenLoadState.ready;
    _weatherState = GardenLoadState.ready;
    _deletedState = GardenLoadState.ready;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
