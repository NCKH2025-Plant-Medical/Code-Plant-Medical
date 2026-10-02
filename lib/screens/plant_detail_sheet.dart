import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:thunghiem1/services/api_service.dart';

class PlantDetailSheet extends StatelessWidget {
  final dynamic prediction;

  /// Set to false to hide the "Xác nhận" / "Quay lại" footer buttons.
  final bool showActions;

  const PlantDetailSheet({
    super.key,
    required this.prediction,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo (Drag Handle)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Chi tiết cây thuốc', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Nội dung chi tiết có thể cuộn (Bọc FutureBuilder ra ngoài ListView)
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: ApiService().getPlantDetail(prediction.plantId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.green));
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Không thể tải dữ liệu chi tiết.', style: TextStyle(color: Colors.red))
                      );
                    }

                    // Lấy dữ liệu từ API dựa trên các key trong Swagger
                    final data = snapshot.data ?? {};
                    final commonName = data['common_name'] ?? prediction.commonName ?? 'Chưa cập nhật';
                    final scientificName = data['scientific_name'] ?? 'Chưa cập nhật';
                    final description = data['description'] ?? 'Chưa có thông tin mô tả cho loài cây này.';
                    final usage = data['usage'];
                    final howToUse = data['how_to_use'];
                    final precautions = data['precautions'];
                    final imageUrl = data['image_url'];

                    return ListView(
                      controller: scrollController, // Rất quan trọng để vuốt được DraggableScrollableSheet
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Hình ảnh cây từ API (Nếu có)
                        if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Các trường thông tin
                        _buildInfoSection('Tên phổ biến', commonName),
                        _buildInfoSection('Tên khoa học', scientificName, isItalic: true),
                        _buildInfoSection('Mô tả', description),

                        // Kiểm tra null hoặc rỗng trước khi hiển thị các section phụ
                        if (usage != null && usage.toString().isNotEmpty)
                          _buildInfoSection('Công dụng', usage),

                        if (howToUse != null && howToUse.toString().isNotEmpty)
                          _buildInfoSection('Cách dùng', howToUse),

                        if (precautions != null && precautions.toString().isNotEmpty)
                          _buildInfoSection('Lưu ý', precautions, titleColor: Colors.red.shade700),

                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),

              // Footer chứa 2 nút (cố định ở dưới cùng Component)
              if (showActions)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Xử lý xác nhận
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check, color: AppColors.lightSurface),
                          label: const Text('Xác nhận là loại này', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: AppColors.lightSurface)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          label: const Text('Quay lại danh sách', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Hàm hỗ trợ build các đoạn text tiêu đề + nội dung nhanh chóng
  Widget _buildInfoSection(String title, String content, {bool isItalic = false, Color titleColor = const Color(0xFF1B5E20)}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.black87,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}