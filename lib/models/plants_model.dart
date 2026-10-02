class PlantPrediction {
  final String plantId;
  final String commonName;
  final String scientificName; // 1. Khai báo thêm biến
  final double confidence; // 0..100
  final String? imageUrl;

  const PlantPrediction({
    required this.plantId,
    required this.commonName,
    required this.scientificName, // 2. Thêm vào constructor
    required this.confidence,
    this.imageUrl,
  });

  factory PlantPrediction.fromJson(Map<String, dynamic> json) {
    return PlantPrediction(
      plantId: json['plant_id']?.toString() ?? '',
      commonName: json['common_name']?.toString() ?? 'Không xác định',
      scientificName: json['scientific_name']?.toString() ?? 'Không xác định',
      confidence: _parseConfidence(json['confidence']),
      imageUrl: json['image_url']?.toString(),
    );
  }

  /// Parses the whole response safely. Never throws; returns [] on bad data.
  static List<PlantPrediction> listFrom(Map<String, dynamic> result) {
    final raw = result['predictions'];
    if (raw is! List) return [];
    final list = raw
        .whereType<Map>()
        .map((e) => PlantPrediction.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.plantId.isNotEmpty)
        .toList();
    list.sort((a, b) => b.confidence.compareTo(a.confidence));
    return list;
  }

  // Server sends "99.99%" as a String, so strip the % before parsing.
  static double _parseConfidence(dynamic v) {
    if (v is num) return v.toDouble().clamp(0, 100);
    final s = v?.toString().replaceAll('%', '').trim() ?? '';
    return (double.tryParse(s) ?? 0).clamp(0, 100).toDouble();
  }

  // Đã cập nhật hiển thị chính xác 2 chữ số thập phân
  String get confidenceLabel {
    // Chuyển double thành chuỗi
    String strValue = confidence.toString();
    int dotIndex = strValue.indexOf('.');

    // Nếu có dấu thập phân và phần thập phân dài hơn 2 chữ số -> Cắt chuỗi
    if (dotIndex != -1 && strValue.length > dotIndex + 3) {
      strValue = strValue.substring(0, dotIndex + 3);
    }

    // Ép kiểu ngược lại và dùng toStringAsFixed(2) để đảm bảo luôn có đủ 2 số
    // (Ví dụ: 99.0 -> 99.00%)
    return '${double.parse(strValue).toStringAsFixed(2)}%';
  }
}