// lib/models/herbal_garden.dart
//
// Model Dart cho chức năng Vườn Dược Liệu (Herbal Garden).
//
// Hợp đồng dữ liệu: xem
//   BAN_GIAO_FRONTEND_VUON_DUOC_LIEU.md — Mục 4 (response thật từ server).
//
// Nguyên tắc: mọi chuỗi tiếng Việt do backend viết sẵn (message, warning,
// canh_bao, description, huong_dan, lua_chon) → FE CHỈ HIỂN THỊ NGUYÊN VĂN,
// không diễn giải lại, để app không nói khác với server.

import 'package:flutter/material.dart';

// ── Mùa vụ ─────────────────────────────────────────────────────────────────

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

  /// Nhãn chip mùa vụ — dùng nguyên văn `display` của server.
  String get chipLabel => !coMuaVu
      ? 'Chưa có lịch mùa vụ'
      : (inSeason ? 'Đúng mùa' : 'Ngoài mùa');

  Color get chipColor {
    if (!coMuaVu) return const Color(0xFF9AA5A1);
    return inSeason ? const Color(0xFF2D6A4F) : const Color(0xFFB45309);
  }
}

// ── GPS ────────────────────────────────────────────────────────────────────

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

  bool get hasCoordinate => latitude != null && longitude != null;
}

// ── Thông tin dược liệu ────────────────────────────────────────────────────

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

// ── Mốc giai đoạn ──────────────────────────────────────────────────────────

class StageInfo {
  final String stage;
  final String label;
  final DateTime? at;
  final String? note;

  const StageInfo({
    required this.stage,
    required this.label,
    this.at,
    this.note,
  });

  factory StageInfo.fromJson(Map<String, dynamic> j) => StageInfo(
        stage: j['stage'] ?? '',
        label: j['label'] ?? '',
        at: j['at'] == null ? null : DateTime.tryParse(j['at'].toString()),
        note: j['note'],
      );
}

// ── Ảnh nhật ký tiến độ ────────────────────────────────────────────────────

class TimelineImage {
  final String id;
  final String? url;
  final String? urlRelative;
  final String? note;
  final String? stage;
  final String? stageLabel;
  final DateTime? capturedAt;
  // Đợt 5 — GPS tại thời điểm chụp (vị trí người dùng đang trồng cây).
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
        id: j['id'] ?? '',
        url: j['url'],
        urlRelative: j['url_relative'],
        note: j['note'],
        stage: j['stage'],
        stageLabel: j['stage_label'],
        capturedAt:
            j['captured_at'] == null ? null : DateTime.tryParse(j['captured_at'].toString()),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        addressName: j['address_name'],
      );

  bool get hasGps => latitude != null && longitude != null;
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
        id: j['id'] ?? '',
        harvestedAt:
            j['harvested_at'] == null ? null : DateTime.tryParse(j['harvested_at'].toString()),
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        inSeason: j['in_season'] ?? false,
        seasonLabel: j['season_label'],
        warning: j['warning'],
        note: j['note'],
        activeRatio: (j['active_ratio'] as num?)?.toDouble(),
      );

  /// Nhãn chất lượng theo `active_ratio` (Mục 4 — A8).
  String get qualityLabel {
    final ratio = activeRatio;
    if (ratio == null) return 'Không đánh giá được';
    if (ratio >= 1.0) return 'Đúng mùa · hoạt chất 100%';
    return 'Ngoài mùa · hoạt chất ${(ratio * 100).round()}%';
  }

  Color get qualityColor {
    final ratio = activeRatio;
    if (ratio == null) return const Color(0xFF9AA5A1);
    if (ratio >= 1.0) return const Color(0xFF2D6A4F);
    if (ratio >= 0.6) return const Color(0xFFB45309);
    return const Color(0xFFB45309);
  }
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

  /// Đất người dùng đã xác nhận (không phải do hệ thống gợi ý).
  bool get isUserConfirmed => soilSource == 'user';

  bool get hasWarning => (soilWarning ?? '').isNotEmpty;
}

