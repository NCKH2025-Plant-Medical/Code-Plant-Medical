import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:thunghiem1/services/api_service.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart'; // Import BackNavButton

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

              // Header có chứa nút BackNavButton và Tiêu đề
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    BackNavButton(onPressed: () => Navigator.pop(context)),
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: 40.0,
                          ), // Căn giữa tiêu đề
                          child: Text(
                            'Chi tiết cây thuốc',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Nội dung chi tiết có thể cuộn (Bọc FutureBuilder ra ngoài ListView)
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: ApiService().getPlantDetail(prediction.plantId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Không thể tải dữ liệu chi tiết.',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    // Lấy dữ liệu từ API dựa trên các key trong Swagger
                    final data = snapshot.data ?? {};
                    final commonName =
                        data['common_name'] ??
                        prediction.commonName ??
                        'Chưa cập nhật';
                    final scientificName =
                        data['scientific_name'] ?? 'Chưa cập nhật';
                    final description =
                        data['description'] ??
                        'Chưa có thông tin mô tả cho loài cây này.';
                    final usage = data['usage'];
                    final howToUse = data['how_to_use'];
                    final precautions = data['precautions'];
                    final imageUrl = data['image_url'];

                    return ListView(
                      controller:
                          scrollController, // Rất quan trọng để vuốt được DraggableScrollableSheet
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Hình ảnh cây từ API (Nếu có)
                        if (imageUrl != null &&
                            imageUrl.toString().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Các trường thông tin
                        _buildInfoSection('Tên phổ biến', commonName),
                        _buildInfoSection(
                          'Tên khoa học',
                          scientificName,
                          isItalic: true,
                        ),
                        _buildInfoSection('Mô tả', description),

                        // Kiểm tra null hoặc rỗng trước khi hiển thị các section phụ
                        if (usage != null && usage.toString().isNotEmpty)
                          _buildInfoSection('Công dụng', usage),

                        if (howToUse != null && howToUse.toString().isNotEmpty)
                          _buildInfoSection('Cách dùng', howToUse),

                        if (precautions != null &&
                            precautions.toString().isNotEmpty)
                          _buildInfoSection(
                            'Lưu ý',
                            precautions,
                            titleColor: Colors.red.shade700,
                          ),

                        // Khối lưu ý miễn trừ trách nhiệm y khoa
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.amber.shade900.withValues(alpha: 0.2)
                                : const Color(0xFFFEF7EA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.amber.shade700.withValues(alpha: 0.4)
                                  : const Color(0xFFF6D389),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.amber.shade300
                                    : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Lưu ý: Mọi thông tin nhận diện và dữ liệu cây thuốc trên ứng dụng chỉ mang tính chất tham khảo, có thể có sai sót và không thay thế cho chẩn đoán y khoa chuyên môn.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: isDark
                                        ? Colors.amber.shade100
                                        : const Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
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
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, -4),
                        blurRadius: 10,
                      ),
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
                          icon: const Icon(
                            Icons.check,
                            color: AppColors.lightSurface,
                          ),
                          label: const Text(
                            'Xác nhận là loại này',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: AppColors.lightSurface,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                          ),
                          label: const Text(
                            'Quay lại danh sách',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
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
  Widget _buildInfoSection(
    String title,
    String content, {
    bool isItalic = false,
    Color titleColor = const Color(0xFF1B5E20),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
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
