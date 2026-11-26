// lib/features/herbal_garden/models/garden_models.dart
//
// Model Dart cho toàn bộ API "Vườn Dược Liệu" (Herbal Garden).
//
// Nguyên tắc: mọi chuỗi tiếng Việt do backend viết sẵn (title, description,
// message, warning, canh_bao...) đều được hiển thị NGUYÊN VĂN — FE không tự
// diễn giải lại, để app không nói khác với server.
//
// Base URL (Cloud Server): xem [AppConfig.detectUrl].

// ── Mùa vụ ────────────────────────────────────────────────────────────────

class SeasonInfo {
  final bool coMuaVu;
  final String? muaVu;
  final int? thangBatDau;
  final int? thangKetThuc;
  final bool dungMuaHienTai;
  final String? display;
  final String? kyThuHoachToi;
  final bool inSeason;

  const SeasonInfo({
    required this.coMuaVu,
    this.muaVu,
    this.thangBatDau,
    this.thangKetThuc,
    required this.dungMuaHienTai,
    this.display,
    this.kyThuHoachToi,
    required this.inSeason,
  });

  factory SeasonInfo.fromJson(Map<String, dynamic> j) => SeasonInfo(
    coMuaVu: j['co_mua_vu'] ?? false,
    muaVu: j['mua_vu'],
    thangBatDau: j['thang_bat_dau'],
    thangKetThuc: j['thang_ket_thuc'],
    dungMuaHienTai: j['dung_mua_hien_tai'] ?? false,
    display: j['display'],
    kyThuHoachToi: j['ky_thu_hoach_toi'],
    inSeason: j['in_season'] ?? false,
  );

  /// Nhãn chip rút gọn.
  String get chipLabel =>
      !coMuaVu ? 'Chưa có lịch mùa vụ' : (inSeason ? 'Đúng mùa' : 'Ngoài mùa');
}

// ── Loại đất & nơi trồng (Đợt 3) ──────────────────────────────────────────

class SoilInfo {
  final String? soilType;
  final String? soilLabel;
  final String? soilSource;
  final String? plantingMedium;
  final String? plantingMediumLabel;
  final int waterAdjustDays;
  final String? soilWarning;

  const SoilInfo({
    this.soilType,
    this.soilLabel,
    this.soilSource,
    this.plantingMedium,
    this.plantingMediumLabel,
    this.waterAdjustDays = 0,
    this.soilWarning,
  });

  factory SoilInfo.fromJson(Map<String, dynamic> j) => SoilInfo(
    soilType: j['soil_type'],
    soilLabel: j['soil_label'],
    soilSource: j['soil_source'],
    plantingMedium: j['planting_medium'],
    plantingMediumLabel: j['planting_medium_label'],
    waterAdjustDays: j['water_adjust_days'] ?? 0,
    soilWarning: j['soil_warning'],
  );

  bool get hasWarning => (soilWarning ?? '').isNotEmpty;

  /// Đất do người dùng tự xác nhận (không phải hệ thống gợi ý).
  bool get isUserConfirmed => soilSource == 'user';
}

// ── Giai đoạn sinh trưởng ─────────────────────────────────────────────────

/// 5 giai đoạn hợp lệ — khớp 100% với server.
const List<String> kGardenStages = <String>[
  'gieo_trong',
  'dang_lon',
  'ra_hoa',
  'san_sang_thu_hoach',
  'da_thu_hoach',
];

/// Nhãn tiếng Việt của giai đoạn (server cũng trả `stage_label` — ưu tiên
/// giá trị từ server, bảng này chỉ là fallback).
const Map<String, String> kGardenStageLabels = <String, String>{
  'gieo_trong': 'Mới gieo',
  'dang_lon': 'Đang lớn',
  'ra_hoa': 'Ra hoa',
  'san_sang_thu_hoach': 'Sẵn sàng thu hoạch',
  'da_thu_hoach': 'Đã thu hoạch',
};

// ── Thông tin dược liệu ───────────────────────────────────────────────────

class BotanicalInfo {
  final String tenLabel;
  final String? tenCay;
  final String? tenQuocte;
  final String? thongTin;
  final String? congDung;
  final String? cachDung;
  final String? luuYo;
  final String? imageUrl;
  final bool toxicLookalike;
  final bool safetyReviewed;

  const BotanicalInfo({
    required this.tenLabel,
    this.tenCay,
    this.tenQuocte,
    this.thongTin,
    this.congDung,
    this.cachDung,
    this.luuYo,
    this.imageUrl,
    required this.toxicLookalike,
    required this.safetyReviewed,
  });