class SoilOption {
  final String code;
  final String label;
  final String? shortLabel;
  final String? description;
  final String? waterHint;
  final String? phAdvice;
  final String? mucDo;

  const SoilOption({
    required this.code,
    required this.label,
    this.shortLabel,
    this.description,
    this.waterHint,
    this.phAdvice,
    this.mucDo,
  });

  factory SoilOption.fromJson(Map<String, dynamic> j) => SoilOption(
        code: j['code'] ?? '',
        label: j['label'] ?? '',
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
        code: j['code'] ?? '',
        label: j['label'] ?? '',
        description: j['description'],
      );
}

class SymptomOption {
  final String code;
  final String label;
  final String? hint;

  const SymptomOption({required this.code, required this.label, this.hint});

  factory SymptomOption.fromJson(Map<String, dynamic> j) => SymptomOption(
        code: j['code'] ?? '',
        label: j['label'] ?? '',
        hint: j['hint'],
      );
}

class SymptomQuestion {
  final String key;
  final String question;
  final String? hint;
  final List<SymptomOption> options;

  const SymptomQuestion({
    required this.key,
    required this.question,
    this.hint,
    required this.options,
  });

  factory SymptomQuestion.fromJson(Map<String, dynamic> j) => SymptomQuestion(
        key: j['key'] ?? '',
        question: j['question'] ?? '',
        hint: j['hint'],
        options: ((j['options'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(SymptomOption.fromJson)
            .toList(),
      );
}

/// Bộ lựa chọn loại đất tĩnh — trả về từ `GET /soil-options`.
class SoilOptions {
  final List<SoilOption> soilTypes;
  final List<PlantingMediumOption> plantingMedia;
  final List<SymptomQuestion> symptomQuestions;
  final Map<String, String> symptomToSoil;

  const SoilOptions({
    required this.soilTypes,
    required this.plantingMedia,
    required this.symptomQuestions,
    required this.symptomToSoil,
  });

  factory SoilOptions.fromJson(Map<String, dynamic> j) {
    final map = <String, String>{};
    for (final e in (j['symptom_to_soil'] ?? []) as List) {
      if (e is Map) {
        final doAm = e['do_am'];
        final mauDat = e['mau_dat'];
        final soil = e['soil_type'];
        if (doAm != null && mauDat != null && soil != null) {
          map['$doAm|$mauDat'] = soil.toString();
        }
      }
    }
    return SoilOptions(
      soilTypes: ((j['soil_types'] ?? []) as List)
          .whereType<Map<String, dynamic>>()
          .map(SoilOption.fromJson)
          .toList(),
      plantingMedia: ((j['planting_media'] ?? []) as List)
          .whereType<Map<String, dynamic>>()
          .map(PlantingMediumOption.fromJson)
          .toList(),
      symptomQuestions: ((j['symptom_questions'] ?? []) as List)
          .whereType<Map<String, dynamic>>()
          .map(SymptomQuestion.fromJson)
          .toList(),
      symptomToSoil: map,
    );
  }
}

/// Gợi ý loại đất cho 1 loài cây — `GET /soil-suggestion`.
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
        confidence: j['confidence'] ?? 'none',
        reason: j['reason'],
        habitatSoil: j['habitat_soil'],
        habitatSoilLabel: j['habitat_soil_label'],
        matchedKeywords:
            List<String>.from(j['matched_keywords'] ?? const []).cast<String>(),
      );

  bool get hasSuggestion => (soilType ?? '').isNotEmpty;
}

// ── Đánh giá sinh trưởng (Đợt 4) ───────────────────────────────────────────
//
// ⚠️ KHÔNG phải kết quả AI nhìn ảnh — suy ra từ dữ liệu người dùng nhập
// (ngày gieo, số ảnh, mốc giai đoạn, lần tưới) đối chiếu chu kỳ sinh trưởng.

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
        goiYa: j['goi_y'],
      );

  bool get isWarning => mucDo == 'canh_bao' || daQuaMucKyVong;
}

