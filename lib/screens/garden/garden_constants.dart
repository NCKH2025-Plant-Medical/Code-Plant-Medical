// lib/screens/garden/garden_constants.dart
//
// Hằng số & quy tắc hiển thị cho Vườn Dược Liệu.
//
// Nguồn: BAN_GIAO_FRONTEND_VUON_DUOC_LIEU.md — Mục 5.2, 5.3, 5.4, 6.1, 6.2.

import 'package:flutter/material.dart';

/// 5 giai đoạn sinh trưởng hợp lệ — khớp với server.
const List<String> kGardenStages = <String>[
  'gieo_trong',
  'dang_lon',
  'ra_hoa',
  'san_sang_thu_hoach',
  'da_thu_hoach',
];

/// Nhãn tiếng Việt của 5 giai đoạn (fallback khi server không trả stage_label).
const Map<String, String> kStageLabels = <String, String>{
  'gieo_trong': 'Mới gieo',
  'dang_lon': 'Đang lớn',
  'ra_hoa': 'Ra hoa',
  'san_sang_thu_hoach': 'Sẵn sàng thu hoạch',
  'da_thu_hoach': 'Đã thu hoạch',
};

/// Icon + màu của 5 giai đoạn.
IconData stageIcon(String stage) => switch (stage) {
      'gieo_trong' => Icons.eco_rounded,
      'dang_lon' => Icons.grass_rounded,
      'ra_hoa' => Icons.local_florist_rounded,
      'san_sang_thu_hoach' => Icons.emoji_events_rounded,
      'da_thu_hoach' => Icons.check_circle_rounded,
      _ => Icons.eco_rounded,
    };

Color stageColor(String stage) => switch (stage) {
      'gieo_trong' => const Color(0xFF2D6A4F),
      'dang_lon' => const Color(0xFFB08900),
      'ra_hoa' => const Color(0xFFC2185B),
      'san_sang_thu_hoach' => const Color(0xFFE07A00),
      'da_thu_hoach' => const Color(0xFF6C757D),
      _ => const Color(0xFF2D6A4F),
    };

/// Icon cho `task_type` — Mục 5.3.
IconData taskIcon(String type) => switch (type) {
      'tuoi' => Icons.water_drop_rounded,
      'cat_tia' => Icons.content_cut_rounded,
      'ngoai_mua' => Icons.event_rounded,
      'thu_hoach' => Icons.grass_rounded,
      'bo_roi' => Icons.bedtime_rounded,
      'co_the_chet' => Icons.warning_amber_rounded,
      'chup_anh' => Icons.photo_camera_rounded,
      'nay_mam' => Icons.spa_rounded,
      _ => Icons.check_circle_outline_rounded,
    };

/// Nhãn ngắn cho `task_type`.
String taskShortLabel(String type) => switch (type) {
      'tuoi' => 'Tưới nước',
      'cat_tia' => 'Cắt tỉa',
      'ngoai_mua' => 'Ngoài mùa',
      'thu_hoach' => 'Đến kỳ thu hoạch',
      'bo_roi' => 'Bị bỏ rơi',
      'co_the_chet' => 'Có thể đã chết',
      'chup_anh' => 'Chụp ảnh tiến độ',
      'nay_mam' => 'Có thể chưa nảy mầm',
      _ => '',
    };

/// Màu viền thẻ theo `priority` — Mục 6.1.
Color taskPriorityColor(String priority) => switch (priority) {
      'high' => const Color(0xFFDC2626),
      'normal' => const Color(0xFFD97706),
      _ => const Color(0xFF9AA5A1),
    };

/// Badge gộp trên card cây — Mục 6.2.
const Map<String, (String, IconData)> kCareBadges = <String, (String, IconData)>{
  'tuoi': ('💧', Icons.water_drop_rounded),
  'cat_tia': ('✂️', Icons.content_cut_rounded),
  'ngoai_mua': ('📅', Icons.event_rounded),
  'thu_hoach': ('🌾', Icons.grass_rounded),
  'bo_roi': ('😴', Icons.bedtime_rounded),
  'co_the_chet': ('💀', Icons.warning_amber_rounded),
  'chup_anh': ('📸', Icons.photo_camera_rounded),
  'nay_mam': ('🌱', Icons.spa_rounded),
};

/// Bảng mã thời tiết WMO → icon — Mục 5.4.
IconData weatherIcon(int? code) {
  if (code == null) return Icons.cloud_outlined;
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code == 1) return Icons.wb_cloudy_rounded;
  if (code == 2) return Icons.cloud_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code >= 45 && code <= 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.grain_rounded;
  if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud_outlined;
}

/// Định dạng ngày kiểu Việt Nam — dd/MM/yyyy.
String formatVnDate(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Định dạng ngày giờ kiểu Việt Nam — dd/MM/yyyy HH:mm.
String formatVnDateTime(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${formatVnDate(d)} · $hh:$mm';
}

/// Màu banner theo nội dung `canh_bao` — Mục 7.1.
///
/// Dùng cờ boolean `botanical.toxic_lookalike` để quyết định banner độc;
/// các trường hợp còn lại suy ra từ nội dung chuỗi do server viết sẵn.
enum GardenBannerKind { danger, warning, info, neutral }

GardenBannerKind classifyBanner(String text, {bool isToxic = false}) {
  if (isToxic) return GardenBannerKind.danger;
  final t = text.toLowerCase();
  if (t.contains('gây độc') || t.contains('có thể đã chết')) {
    return GardenBannerKind.danger;
  }
  if (t.contains('ngoài mùa') ||
      t.contains('không được cập nhật') ||
      t.contains('đất') ||
      t.contains('chưa nảy mầm')) {
    return GardenBannerKind.warning;
  }
  if (t.contains('chưa có dữ liệu mùa vụ')) return GardenBannerKind.neutral;
  return GardenBannerKind.info;
}

Color bannerColor(GardenBannerKind kind) => switch (kind) {
      GardenBannerKind.danger => const Color(0xFFDC2626),
      GardenBannerKind.warning => const Color(0xFFB45309),
      GardenBannerKind.info => const Color(0xFF2D6A4F),
      GardenBannerKind.neutral => const Color(0xFF6C757D),
    };

IconData bannerIcon(GardenBannerKind kind) => switch (kind) {
      GardenBannerKind.danger => Icons.dangerous_rounded,
      GardenBannerKind.warning => Icons.warning_amber_rounded,
      GardenBannerKind.info => Icons.info_outline_rounded,
      GardenBannerKind.neutral => Icons.help_outline_rounded,
    };

/// Màu nền nhạt cho banner.
Color bannerBg(GardenBannerKind kind) => switch (kind) {
      GardenBannerKind.danger => const Color(0xFFFEE2E2),
      GardenBannerKind.warning => const Color(0xFFFEF3C7),
      GardenBannerKind.info => const Color(0xFFE8F4EF),
      GardenBannerKind.neutral => const Color(0xFFF1F3F2),
    };