  factory BotanicalInfo.fromJson(Map<String, dynamic> j) => BotanicalInfo(
    tenLabel: j['ten_label'] ?? '',
    tenCay: j['ten_cay'],
    tenQuocte: j['ten_quocte'],
    thongTin: j['thong_tin'],
    congDung: j['cong_dung'],
    cachDung: j['cach_dung'],
    luuYo: j['luu_y'],
    imageUrl: j['image_url'],
    toxicLookalike: j['toxic_lookalike'] ?? false,
    safetyReviewed: j['safety_reviewed'] ?? false,
  );
}

// ── GPS ───────────────────────────────────────────────────────────────────

class GpsPoint {
  final double? latitude;
  final double? longitude;
  final String? addressName;

  const GpsPoint({this.latitude, this.longitude, this.addressName});

  factory GpsPoint.fromJson(Map<String, dynamic> j) => GpsPoint(
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    addressName: j['address_name'],
  );

  bool get hasCoords =>
      latitude != null && longitude != null && addressName != null;
}

// ── Lịch sử mốc thời gian ──────────────────────────────────────────────────

class StageHistoryEntry {
  final String stage;
  final String label;
  final DateTime? at;
  final String? note;

  const StageHistoryEntry({
    required this.stage,
    required this.label,
    this.at,
    this.note,
  });

  factory StageHistoryEntry.fromJson(Map<String, dynamic> j) =>
      StageHistoryEntry(
        stage: j['stage'] ?? '',
        label: j['label'] ?? '',
        at: j['at'] == null ? null : DateTime.tryParse(j['at'].toString()),
        note: j['note'],
      );
}

// ── Ảnh nhật ký tiến độ ───────────────────────────────────────────────────

class TimelineImage {
  final String id;
  final String? url;
  final String? urlRelative;
  final String? note;
  final String? stage;
  final String? stageLabel;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final String? addressName;

  const TimelineImage({
    required this.id,
    this.url,
    this.urlRelative,
    this.note,
    this.stage,
    this.stageLabel,
    this.capturedAt,
    this.latitude,
    this.longitude,
    this.addressName,
  });

  factory TimelineImage.fromJson(Map<String, dynamic> j) => TimelineImage(
    id: j['id']?.toString() ?? '',
    url: j['url'],
    urlRelative: j['url_relative'],
    note: j['note'],
    stage: j['stage'],
    stageLabel: j['stage_label'],
    capturedAt: j['captured_at'] == null
        ? null
        : DateTime.tryParse(j['captured_at'].toString()),
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    addressName: j['address_name'],
  );
}

// ── Sổ thu hoạch ──────────────────────────────────────────────────────────

class HarvestRecord {
  final String id;
  final DateTime? harvestedAt;
  final double? weightKg;
  final bool inSeason;
  final String? seasonLabel;
  final String? warning;
  final String? note;
  final double? activeRatio;

  const HarvestRecord({
    required this.id,
    this.harvestedAt,
    this.weightKg,
    required this.inSeason,
    this.seasonLabel,
    this.warning,
    this.note,
    this.activeRatio,
  });

  factory HarvestRecord.fromJson(Map<String, dynamic> j) => HarvestRecord(
    id: j['id']?.toString() ?? '',
    harvestedAt: j['harvested_at'] == null
        ? null
        : DateTime.tryParse(j['harvested_at'].toString()),
    weightKg: (j['weight_kg'] as num?)?.toDouble(),
    inSeason: j['in_season'] ?? false,
    seasonLabel: j['season_label'],
    warning: j['warning'],
    note: j['note'],
    activeRatio: (j['active_ratio'] as num?)?.toDouble(),
  );

  String get qualityLabel {
    final ratio = activeRatio;
    if (ratio == null) return 'Không đánh giá được chất lượng';
    if (ratio >= 1.0) return 'Đúng mùa · hoạt chất 100%';
    return 'Ngoài mùa · hoạt chất ${(ratio * 100).round()}%';
  }
}

// ── Đánh giá sinh trưởng (Đợt 4) ─────────────────────────────────────────
// ⚠️ KHÔNG phải kết quả AI nhìn ảnh — suy ra từ dữ liệu người dùng nhập.
class GrowthInfo {
  final String mucDo;
  final String nhanDien;
  final int soNgayTrong;
  final int soAnh;
  final bool daQuaMucKyVong;
  final String? goiYa;

  const GrowthInfo({
    required this.mucDo,
    required this.nhanDien,
    required this.soNgayTrong,
    required this.soAnh,
    required this.daQuaMucKyVong,
    this.goiYa,
  });