// ── Cây trong vườn ─────────────────────────────────────────────────────────

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
    this.soil,
  });

  factory GardenPlantItem.fromJson(Map<String, dynamic> j) => GardenPlantItem(
        id: j['id'] ?? '',
        tenLabel: j['ten_label'] ?? '',
        tenCay: j['ten_cay'],
        tenQuocte: j['ten_quocte'],
        imageUrl: j['image_url'],
        plantedAt:
            j['planted_at'] == null ? null : DateTime.tryParse(j['planted_at'].toString()),
        stage: j['stage'] ?? 'gieo_trong',
        stageLabel: j['stage_label'] ?? 'Mới gieo',
        daysSincePlanted: j['days_since_planted'],
        season: j['season'] == null ? null : SeasonInfo.fromJson(j['season']),
        canChamSocHomNay: j['can_cham_soc_hom_nay'] ?? false,
        trangThaiChamSoc: List<String>.from(j['trang_thai_cham_soc'] ?? const []),
        soAnhTimeline: j['so_anh_timeline'] ?? 0,
        soLanThuHoach: j['so_lan_thu_hoach'] ?? 0,
        tongKhoiLuongThuHoachKg:
            (j['tong_khoi_luong_thu_hoach_kg'] as num?)?.toDouble() ?? 0,
        soil: j['soil'] == null ? null : SoilInfo.fromJson(j['soil']),
      );
}

