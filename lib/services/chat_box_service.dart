// lib/services/chat_box_service.dart
//
// Service cho tính năng ChatBox (hỏi đáp AI).
//
// Hợp đồng API (xem openapi.json của server):
//
// 1) Lấy lịch sử chat:
//    GET {CHAT_URL}/api/v1/chat/history
//        ?conversation_id=<id>   (bắt buộc)
//        &user_id=<id>           (bắt buộc về mặt phân quyền dữ liệu)
//        &before_id=<int>        (cursor phân trang, tuỳ chọn)
//        &limit=<1..50>          (tuỳ chọn, mặc định 20)
//
//    Response 200:
//    {
//      "conversation_id": "…",
//      "messages": [ { "id": 1, "sender": "user"|"bot",
//                      "msg_type": "text"|"image"|"error",
//                      "text_content": "…", "image_url": "…",
//                      "recognition_data": {…}, "is_ai_guess": false,
//                      "created_at": "2026-10-28T23:05:13" } ],
//      "has_more": false,
//      "next_cursor": null
//    }
//
// 2) Xóa lịch sử chat:
//    DELETE {CHAT_URL}/api/v1/chat/session/{conversation_id}?user_id=<id>
//    Response 200: { "success": true, "message": "…" }
//
// ── Lưu trữ theo từng account ───────────────────────────────────────────────
//
// Mỗi account có một `user_id` riêng, dùng làm khoá phân tách dữ liệu ở
// server. `conversation_id` (định danh phiên chat) được lưu cục bộ theo
// `user_id` để khi mở lại app, app biết cần nạp phiên chat nào.
//
// Lưu ý: `conversation_id` là tham số BẮT BUỘC của endpoint history, và
// server không có endpoint "liệt kê các phiên chat" — nên bắt buộc phải lưu
// cục bộ mới khôi phục được lịch sử sau khi tắt app.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/chat_conversation.dart';
import 'package:thunghiem1/models/chat_message.dart';

/// Kết quả một trang lịch sử chat.
class ChatHistoryPage {
  final List<ChatMessage> messages;
  final bool hasMore;
  final int? nextCursor;

  const ChatHistoryPage({
    required this.messages,
    this.hasMore = false,
    this.nextCursor,
  });
}

class ChatBoxService {
  ChatBoxService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => '${AppConfig.chatUrl}/api/v1';

  static const _timeout = Duration(seconds: 20);

  /// Tiền tố key SharedPreferences cho conversation id.
  static const _conversationKeyPrefix = 'pv_chat_conversation_';

  /// Key lưu user id ẩn danh (cho khách chưa đăng nhập).
  static const _anonymousUserKey = 'pv_chat_anonymous_user';

  // ── Danh sách cuộc trò chuyện ────────────────────────────────────────────

  /// Lấy danh sách các phiên chat của người dùng.
  ///
  /// Backend (`GET /api/v1/chat/conversations`) tự lọc theo `user_id`, nên mỗi
  /// account chỉ thấy các phiên của chính mình.
  ///
  /// Tham số `limit` bị server giới hạn trong khoảng 1..100.
  Future<List<ChatConversation>> getConversations({
    required String userId,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/conversations').replace(
      queryParameters: {
        'user_id': userId,
        'limit': limit.clamp(1, 100).toString(),
      },
    );

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được danh sách cuộc trò chuyện (${response.statusCode}).',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return <ChatConversation>[];

    final rawList = decoded['conversations'];
    if (rawList is! List) return <ChatConversation>[];

    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .where((c) => c.conversationId.isNotEmpty)
        .toList();

    // Sắp xếp mới nhất trước (server đã sort sẵn, nhưng đảm bảo lại cho chắc).
    items.sort((a, b) {
      final at = a.updatedAt;
      final bt = b.updatedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return items;
  }

  // ── Tạo cuộc trò chuyện mới ───────────────────────────────────────────────

  /// Tạo một phiên chat mới và trả về thông tin phiên vừa tạo.
  ///
  /// Backend (`POST /api/v1/chat/session/new`) nhận `user_id` và `title` ở
  /// cả query lẫn body — gửi cả hai để tương thích với mọi phiên bản.
  ///
  /// Nếu [title] bị bỏ trống, server tự dùng tiêu đề mặc định
  /// ("Cuộc trò chuyện mới").
  Future<ChatConversation> createConversation({
    required String userId,
    String? title,
  }) async {
    final trimmedTitle = title?.trim();

    final uri = Uri.parse('$_baseUrl/chat/session/new').replace(
      queryParameters: {
        'user_id': userId,
        if (trimmedTitle != null && trimmedTitle.isNotEmpty)
          'title': trimmedTitle,
      },
    );

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'user_id': userId,
            if (trimmedTitle != null && trimmedTitle.isNotEmpty)
              'title': trimmedTitle,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Không tạo được cuộc trò chuyện mới (${response.statusCode}).',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw Exception('Server trả về dữ liệu không hợp lệ.');
    }
    final body = Map<String, dynamic>.from(decoded);

    final conversationId =
        _readString(body, 'conversation_id', 'conversationId') ?? '';
    if (conversationId.isEmpty) {
      throw Exception('Server không trả về mã cuộc trò chuyện.');
    }

    return ChatConversation(
      conversationId: conversationId,
      title: _readString(body, 'title') ??
          (trimmedTitle != null && trimmedTitle.isNotEmpty
              ? trimmedTitle
              : 'Cuộc trò chuyện mới'),
      lastMessage: null,
      updatedAt: DateTime.tryParse(
        _readString(body, 'created_at', 'createdAt') ?? '',
      ),
      messageCount: 0,
    );
  }

  // ── Lịch sử chat ─────────────────────────────────────────────────────────

  /// Lấy lịch sử chat của một phiên.
  ///
  /// Trả về [ChatHistoryPage] rỗng nếu phiên chưa có tin nhắn nào.
  /// Ném [Exception] với message tiếng Việt khi lỗi mạng / server.
  Future<ChatHistoryPage> getHistory({
    required String conversationId,
    required String userId,
    int? beforeId,
    int limit = 50,
  }) async {
    final query = <String, String>{
      'conversation_id': conversationId,
      'user_id': userId,
      'limit': limit.clamp(1, 50).toString(),
    };
    if (beforeId != null) query['before_id'] = beforeId.toString();

    final uri = Uri.parse('$_baseUrl/chat/history').replace(
      queryParameters: query,
    );

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Không tải được lịch sử chat (${response.statusCode}).');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      return const ChatHistoryPage(messages: []);
    }

    final rawMessages = decoded['messages'];
    final items = rawMessages is List
        ? rawMessages
              .whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromHistoryJson)
              .toList()
        : <ChatMessage>[];