  factory GrowthInfo.fromJson(Map<String, dynamic> j) => GrowthInfo(
    mucDo: j['muc_do'] ?? 'binh_thuong',
    nhanDien: j['nhan_dien'] ?? '',
    soNgayTrong: j['so_ngay_trong'] ?? 0,
    soAnh: j['so_anh'] ?? 0,
    daQuaMucKyVong: j['da_qua_muc_ky_vong'] ?? false,
    goiYa: j['goi_ya'],
  );

  bool get isWarning => mucDo == 'canh_bao' || daQuaMucKyVong;
}

// ── Cây trong vườn (danh sách) ────────────────────────────────────────────

class GardenPlantItem {
  final String id;
  final String tenLabel;
  final String? tenCay;
  final String? tenQuocte;
  final String? imageUrl;
  final DateTime? plantedAt;
  final String stage;
  final String stageLabel;
  final int? daysSincePlanted;
  final SeasonInfo? season;
  final bool canChamSocHomNay;
  final List<String> trangThaiChamSoc;
  final int soAnhTimeline;
  final int soLanThuHoach;
  final double tongKhoiLuongThuHoachKg;
  final DateTime? lastWateredAt;
  final int soLanTuoi;
  final SoilInfo? soil;

  const GardenPlantItem({
    required this.id,
    required this.tenLabel,
    this.tenCay,
    this.tenQuocte,
    this.imageUrl,
    this.plantedAt,
    required this.stage,
    required this.stageLabel,
    this.daysSincePlanted,
    this.season,
    required this.canChamSocHomNay,
    required this.trangThaiChamSoc,
    required this.soAnhTimeline,
    required this.soLanThuHoach,
    required this.tongKhoiLuongThuHoachKg,
    this.lastWateredAt,
    this.soLanTuoi = 0,
    this.soil,
  });

  factory GardenPlantItem.fromJson(Map<String, dynamic> j) => GardenPlantItem(
    id: j['id']?.toString() ?? '',
    tenLabel: j['ten_label']?.toString() ?? '',
    tenCay: j['ten_cay'],
    tenQuocte: j['ten_quocte'],
    imageUrl: j['image_url'],
    plantedAt: j['planted_at'] == null
        ? null
        : DateTime.tryParse(j['planted_at'].toString()),
    stage: j['stage']?.toString() ?? 'gieo_trong',
    stageLabel: j['stage_label']?.toString() ?? 'Mới gieo',
    daysSincePlanted: j['days_since_planted'],
    season: j['season'] == null
        ? null
        : SeasonInfo.fromJson(j['season'] as Map<String, dynamic>),
    canChamSocHomNay: j['can_cham_soc_hom_nay'] ?? false,
    trangThaiChamSoc: List<String>.from(j['trang_thai_cham_soc'] ?? const []),
    soAnhTimeline: j['so_anh_timeline'] ?? 0,
    soLanThuHoach: j['so_lan_thu_hoach'] ?? 0,
    tongKhoiLuongThuHoachKg:
        (j['tong_khoi_luong_thu_hoach_kg'] as num?)?.toDouble() ?? 0,
    lastWateredAt: j['last_watered_at'] == null
        ? null
        : DateTime.tryParse(j['last_watered_at'].toString()),
    soLanTuoi: j['so_lan_tuoi'] ?? 0,
    soil: j['soil'] == null
        ? null
        : SoilInfo.fromJson(j['soil'] as Map<String, dynamic>),
  );

  String get displayName => (tenCay ?? tenLabel).trim();
}

// ── Chi tiết 1 cây ─────────────────────────────────────────────────────────

class GardenPlantDetail extends GardenPlantItem {
  final String? notes;
  final String? nhomCay;
  final String? nhomCayLabel;
  final int? soNgayThuHoach;
  final int? kyCatTia;
  final String? ghiChuMuaVu;
  final BotanicalInfo? botanical;
  final List<GpsPoint> locations;
  final List<StageHistoryEntry> stageHistory;
  final List<TimelineImage> timelineImages;
  final List<HarvestRecord> harvestHistory;
  final List<String> canhBao;
  final GrowthInfo? growth;
  final DateTime? ngayChupAnhToiNhat;
  final int soNgayTuLanChupAnhCuoi;

