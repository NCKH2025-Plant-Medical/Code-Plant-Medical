// lib/screens/chat_conversations_screen.dart
//
// Màn hình danh sách các cuộc trò chuyện của người dùng.
//
// Dùng endpoint `GET /api/v1/chat/conversations`.
//
// Mỗi account có danh sách riêng — backend tự lọc theo `user_id`.
// Khách chưa đăng nhập dùng id ẩn danh ổn định theo thiết bị.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/models/chat_conversation.dart';
import 'package:thunghiem1/screens/chat_ai_screen.dart';
import 'package:thunghiem1/services/chat_box_service.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';

class ChatConversationsScreen extends StatefulWidget {
  /// Khi không `null`, màn hình sẽ mở thẳng vào phiên này.
  final String? initialConversationId;

  const ChatConversationsScreen({super.key, this.initialConversationId});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  static const Color _primary = Color(0xFF1B5E20);

  final ChatBoxService _chatService = ChatBoxService();

  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _userId = 'anonymous';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  /// Xác định user_id theo account hiện tại rồi nạp danh sách phiên.
  Future<void> _loadConversations() async {
    final auth = context.read<AuthNotifier>();

    // Chờ `AuthNotifier.init()` đọc xong token để `userId` chính xác.
    if (!auth.isInitialized) {
      try {
        await auth.ready;
      } catch (_) {
        // Bỏ qua — vẫn tiếp tục với id ẩn danh.
      }
    }
    if (!mounted) return;

    _userId = auth.userId ?? await ChatBoxService.anonymousUserId();

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _chatService.getConversations(userId: _userId);
      if (!mounted) return;
      setState(() {
        _conversations = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Tạo phiên chat mới rồi mở màn hình chat với phiên đó.
  Future<void> _createNewConversation() async {
    try {
      final created = await _chatService.createConversation(userId: _userId);

      if (!mounted) return;

      // Thêm ngay vào danh sách để phản hồi tức thì.
      setState(() => _conversations = [created, ..._conversations]);

      await _openConversation(created.conversationId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tạo được cuộc trò chuyện mới: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mở màn hình chat với phiên đã chọn.
  Future<void> _openConversation(String conversationId) async {
    // Lưu lại phiên hiện tại để mở app sau (và khi quay lại từ màn hình
    // chat) vẫn nạp đúng lịch sử.
    await _chatService.saveConversationId(_userId, conversationId);
    if (!mounted) return;

    // Lấy navigator trước khi await để tránh dùng BuildContext sau
    // async gap.
    final navigator = Navigator.of(context);

    await navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            ChatAiScreen(initialConversationId: conversationId),
      ),
    );
    // Quay lại thì nạp lại danh sách (tiêu đề / số tin nhắn có thể đã đổi).
    if (mounted) _loadConversations();
  }

  /// Xoá một phiên khỏi danh sách (gọi API xoá lịch sử của phiên đó).
  Future<void> _deleteConversation(ChatConversation conversation) async {
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
                'Xoá cuộc trò chuyện?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Xoá "${conversation.title}" và toàn bộ tin nhắn trong phiên này?\n'
          'Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Huỷ',
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
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.deleteSession(
        conversationId: conversation.conversationId,
        userId: _userId,
      );
      if (!mounted) return;
      setState(() {
        _conversations = _conversations
            .where((c) => c.conversationId != conversation.conversationId)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không xoá được cuộc trò chuyện: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Định dạng thời gian cập nhật gần nhất.
  String _formatUpdatedAt(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';

    return '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: BackNavButton(onPressed: () => Navigator.pop(context)),
        ),
        centerTitle: true,
        title: Text(
          'Cuộc trò chuyện',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          // Nút tạo cuộc trò chuyện mới.
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: _isLoading ? null : _createNewConversation,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      body: _buildBody(colorScheme, isDark),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, bool isDark) {
    if (_isLoading) {
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
              'Đang tải cuộc trò chuyện…',
              style: TextStyle(
                fontSize: 13.5,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Không tải được danh sách cuộc trò chuyện',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadConversations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 52,
                color: _primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                'Chưa có cuộc trò chuyện nào',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bắt đầu một cuộc trò chuyện mới với trợ lý AI 🌿',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _createNewConversation,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo cuộc trò chuyện mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: _primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _ConversationTile(
            conversation: conversation,
            isDark: isDark,
            formattedUpdatedAt: _formatUpdatedAt(conversation.updatedAt),
            onTap: () => _openConversation(conversation.conversationId),
            onDelete: () => _deleteConversation(conversation),
          );
        },
      ),
    );
  }
}

// --- THẺ MỘT CUỘC TRÒ CHUYỆN ---
class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool isDark;
  final String formattedUpdatedAt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.isDark,
    required this.formattedUpdatedAt,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon đại diện phiên
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (conversation.lastMessage != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        conversation.lastMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (formattedUpdatedAt.isNotEmpty)
                          Text(
                            formattedUpdatedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        if (conversation.messageCount > 0) ...[
                          if (formattedUpdatedAt.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            '${conversation.messageCount} tin nhắn',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Nút xoá phiên
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                tooltip: 'Xoá cuộc trò chuyện',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
