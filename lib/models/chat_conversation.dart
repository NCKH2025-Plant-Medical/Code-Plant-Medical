// lib/models/chat_conversation.dart
//
// Model tóm tắt một phiên chat, dùng cho màn hình "Danh sách cuộc trò chuyện".
//
// Backend (`GET /api/v1/chat/conversations`) trả về:
//   {
//     "user_id": "…",
//     "userId": "…",                       // alias camelCase
//     "conversations": [
//       {
//         "conversation_id": "…",
//         "conversationId": "…",           // alias camelCase
//         "title": "Cuộc trò chuyện mới",
//         "last_message": "…",             // có thể null
//         "lastMessage": "…",              // alias camelCase
//         "updated_at": "2026-10-28T23:05:13",
//         "updatedAt": "…",                 // alias camelCase
//         "message_count": 12,
//         "messageCount": 12                // alias camelCase
//       }
//     ]
//   }
//

/// Tóm tắt một phiên hội thoại trong danh sách.
class ChatConversation {
  /// ID phiên — dùng làm `conversation_id` cho endpoint lấy lịch sử.
  final String conversationId;

  /// Tiêu đề phiên (backend tự sinh từ nội dung đầu tiên).
  final String title;

  /// Nội dung tin nhắn cuối cùng — dùng làm mô tả phụ.
  final String? lastMessage;

  /// Thời điểm cập nhật gần nhất (dùng để sắp xếp & hiển thị).
  final DateTime? updatedAt;

  /// Tổng số tin nhắn trong phiên.
  final int messageCount;

  const ChatConversation({
    required this.conversationId,
    required this.title,
    this.lastMessage,
    this.updatedAt,
    this.messageCount = 0,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final rawUpdated =
        _readString(json, 'updated_at', 'updatedAt') ??
        _readString(json, 'created_at', 'createdAt');

    final rawCount = json['message_count'] ?? json['messageCount'];

    return ChatConversation(
      conversationId:
          _readString(json, 'conversation_id', 'conversationId') ?? '',
      title: _readString(json, 'title') ?? 'Cuộc trò chuyện',
      lastMessage: _readString(json, 'last_message', 'lastMessage'),
      updatedAt: rawUpdated == null ? null : DateTime.tryParse(rawUpdated),
      messageCount: rawCount is num ? rawCount.toInt() : 0,
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
