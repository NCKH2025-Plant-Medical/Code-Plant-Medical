import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/core/image_compress.dart';
import 'package:thunghiem1/models/chat_message.dart';
import 'package:thunghiem1/screens/chat_conversations_screen.dart';
import 'package:thunghiem1/services/chat_box_service.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';

export 'package:thunghiem1/models/chat_message.dart'
    show ChatMessage, PlantResultItem;

// --- SCREEN CHÍNH ---
class ChatAiScreen extends StatefulWidget {
  /// Mã phiên chat cần mở. Nếu `null`, app dùng phiên đã lưu gần nhất
  /// (hoặc tạo phiên mới khi người dùng gửi tin nhắn đầu tiên).
  final String? initialConversationId;

  const ChatAiScreen({super.key, this.initialConversationId});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  static const Color _primary = Color(0xFF1B5E20);
  static const Color _primaryLight = Color(0xFF2E7D32);
  static String get _baseUrl => '${AppConfig.chatUrl}/api/v1';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();
  final ChatBoxService _chatService = ChatBoxService();

  String? _conversationId;

  /// user_id dùng cho API chat — tách biệt theo từng account.
  /// Với khách chưa đăng nhập thì dùng id ẩn danh ổn định theo thiết bị.
  String _userId = 'anonymous';

  bool _isTyping = false;
  bool _hasText = false;

  /// Đang nạp lịch sử chat từ server khi mở màn hình.
  bool _isLoadingHistory = false;

  /// Đã nạp lịch sử xong (kể cả khi không có lịch sử).
  bool _historyLoaded = false;

  /// Đang xoá lịch sử chat.
  bool _isDeleting = false;

  /// Đang nạp thêm tin nhắn cũ hơn (phân trang theo cursor `before_id`).
  bool _isLoadingMore = false;

  /// Còn tin nhắn cũ hơn để nạp không.
  bool _hasMoreHistory = false;

  /// Cursor phân trang — `before_id` cho lần nạp tiếp theo.
  int? _historyCursor;

  /// Số tin nhắn đã nạp từ server.
  int _loadedMessageCount = 0;

  /// Đang tạo cuộc trò chuyện mới.
  bool _isCreatingConversation = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Xin chào! Tôi là Trợ lý AI Plant Vision 🌿\nBạn có thể đặt câu hỏi hoặc gửi ảnh cây để tôi nhận diện và tư vấn nhé!',
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final has = _messageController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    // Nạp lịch sử chat (nếu có) ngay khi mở màn hình.
    _initConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  /// Xác định user_id theo account hiện tại và nạp lịch sử chat.
  ///
  /// - Đã đăng nhập  → dùng `AuthNotifier.userId` (claim `sub` của JWT),
  ///   nhờ vậy lịch sử của mỗi account tách biệt hoàn toàn.
  /// - Chưa đăng nhập → dùng id ẩn danh ổn định theo thiết bị.
  Future<void> _initConversation() async {
    final auth = context.read<AuthNotifier>();

    // Chờ `AuthNotifier.init()` đọc xong token, nếu không `userId` có thể
    // chưa sẵn sàng và ta sẽ gán nhầm id ẩn danh cho tài khoản đã đăng nhập.
    if (!auth.isInitialized) {
      try {
        await auth.ready;
      } catch (_) {
        // Bỏ qua — vẫn tiếp tục với id ẩn danh.
      }
    }
    if (!mounted) return;

    final accountId = auth.userId;
    _userId = accountId ?? await ChatBoxService.anonymousUserId();

    if (!mounted) return;

    setState(() => _isLoadingHistory = true);

    // Ưu tiên phiên được chỉ định từ màn hình danh sách cuộc trò chuyện.
    final requestedId = widget.initialConversationId;

    // Đọc conversation id đã lưu của account này.
    final savedId = requestedId ??
        await _chatService.readConversationId(_userId);
    if (!mounted) return;

    if (savedId != null && savedId.isNotEmpty) {
      _conversationId = savedId;
      try {
        final page = await _chatService.getHistory(
          conversationId: savedId,
          userId: _userId,
          limit: _historyPageSize,
        );
        if (!mounted) return;

        // Thay danh sách cũ (chỉ có lời chào) bằng lịch sử từ server.
        // Nếu server trả về rỗng thì giữ lại lời chào ban đầu.
        setState(() {
          if (page.messages.isNotEmpty) {
            _messages
              ..clear()
              ..addAll(page.messages);
          }
          _loadedMessageCount = page.messages.length;
          _hasMoreHistory = page.hasMore;
          _historyCursor = page.nextCursor;
          _isLoadingHistory = false;
          _historyLoaded = true;
        });
        _scrollToBottom();
        return;
      } catch (_) {
        // Lỗi mạng → vẫn cho user chat tiếp, chỉ không nạp được lịch sử.
        if (!mounted) return;
        setState(() {
          _isLoadingHistory = false;
          _historyLoaded = true;
        });
        return;
      }
    }

    setState(() {
      _isLoadingHistory = false;
      _historyLoaded = true;
    });
  }

