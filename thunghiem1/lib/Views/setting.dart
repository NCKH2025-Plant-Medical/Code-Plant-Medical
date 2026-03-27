import 'package:flutter/material.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  // Trạng thái các cài đặt
  bool _isDarkMode = false;
  bool _autoSaveImage = true;
  bool _offlineMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'Tiếng Việt';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Giao diện & Ngôn ngữ'),

          // Cài đặt Ngôn ngữ
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            title: const Text('Ngôn ngữ'),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Logic chọn ngôn ngữ
              _showLanguageDialog();
            },
          ),

          // Chế độ tối
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode, color: Colors.orange),
            title: const Text('Chế độ tối (Dark Mode)'),
            value: _isDarkMode,
            onChanged: (bool value) {
              setState(() {
                _isDarkMode = value;
              });
              // Thực hiện logic đổi Theme ở đây
            },
          ),

          const Divider(),
          _buildSectionHeader('Tính năng nhận diện'),

          // Tự động lưu ảnh
          SwitchListTile(
            secondary: const Icon(Icons.save_alt, color: Colors.green),
            title: const Text('Tự động lưu ảnh'),
            subtitle: const Text('Lưu ảnh cây vào thư viện sau khi nhận diện'),
            value: _autoSaveImage,
            onChanged: (bool value) {
              setState(() {
                _autoSaveImage = value;
              });
            },
          ),

          // Tải dữ liệu ngoại tuyến
          SwitchListTile(
            secondary: const Icon(Icons.cloud_download, color: Colors.purple),
            title: const Text('Dữ liệu ngoại tuyến'),
            subtitle: const Text('Nhận diện cây thuốc khi không có mạng'),
            value: _offlineMode,
            onChanged: (bool value) {
              setState(() {
                _offlineMode = value;
              });
            },
          ),

          const Divider(),
          _buildSectionHeader('Hệ thống'),

          // Thông báo
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active, color: Colors.red),
            title: const Text('Thông báo'),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),

          // Xóa bộ nhớ đệm (Cache)
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.grey),
            title: const Text('Xóa bộ nhớ đệm'),
            subtitle: const Text('Giải phóng dung lượng (Hiện có: 124MB)'),
            onTap: () {
              _showClearCacheDialog();
            },
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'Phiên bản 1.0.0+1',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Widget hỗ trợ tạo tiêu đề nhóm
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // Dialog chọn ngôn ngữ
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn ngôn ngữ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('Tiếng Việt'),
              value: 'Tiếng Việt',
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val.toString());
                Navigator.pop(context);
              },
            ),
            RadioListTile(
              title: const Text('English'),
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val.toString());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Dialog xác nhận xóa Cache
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bộ nhớ đệm?'),
        content: const Text('Hành động này sẽ xóa các tệp tạm thời nhưng không xóa lịch sử nhận diện của bạn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () {
              // Thực hiện xóa cache ở đây
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa bộ nhớ đệm thành công')),
              );
            },
            child: const Text('XÓA', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}