// lib/services/map_cache_service.dart
//
// Cache offline cho bản đồ.
//
// Yêu cầu: "Mất mạng → Load cache + Snackbar đỏ".
// Cache lưu ở SharedPreferences (JSON) vì:
//   • Tồn tại qua các lần mở app (không như biến trong RAM).
//   • Nhẹ, không cần DB.
//   • Đủ để vẽ lại marker đã xem lần trước khi offline.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';

class MapCacheService {
  static const _kCacheKey = 'plant_map_cache_v1';
  static const _kCacheTimeKey = 'plant_map_cache_time_v1';

  /// Lưu danh sách marker (mới nhất ghi đè bản cũ).
  Future<void> saveMarkers(List<PlantMapMarker> markers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = markers.map((m) => m.toCacheJson()).toList();
      await prefs.setString(_kCacheKey, jsonEncode(payload));
      await prefs.setString(_kCacheTimeKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Cache là best-effort → lỗi ghi không được làm crash app.
    }
  }

  /// Đọc cache. Trả về list rỗng nếu chưa có cache hoặc cache hỏng.
  Future<List<PlantMapMarker>> loadMarkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PlantMapMarker.fromCacheJson)
          .where((m) => m.latitude != 0 || m.longitude != 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Thời điểm ghi cache gần nhất (null = chưa có).
  Future<DateTime?> lastSavedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheTimeKey);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      await prefs.remove(_kCacheTimeKey);
    } catch (_) {}
  }
}