  /// Số tin nhắn mỗi trang khi nạp lịch sử.
  static const int _historyPageSize = 20;

  /// Nạp thêm tin nhắn cũ hơn (phân trang theo cursor `before_id`).
  ///
  /// Tin nhắn cũ được chèn vào ĐẦU danh sách để giữ đúng thứ tự thời gian.
  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMoreHistory) return;

    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;

    // Không có cursor → server đã hết dữ liệu.
    final cursor = _historyCursor;
    if (cursor == null) {
      setState(() => _hasMoreHistory = false);
      return;
    }

    setState(() => _isLoadingMore = true);

    // Ghi nhớ vị trí cuộn hiện tại để giữ đúng sau khi chèn tin nhắn cũ.
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    try {
      final page = await _chatService.getHistory(
        conversationId: conversationId,
        userId: _userId,
        beforeId: cursor,
        limit: _historyPageSize,
      );
      if (!mounted) return;

      setState(() {
        if (page.messages.isNotEmpty) {
          // Tin nhắn cũ hơn → chèn vào đầu danh sách.
          _messages.insertAll(0, page.messages);
          _loadedMessageCount += page.messages.length;
        }
        _hasMoreHistory = page.hasMore;
        _historyCursor = page.nextCursor;
        _isLoadingMore = false;
      });

      // Giữ nguyên vị trí đang xem (không nhảy xuống cuối): bù lại phần
      // chiều cao mới được thêm vào đầu danh sách.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final delta =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        final target = (oldOffset + delta).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(target);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMoreHistory = false;
      });
    }
  }

  /// Tạo cuộc trò chuyện mới và bắt đầu phiên đó.
  Future<void> _startNewConversation() async {
    if (_isCreatingConversation) return;

    setState(() => _isCreatingConversation = true);

    try {
      final created = await _chatService.createConversation(userId: _userId);
      if (!mounted) return;

      // Lưu lại phiên hiện tại để lần mở app sau vẫn nạp được.
      await _chatService.saveConversationId(_userId, created.conversationId);
      if (!mounted) return;

      setState(() {
        _conversationId = created.conversationId;
        _messages.clear();
        _messages.add(
          ChatMessage(
            text:
                'Xin chào! Tôi là Trợ lý AI Plant Vision 🌿\n'
                'Bạn có thể đặt câu hỏi hoặc gửi ảnh cây để tôi nhận diện và tư vấn nhé!',
            isUser: false,
          ),
        );
        _loadedMessageCount = 0;
        _hasMoreHistory = false;
        _historyCursor = null;
        _isCreatingConversation = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tạo được cuộc trò chuyện mới: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mở màn hình danh sách các cuộc trò chuyện.
  Future<void> _openConversationsList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatConversationsScreen(),
      ),
    );
    if (!mounted) return;

    // Có thể đã chuyển sang phiên khác → nạp lại lịch sử phiên hiện tại.
    final savedId = await _chatService.readConversationId(_userId);
    if (!mounted) return;
    if (savedId != null && savedId.isNotEmpty && savedId != _conversationId) {
      _conversationId = savedId;
      await _reloadHistory();
    }
  }

  /// Nạp lại lịch sử của phiên hiện tại từ đầu.
  Future<void> _reloadHistory() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;

    setState(() => _isLoadingHistory = true);

    try {
      final page = await _chatService.getHistory(
        conversationId: conversationId,
        userId: _userId,
        limit: _historyPageSize,
      );
      if (!mounted) return;

      setState(() {
        if (page.messages.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(page.messages);
        }
        _loadedMessageCount = page.messages.length;
        _hasMoreHistory = page.hasMore;
        _historyCursor = page.nextCursor;
        _isLoadingHistory = false;
        _historyLoaded = true;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyLoaded = true;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // --- API 1: GỬI TIN NHẮN VĂN BẢN (POST /chat) ---
  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty || _isTyping) return;

    final clientMsgId = _uuid.v4();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': text,
              'conversationId': _conversationId ?? '',
              'userId': _userId,
              'clientMessageId': clientMsgId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newConversationId =
            data['conversationId']?.toString() ?? data['conversation_id']?.toString();
        if (newConversationId != null && newConversationId.isNotEmpty) {
          _conversationId = newConversationId;
          // Lưu lại để mở app sau còn nạp được lịch sử phiên này.
          await _chatService.saveConversationId(_userId, newConversationId);
        }

        final replyText =
            data['reply']?.toString() ?? 'Không nhận được phản hồi.';
        final type = data['type']?.toString() ?? 'text';
        final isAiGuess =
            data['isAiGuess'] == true || data['is_ai_guess'] == true;

        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              text: replyText,
              isUser: false,
              type: type,
              isAiGuess: isAiGuess,
            ),
          );
        });
      } else {
        throw Exception('Server error (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: 'Có sự cố kết nối. Vui lòng thử lại!',
            isUser: false,
            type: 'error',
          ),
        );
      });
    } finally {
      _scrollToBottom();
    }
  }

  // --- API 2: GỬI ẢNH CHỤP CÂY (POST /chat/image) ---
  Future<void> _sendImage(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final compressedPath = await compressImageForUpload(picked.path);
      final clientMsgId = _uuid.v4();

      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Đã gửi một hình ảnh cây thuốc 🌿',
            isUser: true,
            imagePath: compressedPath,
          ),
        );
        _isTyping = true;
      });
      _scrollToBottom();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/chat/image'),
      );
      request.fields['userId'] = _userId;
      request.fields['clientMessageId'] = clientMsgId;
      if (_conversationId != null && _conversationId!.isNotEmpty) {
        request.fields['conversationId'] = _conversationId!;
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', compressedPath),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 40),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newConversationId =
            data['conversationId']?.toString() ?? data['conversation_id']?.toString();
        if (newConversationId != null && newConversationId.isNotEmpty) {
          _conversationId = newConversationId;
          await _chatService.saveConversationId(_userId, newConversationId);
        }

        final status = data['status']?.toString();
        final aiReply =
            data['aiReply']?.toString() ??
            data['ai_reply']?.toString() ??
            data['message']?.toString() ??
            '';

        List<PlantResultItem> plantList = [];
        if (data['results'] is List) {
          plantList = (data['results'] as List)
              .map((item) => PlantResultItem.fromJson(item))
              .toList();
        }

        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              text: aiReply,
              isUser: false,
              status: status,
              plantResults: plantList,
            ),
          );
        });
      } else {
        throw Exception('Server image upload failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: 'Lỗi khi gửi ảnh nhận diện: $e',
            isUser: false,
            type: 'error',
          ),
        );
      });
    } finally {
      _scrollToBottom();
    }
  }

  bool get _isProcessing => _isTyping;

  // --- XÓA LỊCH SỬ CHAT (DELETE /chat/session/{conversation_id}) ---

  /// Mở hộp thoại xác nhận trước khi xóa lịch sử chat.
  ///
  /// Chỉ khi người dùng bấm "Xóa" trong hộp thoại thì mới thực sự xóa.
  Future<void> _confirmDeleteHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Xóa lịch sử chat?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc là muốn xóa toàn bộ lịch sử trò chuyện này không?\n'
          'Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteHistory();
  }

  /// Thực sự xóa lịch sử chat (đã được người dùng xác nhận).
  Future<void> _deleteHistory() async {
    if (_isDeleting) return;

    final conversationId = _conversationId;

    // Chưa có phiên nào trên server → chỉ cần xoá cục bộ.
    if (conversationId == null || conversationId.isEmpty) {
      setState(() {
        _messages.clear();
        _messages.add(
          ChatMessage(
            text: 'Đã xóa lịch sử cuộc trò chuyện. Hãy gửi câu hỏi mới!',
            isUser: false,
          ),
        );
      });
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await _chatService.deleteSession(
        conversationId: conversationId,
        userId: _userId,
      );

      // Xóa luôn conversation id đã lưu, để lần mở app sau không nạp
      // lại phiên đã bị xóa.
      await _chatService.clearConversationId(_userId);

      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _conversationId = null;
        _messages.clear();
        _messages.add(
          ChatMessage(
            text: 'Đã xóa lịch sử cuộc trò chuyện. Hãy gửi câu hỏi mới!',
            isUser: false,
          ),
        );
        _loadedMessageCount = 0;
        _hasMoreHistory = false;
        _historyCursor = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa lịch sử chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F7F5),
      appBar: _buildAppBar(colorScheme, isDark),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingHistory
                  ? const _HistoryLoadingView()
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      // +1 cho nút "tải tin nhắn cũ hơn" ở đầu danh sách.
                      itemCount:
                          _messages.length +
                          (_isTyping ? 1 : 0) +
                          (_hasMoreHistory ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Hàng đầu: nút tải thêm tin nhắn cũ hơn.
                        if (_hasMoreHistory && index == 0) {
                          return _buildLoadMoreRow(colorScheme, isDark);
                        }

                        // Hàng cuối: bong bóng "đang gõ".
                        final messageIndex = index - (_hasMoreHistory ? 1 : 0);
                        if (messageIndex == _messages.length) {
                          return const _TypingBubble();
                        }
                        return _MessageBubble(
                          message: _messages[messageIndex],
                        );
                      },
                    ),
            ),
            _buildInputBar(colorScheme, isDark),
          ],
        ),
      ),
    );
  }

  /// Hàng nút "tải tin nhắn cũ hơn" — hiển thị ở đầu danh sách tin nhắn.
  Widget _buildLoadMoreRow(ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: _isLoadingMore
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : OutlinedButton.icon(
                onPressed: _loadMoreHistory,
                icon: const Icon(Icons.history_rounded, size: 17),
                label: Text('Xem tin nhắn cũ hơn ($_loadedMessageCount)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryLight,
                  side: BorderSide(
                    color: _primaryLight.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme, bool isDark) {
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
        child: BackNavButton(onPressed: () => Navigator.pop(context)),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AiAvatar(size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hỏi đáp AI',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Mở danh sách các cuộc trò chuyện.
        IconButton(
          icon: const Icon(Icons.forum_outlined),
          tooltip: 'Danh sách cuộc trò chuyện',
          onPressed: _openConversationsList,
        ),
        // Tạo cuộc trò chuyện mới.
        IconButton(
          icon: _isCreatingConversation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_comment_outlined),
          tooltip: 'Cuộc trò chuyện mới',
          onPressed: _isCreatingConversation ? null : _startNewConversation,
        ),
        // Nút xóa lịch sử chat — luôn hiện ở góc trên bên phải.
        // Bấm vào sẽ hiện hộp thoại xác nhận trước khi xóa.
        IconButton(
          icon: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline_rounded),
          tooltip: 'Xóa lịch sử chat',
          // Chưa nạp xong lịch sử thì chưa cho xóa, tránh xóa nhầm phiên.
          onPressed: (_isDeleting || !_historyLoaded)
              ? null
              : _confirmDeleteHistory,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme, bool isDark) {
    final canSend = _hasText && !_isTyping;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Nút đính kèm ảnh (Thư viện / Camera)
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined, color: _primary),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                builder: (ctx) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('Chọn ảnh từ thư viện'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _sendImage(ImageSource.gallery);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text('Chụp ảnh mới'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _sendImage(ImageSource.camera);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Nhập câu hỏi về cây thuốc...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: _primaryLight.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: canSend
                  ? const LinearGradient(
                      colors: [_primaryLight, _primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: canSend
                  ? null
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? _sendMessage : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.send_rounded,
                    color: canSend ? Colors.white : Colors.grey.shade500,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- VIEW ĐANG NẠP LỊCH SỬ CHAT ---
class _HistoryLoadingView extends StatelessWidget {
  const _HistoryLoadingView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Đang tải lịch sử chat…',
            style: TextStyle(
              fontSize: 13.5,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// --- AI AVATAR WIDGET ---
class _AiAvatar extends StatelessWidget {
  final double size;
  const _AiAvatar({this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.eco_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

// --- BONG BÓNG TIN NHẮN WIDGET ---
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[const _AiAvatar(size: 30), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? null
                    : (isDark ? Colors.grey.shade800 : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hiển thị ảnh gửi kèm.
                  // Ảnh cục bộ (phiên hiện tại) dùng imagePath;
                  // ảnh nạp từ lịch sử server dùng imageUrl.
                  if (message.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imagePath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (message.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.imageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 180,
                            width: double.infinity,
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Nội dung câu hỏi / trả lời
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),

                  // Cảnh báo AI đoán (isAiGuess)
                  if (message.isAiGuess) ...[
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Thông tin tổng hợp ngoài CSDL',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Render danh sách thẻ kết quả cây thuốc (nếu có)
                  if (message.plantResults != null &&
                      message.plantResults!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      children: message.plantResults!.map((plant) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade900
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              if (plant.sampleImage != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    plant.sampleImage!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plant.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      plant.scientificName,
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(plant.confidence * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B5E20),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatTime(message.time),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isUser
                            ? Colors.white70
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TYPING BUBBLE WIDGET ---
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AiAvatar(size: 30),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_controller.value - i * 0.2) % 1.0;
                    final dy = t < 0.5
                        ? -4.0 * (1 - (t - 0.25).abs() * 4)
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(0, dy.clamp(-4.0, 0.0)),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF2E7D32).withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