class GardenPlantDetail extends GardenPlantItem {
  final String? notes;
  final String? nhomCayLabel;
  final String? ghiChuMuaVu;
  final int? soNgayThuHoach;
  final int? kyCatTia;
  final BotanicalInfo? botanical;
  final List<GpsPoint> locations;
  final List<StageInfo> stageHistory;
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
    super.soil,
    this.notes,
    this.nhomCayLabel,
    this.ghiChuMuaVu,
    this.soNgayThuHoach,
    this.kyCatTia,
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
        id: j['id'] ?? '',
        tenLabel: j['ten_label'] ?? '',
        tenCay: j['ten_cay'],
        tenQuocte: j['ten_quocte'],
        imageUrl: j['image_url'],
        plantedAt:
            j['planted_at'] == null ? null : DateTime.tryParse(j['planted_at'].toString()),
        stage: j['stage'] ?? 'gieo_trong',
        stageLabel: j['stage_label'] ?? 'Mới gieo',
        daysSincePlanted: j['days_since_planted'],
        season: j['season'] == null ? null : SeasonInfo.fromJson(j['season']),
        canChamSocHomNay: j['can_cham_soc_hom_nay'] ?? false,
        trangThaiChamSoc: List<String>.from(j['trang_thai_cham_soc'] ?? const []),
        soAnhTimeline: j['so_anh_timeline'] ?? 0,
        soLanThuHoach: j['so_lan_thu_hoach'] ?? 0,
        tongKhoiLuongThuHoachKg:
            (j['tong_khoi_luong_thu_hoach_kg'] as num?)?.toDouble() ?? 0,
        soil: j['soil'] == null ? null : SoilInfo.fromJson(j['soil']),
        notes: j['notes'],
        nhomCayLabel: j['nhom_cay_label'],
        ghiChuMuaVu: j['ghi_chu_mua_vu'],
        soNgayThuHoach: j['so_ngay_thu_hoach'],
        kyCatTia: j['ky_cat_tia'],
        botanical:
            j['botanical'] == null ? null : BotanicalInfo.fromJson(j['botanical']),
        locations: ((j['locations'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(GpsPoint.fromJson)
            .toList(),
        stageHistory: ((j['stage_history'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(StageInfo.fromJson)
            .toList(),
        timelineImages: ((j['timeline_images'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(TimelineImage.fromJson)
            .toList(),
        harvestHistory: ((j['harvest_history'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(HarvestRecord.fromJson)
            .toList(),
        canhBao: List<String>.from(j['canh_bao'] ?? const []),
        growth: j['growth'] == null ? null : GrowthInfo.fromJson(j['growth']),
        ngayChupAnhToiNhat: j['ngay_chup_anh_toi_nhat'] == null
            ? null
            : DateTime.tryParse(j['ngay_chup_anh_toi_nhat'].toString()),
        soNgayTuLanChupAnhCuoi: j['so_ngay_tu_lan_chup_anh_cuoi'] ?? 0,
      );
}

// ── Task chăm sóc ──────────────────────────────────────────────────────────

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
        id: j['id'] ?? '',
        label: j['label'] ?? '',
        moTa: j['mo_ta'],
        canhBao: j['canh_bao'],
      );
}

class CareTask {
  final String plantId;
  final String tenLabel;
  final String tenCay;
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
    required this.tenCay,
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
        plantId: j['plant_id'] ?? '',
        tenLabel: j['ten_label'] ?? '',
        tenCay: j['ten_cay'] ?? '',
        imageUrl: j['image_url'],
        taskType: j['task_type'] ?? '',
        title: j['title'] ?? '',
        description: j['description'],
        priority: j['priority'] ?? 'normal',
        dueAt: j['due_at'] == null ? null : DateTime.tryParse(j['due_at'].toString()),
        stage: j['stage'],
        stageLabel: j['stage_label'],
        season: j['season'] == null ? null : SeasonInfo.fromJson(j['season']),
        huongDan: List<String>.from(j['huong_dan'] ?? const []),
        luaChon: ((j['lua_chon'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(TaskChoice.fromJson)
            .toList(),
        coTheDismiss: j['co_the_dismiss'] ?? false,
      );

  /// Task bắt buộc — không dùng nút "Đã xong".
  bool get isMandatory => taskType == 'tuoi' || taskType == 'thu_hoach';
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
    required this.tasks,
    this.soNhacChupAnh = 0,
    this.soChuaNayMam = 0,
  });

  factory CareToday.fromJson(Map<String, dynamic> j) => CareToday(
        uid: j['uid'] ?? '',
        date: j['date'] ?? '',
        total: j['total'] ?? 0,
        soCanTuoi: j['so_can_tuoi'] ?? 0,
        soDenKyCatTia: j['so_den_ky_cat_tia'] ?? 0,
        soNgoaiMua: j['so_ngoai_mua'] ?? 0,
        soSanSangThuHoach: j['so_san_sang_thu_hoach'] ?? 0,
        soBoRoi: j['so_bo_roi'] ?? 0,
        soCoTheChet: j['so_co_the_chet'] ?? 0,
        soNhacChupAnh: j['so_nhac_chup_anh'] ?? 0,
        soChuaNayMam: j['so_chua_nay_mam'] ?? 0,
        tasks: ((j['tasks'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(CareTask.fromJson)
            .toList(),
      );
}

// ── Thời tiết ─────────────────────────────────────────────────────────────

class WeatherDay {
  final String date;
  final double? rainMm;
  final double? tempMax;
  final double? tempMin;

  const WeatherDay({required this.date, this.rainMm, this.tempMax, this.tempMin});

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
        date: j['date'] ?? '',
        rainMm: (j['rain_mm'] as num?)?.toDouble(),
        tempMax: (j['temp_max'] as num?)?.toDouble(),
        tempMin: (j['temp_min'] as num?)?.toDouble(),
      );
}

class GardenWeather {
  final bool ok;
  final double? temperature;
  final double? rainMm;
  final double? windSpeed;
  final double? uvIndex;
  final int? humidity;
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
    this.rainMm,
    this.windSpeed,
    this.uvIndex,
    this.humidity,
    this.weatherCode,
    this.weatherText,
    this.lyDo,
    this.source,
    this.region,
    this.canTuoi,
    required this.daily,
  });

  factory GardenWeather.fromJson(Map<String, dynamic> j) => GardenWeather(
        ok: j['ok'] ?? false,
        temperature: (j['temperature'] as num?)?.toDouble(),
        rainMm: (j['rain_mm'] as num?)?.toDouble(),
        windSpeed: (j['wind_speed'] as num?)?.toDouble(),
        uvIndex: (j['uv_index'] as num?)?.toDouble(),
        humidity: j['humidity'],
        weatherCode: j['weather_code'],
        weatherText: j['weather_text'],
        lyDo: j['ly_do'],
        source: j['source'],
        region: j['region'],
        canTuoi: j['can_tuoi'],
        daily: ((j['daily'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(WeatherDay.fromJson)
            .toList(),
      );

  /// Nhãn nguồn toạ độ — hiển thị nhỏ dưới ô thời tiết.
  String get sourceLabel => switch (source) {
        'toa_do_nguoi_dung' => 'Vị trí của bạn',
        'gps_anh_chup' => 'Vị trí ảnh chụp',
        'gps_cua_cay' => 'Vị trí cây',
        _ => region ?? 'Miền Bắc',
      };
}

// ── Kết quả nhận diện (POST /predict) ─────────────────────────────────────

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
        plantId: j['plant_id'] ?? '',
        commonName: j['common_name'] ?? '',
        scientificName: j['scientific_name'],
        // ⚠️ `confidence` là STRING ("95.46%"), không phải number.
        confidence: j['confidence']?.toString(),
        imageUrl: j['image_url'],
        source: j['source'],
        safetyWarning: j['safety_warning'],
        toxicLookalike: j['toxic_lookalike'] ?? false,
      );

  /// Parse "95.46%" → 0.9546 ; null nếu không có.
  double? get confidenceValue {
    final raw = confidence;
    if (raw == null) return null;
    final parsed = double.tryParse(raw.replaceAll('%', '').trim());
    if (parsed == null) return null;
    return parsed > 1 ? parsed / 100 : parsed;
  }
}

class PredictResult {
  /// "success" | "uncertain" | "unknown"
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
        status: j['status'] ?? 'unknown',
        predictions: ((j['predictions'] ?? []) as List)
            .whereType<Map<String, dynamic>>()
            .map(PlantPrediction.fromJson)
            .toList(),
        message: j['message'],
        safetyWarning: j['safety_warning'],
        imageQualityOk: j['image_quality_ok'],
      );

  bool get canAddToGarden => status == 'success' || status == 'uncertain';
}

// ── Cây đã xoá ─────────────────────────────────────────────────────────────

class DeletedPlantItem {
  final String id;
  final String? tenCay;
  final String? tenLabel;
  final String? imageUrl;
  final String? stageLabel;
  final DateTime? plantedAt;
  final DateTime? deletedAt;
  final int soAnhTimeline;
  final int soLanThuHoach;

  const DeletedPlantItem({
    required this.id,
    this.tenCay,
    this.tenLabel,
    this.imageUrl,
    this.stageLabel,
    this.plantedAt,
    this.deletedAt,
    this.soAnhTimeline = 0,
    this.soLanThuHoach = 0,
  });

  factory DeletedPlantItem.fromJson(Map<String, dynamic> j) => DeletedPlantItem(
        id: j['id'] ?? '',
        tenCay: j['ten_cay'],
        tenLabel: j['ten_label'],
        imageUrl: j['image_url'],
        stageLabel: j['stage_label'],
        plantedAt:
            j['planted_at'] == null ? null : DateTime.tryParse(j['planted_at'].toString()),
        deletedAt:
            j['deleted_at'] == null ? null : DateTime.tryParse(j['deleted_at'].toString()),
        soAnhTimeline: j['so_anh_timeline'] ?? 0,
        soLanThuHoach: j['so_lan_thu_hoach'] ?? 0,
      );
}
