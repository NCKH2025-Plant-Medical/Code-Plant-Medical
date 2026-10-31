// lib/models/chat_message.dart
//
// Model dùng chung cho màn hình chat AI và service ChatBox.
//
// Backend (`/api/v1/chat`) trả về message theo chuẩn:
//   {
//     "id": 338,
//     "client_message_id": "…",
//     "user_id": "…",
//     "conversation_id": "…",
//     "sender": "user" | "bot",
//     "msg_type": "text" | "image" | "error",
//     "text_content": "…",
//     "image_url": "https://…",          // ảnh đã upload lên storage
//     "recognition_data": { … },        // kết quả nhận diện (nếu có)
//     "is_ai_guess": false,
//     "created_at": "2026-10-28T23:05:13"
//   }
//
// Backend trả về CẢ alias snake_case lẫn camelCase cho các field chính,
// nhưng `recognition_data` là object tự do nên parser ở đây chấp nhận cả hai
// để an toàn.

/// Một thẻ kết quả nhận diện cây thuốc.
class PlantResultItem {
  final String plantId;
  final String name;
  final String scientificName;
  final double confidence;
  final String? sampleImage;

  PlantResultItem({
    required this.plantId,
    required this.name,
    required this.scientificName,
    required this.confidence,
    this.sampleImage,
  });

  factory PlantResultItem.fromJson(Map<String, dynamic> json) {
    return PlantResultItem(
      plantId: _readString(json, 'plantId', 'plant_id') ?? '',
      name: _readString(json, 'name') ?? 'Cây chưa xác định',
      scientificName: _readString(json, 'scientificName', 'scientific_name') ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      sampleImage: _readString(json, 'sampleImage', 'sample_image'),
    );
  }
}

/// Một tin nhắn trong cuộc trò chuyện.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  /// Đường dẫn file ảnh CỤC BỘ (chỉ có trong phiên hiện tại).
  final String? imagePath;

  /// URL ảnh trên server (dùng khi nạp lịch sử từ backend).
  final String? imageUrl;

  final bool isAiGuess;
  final String? type; // text, refuse, error, image
  final String? status; // confident, uncertain, unknown
  final List<PlantResultItem>? plantResults;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.imagePath,
    this.imageUrl,
    this.isAiGuess = false,
    this.type = 'text',
    this.status,
    this.plantResults,
  }) : time = time ?? DateTime.now();

  /// Dựng message từ payload của `GET /api/v1/chat/history`.
  factory ChatMessage.fromHistoryJson(Map<String, dynamic> json) {
    final sender = _readString(json, 'sender')?.toLowerCase() ?? '';
    final isUser = sender == 'user' || sender == 'human';

    final type = _readString(json, 'msgType', 'msg_type') ?? 'text';
    final imageUrl = _readString(json, 'imageUrl', 'image_url');

    // `recognition_data` là object tự do — có thể chứa `results` (danh sách
    // thẻ cây) hoặc chính là một thẻ cây đơn lẻ.
    List<PlantResultItem>? plantResults;
    String? status;
    final recognition = json['recognitionData'] ?? json['recognition_data'];
    if (recognition is Map) {
      final rawResults = recognition['results'];
      if (rawResults is List) {
        final items = rawResults
            .whereType<Map<String, dynamic>>()
            .map(PlantResultItem.fromJson)
            .toList();
        if (items.isNotEmpty) plantResults = items;
      } else if (recognition.containsKey('name')) {
        plantResults = [
          PlantResultItem.fromJson(
            recognition.map((k, v) => MapEntry(k.toString(), v)),
          ),
        ];
      }
      final rawStatus = recognition['status']?.toString();
      if (rawStatus != null && rawStatus.isNotEmpty) status = rawStatus;
    }

    final rawTime = _readString(json, 'createdAt', 'created_at');

    return ChatMessage(
      text: _readString(json, 'textContent', 'text_content') ?? '',
      isUser: isUser,
      time: DateTime.tryParse(rawTime ?? '') ?? DateTime.now(),
      imageUrl: imageUrl,
      isAiGuess: json['isAiGuess'] == true || json['is_ai_guess'] == true,
      type: type,
      status: status,
      plantResults: plantResults,
    );
  }
}

/// Đọc field theo thứ tự ưu tiên, hỗ trợ cả alias camelCase/snake_case.
String? _readString(
  Map<String, dynamic> json,
  String primary, [
  String? alias,
]) {
  final value = json[primary] ?? (alias != null ? json[alias] : null);
  if (value == null) return null;
  final str = value.toString();
  return str.isEmpty ? null : str;
}