    // Server đã sắp xếp tăng dần theo thời gian, nhưng đảm bảo lại để an toàn.
    items.sort((a, b) => a.time.compareTo(b.time));

    final hasMore =
        decoded['has_more'] == true || decoded['hasMore'] == true;
    final rawCursor = decoded['next_cursor'] ?? decoded['nextCursor'];
    final nextCursor = rawCursor is num ? rawCursor.toInt() : null;

    return ChatHistoryPage(
      messages: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  // ── Xóa lịch sử chat ────────────────────────────────────────────────────

  /// Xóa toàn bộ lịch sử chat của một phiên.
  ///
  /// Trả về `true` nếu server xác nhận xóa thành công.
  Future<bool> deleteSession({
    required String conversationId,
    required String userId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/chat/session/$conversationId',
    ).replace(queryParameters: {'user_id': userId});

    final response = await _client
        .delete(uri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Không xóa được lịch sử chat (${response.statusCode}).');
    }

    // Server trả { "success": bool, "message": string }.
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded.containsKey('success')) {
        return decoded['success'] == true;
      }
    } catch (_) {
      // Không parse được → coi như thành công (status 200 đã đủ).
    }
    return true;
  }

  // ── Lưu conversation id theo từng account ───────────────────────────────

  /// Đọc `conversation_id` đã lưu của account [userId].
  ///
  /// Trả về `null` nếu account này chưa từng chat (hoặc đã xóa lịch sử).
  Future<String?> readConversationId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('$_conversationKeyPrefix$userId');
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Lưu `conversation_id` cho account [userId].
  Future<void> saveConversationId(String userId, String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_conversationKeyPrefix$userId', conversationId);
    } catch (_) {
      // Không lưu được cũng không chặn luồng chat.
    }
  }

  /// Xóa `conversation_id` đã lưu của account [userId].
  ///
  /// Gọi sau khi người dùng xóa lịch sử chat — để lần mở app sau app không
  /// cố nạp lại phiên đã bị xóa.
  Future<void> clearConversationId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_conversationKeyPrefix$userId');
    } catch (_) {
      // Bỏ qua.
    }
  }

  // ── User id ẩn danh (khách chưa đăng nhập) ──────────────────────────────

  /// Lấy user id ổn định cho khách chưa đăng nhập.
  ///
  /// Sinh một id ngẫu nhiên lần đầu rồi lưu lại, nhờ vậy lịch sử chat của
  /// khách vẫn được giữ qua các lần mở app trên cùng thiết bị.
  static Future<String> anonymousUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_anonymousUserKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final generated =
          'guest_${DateTime.now().millisecondsSinceEpoch}_'
          '${_stableRandomSuffix()}';
      await prefs.setString(_anonymousUserKey, generated);
      return generated;
    } catch (_) {
      return 'guest_anonymous';
    }
  }

  /// Sinh hậu tố ngẫu nhiên — không cần mật mã hoá, chỉ để id ẩn danh
  /// đủ khác biệt giữa các thiết bị.
  static String _stableRandomSuffix() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(36);
  }

  void dispose() => _client.close();
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