  GardenPlantDetail({
    required super.id,
    required super.tenLabel,
    super.tenCay,
    super.tenQuocte,
    super.imageUrl,
    super.plantedAt,
    required super.stage,
    required super.stageLabel,
    super.daysSincePlanted,
    super.season,
    required super.canChamSocHomNay,
    required super.trangThaiChamSoc,
    required super.soAnhTimeline,
    required super.soLanThuHoach,
    required super.tongKhoiLuongThuHoachKg,
    super.lastWateredAt,
    super.soLanTuoi = 0,
    super.soil,
    this.notes,
    this.nhomCay,
    this.nhomCayLabel,
    this.soNgayThuHoach,
    this.kyCatTia,
    this.ghiChuMuaVu,
    this.botanical,
    required this.locations,
    required this.stageHistory,
    required this.timelineImages,
    required this.harvestHistory,
    required this.canhBao,
    this.growth,
    this.ngayChupAnhToiNhat,
    this.soNgayTuLanChupAnhCuoi = 0,
  });

  factory GardenPlantDetail.fromJson(Map<String, dynamic> j) =>
      GardenPlantDetail(
        id: j['id']?.toString() ?? '',
        tenLabel: j['ten_label']?.toString() ?? '',
        tenCay: j['ten_cay'],
        tenQuocte: j['ten_quocte'],
        imageUrl: j['image_url'],
        plantedAt: j['planted_at'] == null
            ? null
            : DateTime.tryParse(j['planted_at'].toString()),
        stage: j['stage']?.toString() ?? 'gieo_trong',
        stageLabel: j['stage_label']?.toString() ?? 'Mới gieo',
        daysSincePlanted: j['days_since_planted'],
        season: j['season'] == null
            ? null
            : SeasonInfo.fromJson(j['season'] as Map<String, dynamic>),
        canChamSocHomNay: j['can_cham_soc_hom_nay'] ?? false,
        trangThaiChamSoc: List<String>.from(
          j['trang_thai_cham_soc'] ?? const [],
        ),
        soAnhTimeline: j['so_anh_timeline'] ?? 0,
        soLanThuHoach: j['so_lan_thu_hoach'] ?? 0,
        tongKhoiLuongThuHoachKg:
            (j['tong_khoi_luong_thu_hoach_kg'] as num?)?.toDouble() ?? 0,
        lastWateredAt: j['last_watered_at'] == null
            ? null
            : DateTime.tryParse(j['last_watered_at'].toString()),
        soLanTuoi: j['so_lan_tuoi'] ?? 0,
        soil: j['soil'] == null
            ? null
            : SoilInfo.fromJson(j['soil'] as Map<String, dynamic>),
        notes: j['notes'],
        nhomCay: j['nhom_cay'],
        nhomCayLabel: j['nhom_cay_label'],
        soNgayThuHoach: j['so_ngay_thu_hoach'],
        kyCatTia: j['ky_cat_tia'],
        ghiChuMuaVu: j['ghi_chu_mua_vu'],
        botanical: j['botanical'] == null
            ? null
            : BotanicalInfo.fromJson(j['botanical'] as Map<String, dynamic>),
        locations: (j['locations'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GpsPoint.fromJson)
            .toList(),
        stageHistory: (j['stage_history'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StageHistoryEntry.fromJson)
            .toList(),
        timelineImages: (j['timeline_images'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TimelineImage.fromJson)
            .toList(),
        harvestHistory: (j['harvest_history'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(HarvestRecord.fromJson)
            .toList(),
        canhBao: List<String>.from(j['canh_bao'] ?? const []),
        growth: j['growth'] == null
            ? null
            : GrowthInfo.fromJson(j['growth'] as Map<String, dynamic>),
        ngayChupAnhToiNhat: j['ngay_chup_anh_toi_nhat'] == null
            ? null
            : DateTime.tryParse(j['ngay_chup_anh_toi_nhat'].toString()),
        soNgayTuLanChupAnhCuoi: j['so_ngay_tu_lan_chup_anh_cuoi'] ?? 0,
      );
}

// ── Việc chăm sóc hôm nay ────────────────────────────────────────────────

class TaskChoice {
  final String id;
  final String label;
  final String? moTa;
  final String? canhBao;

  const TaskChoice({
    required this.id,
    required this.label,
    this.moTa,
    this.canhBao,
  });

  factory TaskChoice.fromJson(Map<String, dynamic> j) => TaskChoice(
    id: j['id']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    moTa: j['mo_ta'],
    canhBao: j['canh_bao'],
  );
}

class CareTask {
  final String plantId;
  final String tenLabel;
  final String? tenCay;
  final String? imageUrl;
  final String taskType;
  final String title;
  final String? description;
  final String priority;
  final DateTime? dueAt;
  final String? stage;
  final String? stageLabel;
  final SeasonInfo? season;
  final List<String> huongDan;
  final List<TaskChoice> luaChon;
  final bool coTheDismiss;

  const CareTask({
    required this.plantId,
    required this.tenLabel,
    this.tenCay,
    this.imageUrl,
    required this.taskType,
    required this.title,
    this.description,
    required this.priority,
    this.dueAt,
    this.stage,
    this.stageLabel,
    this.season,
    this.huongDan = const [],
    this.luaChon = const [],
    this.coTheDismiss = false,
  });

  factory CareTask.fromJson(Map<String, dynamic> j) => CareTask(
    plantId: j['plant_id']?.toString() ?? '',
    tenLabel: j['ten_label']?.toString() ?? '',
    tenCay: j['ten_cay'],
    imageUrl: j['image_url'],
    taskType: j['task_type']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    description: j['description'],
    priority: j['priority']?.toString() ?? 'normal',
    dueAt: j['due_at'] == null
        ? null
        : DateTime.tryParse(j['due_at'].toString()),
    stage: j['stage'],
    stageLabel: j['stage_label'],
    season: j['season'] == null
        ? null
        : SeasonInfo.fromJson(j['season'] as Map<String, dynamic>),
    huongDan: List<String>.from(j['huong_dan'] ?? const []),
    luaChon: (j['lua_chon'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TaskChoice.fromJson)
        .toList(),
    coTheDismiss: j['co_the_dismiss'] ?? false,
  );

  String get displayName => (tenCay ?? tenLabel).trim();
}

class CareToday {
  final String uid;
  final String date;
  final int total;
  final int soCanTuoi;
  final int soDenKyCatTia;
  final int soNgoaiMua;
  final int soSanSangThuHoach;
  final int soBoRoi;
  final int soCoTheChet;
  final int soNhacChupAnh;
  final int soChuaNayMam;
  final List<CareTask> tasks;

  const CareToday({
    required this.uid,
    required this.date,
    required this.total,
    required this.soCanTuoi,
    required this.soDenKyCatTia,
    required this.soNgoaiMua,
    required this.soSanSangThuHoach,
    required this.soBoRoi,
    required this.soCoTheChet,
    required this.soNhacChupAnh,
    required this.soChuaNayMam,
    required this.tasks,
  });

  factory CareToday.fromJson(Map<String, dynamic> j) => CareToday(
    uid: j['uid']?.toString() ?? '',
    date: j['date']?.toString() ?? '',
    total: j['total'] ?? 0,
    soCanTuoi: j['so_can_tuoi'] ?? 0,
    soDenKyCatTia: j['so_den_ky_cat_tia'] ?? 0,
    soNgoaiMua: j['so_ngoai_mua'] ?? 0,
    soSanSangThuHoach: j['so_san_sang_thu_hoach'] ?? 0,
    soBoRoi: j['so_bo_roi'] ?? 0,
    soCoTheChet: j['so_co_the_chet'] ?? 0,
    soNhacChupAnh: j['so_nhac_chup_anh'] ?? 0,
    soChuaNayMam: j['so_chua_nay_mam'] ?? 0,
    tasks: (j['tasks'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CareTask.fromJson)
        .toList(),
  );

  static CareToday empty() => const CareToday(
    uid: '',
    date: '',
    total: 0,
    soCanTuoi: 0,
    soDenKyCatTia: 0,
    soNgoaiMua: 0,
    soSanSangThuHoach: 0,
    soBoRoi: 0,
    soCoTheChet: 0,
    soNhacChupAnh: 0,
    soChuaNayMam: 0,
    tasks: [],
  );
}

// ── Thời tiết ─────────────────────────────────────────────────────────────

class WeatherDay {
  final String date;
  final double? rainMm;
  final double? tempMax;
  final double? tempMin;

  const WeatherDay({
    required this.date,
    this.rainMm,
    this.tempMax,
    this.tempMin,
  });

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
    date: j['date']?.toString() ?? '',
    rainMm: (j['rain_mm'] as num?)?.toDouble(),
    tempMax: (j['temp_max'] as num?)?.toDouble(),
    tempMin: (j['temp_min'] as num?)?.toDouble(),
  );
}

class GardenWeather {
  final bool ok;
  final double? temperature;
  final int? humidity;
  final double? rainMm;
  final double? windSpeed;
  final double? uvIndex;
  final int? weatherCode;
  final String? weatherText;
  final String? lyDo;
  final String? source;
  final String? region;
  final bool? canTuoi;
  final List<WeatherDay> daily;

  const GardenWeather({
    required this.ok,
    this.temperature,
    this.humidity,
    this.rainMm,
    this.windSpeed,
    this.uvIndex,
    this.weatherCode,
    this.weatherText,
    this.lyDo,
    this.source,
    this.region,
    this.canTuoi,
    this.daily = const [],
  });

  factory GardenWeather.fromJson(Map<String, dynamic> j) => GardenWeather(
    ok: j['ok'] ?? false,
    temperature: (j['temperature'] as num?)?.toDouble(),
    humidity: j['humidity'],
    rainMm: (j['rain_mm'] as num?)?.toDouble(),
    windSpeed: (j['wind_speed'] as num?)?.toDouble(),
    uvIndex: (j['uv_index'] as num?)?.toDouble(),
    weatherCode: j['weather_code'],
    weatherText: j['weather_text'],
    lyDo: j['ly_do'],
    source: j['source'],
    region: j['region'],
    canTuoi: j['can_tuoi'],
    daily: (j['daily'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WeatherDay.fromJson)
        .toList(),
  );

  /// Nhãn nguồn toạ độ (tiếng Việt, hiển thị nhỏ dưới widget thời tiết).
  String get sourceLabel {
    switch (source) {
      case 'toa_do_nguoi_dung':
        return 'Vị trí của bạn';
      case 'gps_anh_chup':
        return 'Vị trí chụp ảnh';
      case 'gps_cua_cay':
        return 'Vị trí cây';
      default:
        return region ?? 'Vùng mặc định';
    }
  }

  /// Icon gợi ý theo mã thời tiết WMO (mã 0..99).
  static int weatherIcon(int? code) {
    if (code == null) return 0;
    if (code == 0) return 1; // ☀️ quang
    if (code == 1) return 2; // 🌤️
    if (code == 2) return 3; // ⛅
    if (code == 3) return 4; // ☁️
    if (code == 45 || code == 48) return 5; // 🌫️ sương mù
    if (code >= 51 && code <= 57) return 6; // 🌦️ mưa phùn
    if (code >= 61 && code <= 67) return 7; // 🌧️ mưa
    if (code >= 71 && code <= 77) return 8; // ❄️ tuyết
    if (code >= 80 && code <= 82) return 9; // 🌦️ mưa rào
    if (code >= 85 && code <= 86) return 8; // ❄️ tuyết rào
    if (code >= 95) return 10; // ⛈️ giông
    return 4;
  }
}

// ── Cây đã xoá (soft delete) ──────────────────────────────────────────────

class DeletedGardenPlant {
  final String id;
  final String? tenLabel;
  final String? tenCay;
  final String? imageUrl;
  final String? stage;
  final DateTime? plantedAt;
  final DateTime? deletedAt;
  final int soAnhTimeline;
  final int soLanThuHoach;

  const DeletedGardenPlant({
    required this.id,
    this.tenLabel,
    this.tenCay,
    this.imageUrl,
    this.stage,
    this.plantedAt,
    this.deletedAt,
    this.soAnhTimeline = 0,
    this.soLanThuHoach = 0,
  });

  factory DeletedGardenPlant.fromJson(Map<String, dynamic> j) =>
      DeletedGardenPlant(
        id: j['id']?.toString() ?? '',
        tenLabel: j['ten_label'],
        tenCay: j['ten_cay'],
        imageUrl: j['image_url'],
        stage: j['stage'],
        plantedAt: j['planted_at'] == null
            ? null
            : DateTime.tryParse(j['planted_at'].toString()),
        deletedAt: j['deleted_at'] == null
            ? null
            : DateTime.tryParse(j['deleted_at'].toString()),
        soAnhTimeline: j['so_anh_timeline'] ?? 0,
        soLanThuHoach: j['so_lan_thu_hoach'] ?? 0,
      );

  String get displayName => (tenCay ?? tenLabel ?? 'Cây đã xoá').trim();
}

// ── Bộ lựa chọn loại đất ─────────────────────────────────────────────────

class SoilTypeOption {
  final String code;
  final String label;
  final String? shortLabel;
  final String? description;
  final String? waterHint;
  final String? phAdvice;
  final String? mucDo;

  const SoilTypeOption({
    required this.code,
    required this.label,
    this.shortLabel,
    this.description,
    this.waterHint,
    this.phAdvice,
    this.mucDo,
  });

  factory SoilTypeOption.fromJson(Map<String, dynamic> j) => SoilTypeOption(
    code: j['code']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    shortLabel: j['short_label'],
    description: j['description'],
    waterHint: j['water_hint'],
    phAdvice: j['ph_advice'],
    mucDo: j['muc_do'],
  );
}

class PlantingMediumOption {
  final String code;
  final String label;
  final String? description;

  const PlantingMediumOption({
    required this.code,
    required this.label,
    this.description,
  });

  factory PlantingMediumOption.fromJson(Map<String, dynamic> j) =>
      PlantingMediumOption(
        code: j['code']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        description: j['description'],
      );
}

class SoilSymptomOption {
  final String code;
  final String label;
  final String? hint;

  const SoilSymptomOption({required this.code, required this.label, this.hint});

  factory SoilSymptomOption.fromJson(Map<String, dynamic> j) =>
      SoilSymptomOption(
        code: j['code']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        hint: j['hint'],
      );
}

class SoilSymptomQuestion {
  final String key;
  final String question;
  final String? hint;
  final List<SoilSymptomOption> options;

  const SoilSymptomQuestion({
    required this.key,
    required this.question,
    this.hint,
    required this.options,
  });

  factory SoilSymptomQuestion.fromJson(Map<String, dynamic> j) =>
      SoilSymptomQuestion(
        key: j['key']?.toString() ?? '',
        question: j['question']?.toString() ?? '',
        hint: j['hint'],
        options: (j['options'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SoilSymptomOption.fromJson)
            .toList(),
      );
}

class SoilSymptomMapping {
  final String doAm;
  final String mauDat;
  final String soilType;
  final String soilLabel;

  const SoilSymptomMapping({
    required this.doAm,
    required this.mauDat,
    required this.soilType,
    required this.soilLabel,
  });

  factory SoilSymptomMapping.fromJson(Map<String, dynamic> j) =>
      SoilSymptomMapping(
        doAm: j['do_am']?.toString() ?? '',
        mauDat: j['mau_dat']?.toString() ?? '',
        soilType: j['soil_type']?.toString() ?? '',
        soilLabel: j['soil_label']?.toString() ?? '',
      );
}

class SoilOptions {
  final List<SoilTypeOption> soilTypes;
  final List<PlantingMediumOption> plantingMedia;
  final List<SoilSymptomQuestion> symptomQuestions;
  final List<SoilSymptomMapping> symptomToSoil;

  const SoilOptions({
    this.soilTypes = const [],
    this.plantingMedia = const [],
    this.symptomQuestions = const [],
    this.symptomToSoil = const [],
  });

  factory SoilOptions.fromJson(Map<String, dynamic> j) => SoilOptions(
    soilTypes: (j['soil_types'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SoilTypeOption.fromJson)
        .toList(),
    plantingMedia: (j['planting_media'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlantingMediumOption.fromJson)
        .toList(),
    symptomQuestions: (j['symptom_questions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SoilSymptomQuestion.fromJson)
        .toList(),
    symptomToSoil: (j['symptom_to_soil'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SoilSymptomMapping.fromJson)
        .toList(),
  );

  /// Tra bảng ánh xạ 2 triệu chứng → mã loại đất.
  String? soilTypeForSymptoms({required String doAm, required String mauDat}) {
    for (final m in symptomToSoil) {
      if (m.doAm == doAm && m.mauDat == mauDat) return m.soilType;
    }
    return null;
  }

  SoilTypeOption? soilTypeByCode(String? code) {
    if (code == null) return null;
    for (final s in soilTypes) {
      if (s.code == code) return s;
    }
    return null;
  }
}

// ── Gợi ý loại đất cho 1 loài cây ─────────────────────────────────────────

class SoilSuggestion {
  final String? tenLabel;
  final String? tenCay;
  final String? soilType;
  final String? soilLabel;
  final String confidence;
  final String? reason;
  final String? habitatSoil;
  final String? habitatSoilLabel;
  final List<String> matchedKeywords;

  const SoilSuggestion({
    this.tenLabel,
    this.tenCay,
    this.soilType,
    this.soilLabel,
    this.confidence = 'none',
    this.reason,
    this.habitatSoil,
    this.habitatSoilLabel,
    this.matchedKeywords = const [],
  });

  factory SoilSuggestion.fromJson(Map<String, dynamic> j) => SoilSuggestion(
    tenLabel: j['ten_label'],
    tenCay: j['ten_cay'],
    soilType: j['soil_type'],
    soilLabel: j['soil_label'],
    confidence: j['confidence']?.toString() ?? 'none',
    reason: j['reason'],
    habitatSoil: j['habitat_soil'],
    habitatSoilLabel: j['habitat_soil_label'],
    matchedKeywords: List<String>.from(j['matched_keywords'] ?? const []),
  );

  bool get hasSuggestion => (soilType ?? '').isNotEmpty;
}

// ── Kết quả tìm trong danh mục dược liệu ─────────────────────────────────

class CatalogPlant {
  final String plantId;
  final String commonName;
  final String? scientificName;
  final String? imageUrl;
  final String? confidence;
  final String? safetyWarning;
  final bool toxicLookalike;

  const CatalogPlant({
    required this.plantId,
    required this.commonName,
    this.scientificName,
    this.imageUrl,
    this.confidence,
    this.safetyWarning,
    required this.toxicLookalike,
  });

  factory CatalogPlant.fromJson(Map<String, dynamic> j) => CatalogPlant(
    plantId: j['plant_id']?.toString() ?? '',
    commonName: j['common_name']?.toString() ?? '',
    scientificName: j['scientific_name'],
    imageUrl: j['image_url'],
    confidence: j['confidence']?.toString(),
    safetyWarning: j['safety_warning'],
    toxicLookalike: j['toxic_lookalike'] ?? false,
  );

  /// "95.46%" → 0.9546 (null nếu không có — kết quả search không có %).
  double? get confidenceValue {
    final raw = confidence;
    if (raw == null) return null;
    final parsed = double.tryParse(raw.replaceAll('%', '').trim());
    if (parsed == null) return null;
    return parsed / 100.0;
  }
}

// ── Kết quả nhận diện từ POST /predict ───────────────────────────────────

class PlantPrediction {
  final String plantId;
  final String commonName;
  final String? scientificName;
  final String? confidence;
  final String? imageUrl;
  final String? source;
  final String? safetyWarning;
  final bool toxicLookalike;

  const PlantPrediction({
    required this.plantId,
    required this.commonName,
    this.scientificName,
    this.confidence,
    this.imageUrl,
    this.source,
    this.safetyWarning,
    required this.toxicLookalike,
  });

  factory PlantPrediction.fromJson(Map<String, dynamic> j) => PlantPrediction(
    plantId: j['plant_id']?.toString() ?? '',
    commonName: j['common_name']?.toString() ?? '',
    scientificName: j['scientific_name'],
    confidence: j['confidence']?.toString(),
    imageUrl: j['image_url'],
    source: j['source'],
    safetyWarning: j['safety_warning'],
    toxicLookalike: j['toxic_lookalike'] ?? false,
  );

  double? get confidenceValue {
    final raw = confidence;
    if (raw == null) return null;
    final parsed = double.tryParse(raw.replaceAll('%', '').trim());
    if (parsed == null) return null;
    return parsed / 100.0;
  }

  /// Kết quả chỉ mang tính tham khảo (không chắc chắn 100%).
  ///
  /// Nguồn phụ (`secondary_resolver`) hoặc độ tin cậy thấp → cần nói rõ với
  /// người dùng là "gợi ý tham khảo", KHÔNG nói tới tên model/kỹ thuật.
  bool get isReferenceOnly =>
      source == 'secondary_resolver' || (confidenceValue ?? 1.0) < 0.6;

  /// Cảnh báo ngắn gọn, thân thiện — thay thế cho chuỗi cảnh báo dài dòng
  /// của server (chứa thuật ngữ kỹ thuật như "mô hình phụ", "AI model").
  ///
  /// ⚠️ Chỉ hiện cảnh báo NGUY HIỂM THẬT SỰ (loài độc / look-alike độc).
  /// Mọi cảnh báo khác → thông báo "chỉ là tham khảo".
  String? get friendlyWarning {
    if (toxicLookalike) {
      return 'Loài này có cây trông giống gây ĐỘC trong tự nhiên. '
          'Hãy thận trọng khi nhận diện và sử dụng.';
    }
    if (isReferenceOnly) {
      return 'Kết quả này chỉ là tham khảo. Bạn có muốn chọn cây này không?';
    }
    return null;
  }
}

class PredictResult {
  final String status;
  final List<PlantPrediction> predictions;
  final String? message;
  final String? safetyWarning;
  final bool? imageQualityOk;

  const PredictResult({
    required this.status,
    required this.predictions,
    this.message,
    this.safetyWarning,
    this.imageQualityOk,
  });

  factory PredictResult.fromJson(Map<String, dynamic> j) => PredictResult(
    status: j['status']?.toString() ?? 'unknown',
    predictions: (j['predictions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlantPrediction.fromJson)
        .toList(),
    message: j['message'],
    safetyWarning: j['safety_warning'],
    imageQualityOk: j['image_quality_ok'],
  );

  bool get canAddToGarden => status != 'unknown';
}
