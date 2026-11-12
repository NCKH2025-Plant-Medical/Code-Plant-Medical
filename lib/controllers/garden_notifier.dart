// lib/controllers/garden_notifier.dart
//
// State management cho chức năng Vườn Dược Liệu.
//
// Dùng ChangeNotifier + Provider, đồng bộ với AuthNotifier sẵn có của app.
//
// Nguyên tắc: mọi thông báo / cảnh báo đều lấy NGUYÊN VĂN từ server
// (`message`, `warning`, `detail`) — không tự diễn giải lại.

import 'package:flutter/foundation.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/services/herbal_garden_api.dart';

enum GardenStatus { idle, loading, ready, error }

class GardenNotifier extends ChangeNotifier {
  GardenNotifier({HerbalGardenApi? api}) : _api = api ?? HerbalGardenApi();

  final HerbalGardenApi _api;

  // ── State ────────────────────────────────────────────────────────────────

  GardenStatus _status = GardenStatus.idle;
  GardenStatus get status => _status;

  String? _error;
  String? get error => _error;

  List<GardenPlantItem> _plants = const [];
  List<GardenPlantItem> get plants => _plants;

  CareToday? _careToday;
  CareToday? get careToday => _careToday;

  GardenWeather? _weather;
  GardenWeather? get weather => _weather;

  double _totalHarvestKg = 0;
  double get totalHarvestKg => _totalHarvestKg;

  /// UID dùng cho request — gán từ bên ngoài (theo account đang đăng nhập).
  String? _uid;

  /// UID thực tế sẽ gửi lên server (xem [_effectiveUid]).
  String get uid => _effectiveUid;

  /// UID cuối cùng sẽ gửi lên server.
  ///
  /// Ưu tiên:
  ///  1. UID riêng của account (đặt qua [setUid]) — chỉ dùng khi bật chế độ
  ///     vườn riêng (`GARDEN_PER_USER=true`).
  ///  2. [AppConfig.gardenUid] — mặc định `'demo'`, dùng vườn mẫu có sẵn
  ///     5 cây đa dạng trạng thái để demo đầy đủ mọi chip & badge.
  String get _effectiveUid {
    if (AppConfig.gardenPerUser) {
      final u = _uid;
      if (u != null && u.isNotEmpty) return u;
    }
    return AppConfig.gardenUid;
  }

  void setUid(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Tải song song 3 nguồn dữ liệu: danh sách cây, việc hôm nay, thời tiết.
  ///
  /// Server không cache → mỗi lần gọi `care-today` đều trả trạng thái mới.
  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      _status = GardenStatus.loading;
      _error = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait<dynamic>([
        _api.listGarden(uid: _effectiveUid),
        _api.careToday(uid: _effectiveUid),
        _api.weather(),
      ]);

      _plants = results[0] as List<GardenPlantItem>;
      _careToday = results[1] as CareToday;
      _weather = results[2] as GardenWeather;
      _totalHarvestKg = _plants.fold<double>(
        0,
        (sum, p) => sum + p.tongKhoiLuongThuHoachKg,
      );
      _status = GardenStatus.ready;
      _error = null;
    } catch (e) {
      _status = GardenStatus.error;
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  /// Làm mới — chỉ cập nhật dữ liệu, không bật full-screen loading
  /// (để người dùng không mất màn hình đang xem).
  Future<void> refresh() => load(showLoading: false);

  // ── Hành động trên thẻ việc ─────────────────────────────────────────────

  /// Ghi nhận đã tưới — `POST /{id}/water`.
  Future<String> water(String plantId, {String? note}) async {
    final message = await _api.waterPlant(plantId, note: note, uid: _effectiveUid);
    await refresh();
    return message;
  }

  /// Gỡ thẻ việc — `POST /{id}/task/dismiss`.
  Future<String> dismiss(CareTask task, {String? choice}) async {
    final message = await _api.dismissTask(
      task.plantId,
      taskType: task.taskType,
      choice: choice,
      uid: _effectiveUid,
    );
    await refresh();
    return message;
  }

  /// Đổi mốc giai đoạn — `POST /{id}/stage`.
  ///
  /// Đổi mốc cũng được tính là "đã chăm sóc cây" → gỡ task `tuoi` và cảnh
  /// báo bị bỏ rơi.
  Future<String> updateStage(
    String plantId,
    String stage, {
    String? note,
  }) async {
    final message = await _api.updateStage(
      plantId,
      stage,
      note: note,
      uid: _effectiveUid,
    );
    await refresh();
    return message;
  }

  /// Ghi sổ thu hoạch — `POST /{id}/harvest`.
  Future<HarvestRecord> harvest(
    String plantId, {
    DateTime? harvestedAt,
    double? weightKg,
    String? note,
  }) async {
    final record = await _api.harvest(
      plantId,
      harvestedAt: harvestedAt,
      weightKg: weightKg,
      note: note,
      uid: _effectiveUid,
    );
    await refresh();
    return record;
  }

  /// Xoá cây (xoá mềm) — `DELETE /{id}`.
  Future<String> deletePlant(String plantId) async {
    final message = await _api.deletePlant(plantId, uid: _effectiveUid);
    await refresh();
    return message;
  }

  /// Khôi phục cây đã xoá — `POST /{id}/restore`.
  Future<String> restorePlant(String plantId) async {
    final message = await _api.restorePlant(plantId, uid: _effectiveUid);
    await refresh();
    return message;
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
