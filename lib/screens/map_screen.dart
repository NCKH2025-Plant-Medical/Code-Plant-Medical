import 'package:flutter/material.dart';
import 'package:thunghiem1/widgets/search_text_field.dart';
import 'package:thunghiem1/theme/app_colors.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';

enum MapUiState { loaded, empty, loading, error }

class PlantMapScreen extends StatefulWidget {
  const PlantMapScreen({super.key});

  @override
  State<PlantMapScreen> createState() => _PlantMapScreenState();
}

class _PlantMapScreenState extends State<PlantMapScreen> {
  MapUiState _uiState = MapUiState.loading;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() => _uiState = MapUiState.loading);

    // Giả lập thời gian call API / load map
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _uiState = MapUiState.loaded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // 1. LỚP DƯỚI CÙNG: Bản đồ lấp đầy toàn màn hình
          Positioned.fill(
            child: _buildMapBackground(),
          ),

          // 2. LỚP Ở GIỮA: Các thẻ thông báo trạng thái (Empty, Loading, Error)
          if (_uiState == MapUiState.empty) _buildEmptyOverlay(),
          if (_uiState == MapUiState.loading) _buildLoadingOverlay(),
          if (_uiState == MapUiState.error) _buildErrorOverlay(),

          // 3. LỚP DƯỚI ĐÁY (Bottom): Thẻ thông tin cây khi load thành công
          if (_uiState == MapUiState.loaded) _buildLoadedOverlay(),

          // 4. LỚP TRÊN CÙNG: Header (Tiêu đề + Thanh tìm kiếm) đè lên map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
        ],
      ),
      // FAB debug đã xóa
    );
  }

  // ==========================================
  // HEADER WIDGET (Tiêu đề + Thanh tìm kiếm)
  // ==========================================
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hàng tiêu đề
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: BackNavButton(),
                  ),

                  Text(
                    'Plant Map',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),

                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thanh tìm kiếm — heroTag riêng để không trùng với Home
              SearchTextField(
                hintText: 'Tìm kiếm cây trồng....',
                heroTag: 'search_bar_map',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BACKGROUND MAP (Giả lập bản đồ)
  // ==========================================
  Widget _buildMapBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE5E3DF),
      child: Stack(
        children: [
          Positioned(
            top: 150, left: -50,
            child: Container(width: 500, height: 80, color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          Positioned(
            bottom: -50, right: 80,
            child: Container(width: 120, height: 600, color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          Center(
            child: Text(
              _uiState == MapUiState.loading
                  ? ''
                  : 'Bản đồ thực tế sẽ hiển thị full màn hình',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LỚP OVERLAY 1: THÀNH CÔNG (Có thẻ cây bên dưới)
  // ==========================================
  Widget _buildLoadedOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Hình ảnh cây
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.green.shade200,
                child: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Artemisia_vulgaris_1.jpg/640px-Artemisia_vulgaris_1.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.eco, color: Colors.green),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Thông tin cây
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.blue, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'MỚI PHÁT HIỆN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cây Ngải Cứu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                          Icons.location_on,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cách bạn 200m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LỚP OVERLAY 2: TRỐNG (Empty)
  // ==========================================
  Widget _buildEmptyOverlay() {
    return _buildCenterCard(
      icon: Icons.search_rounded,
      iconColor: AppColors.primaryVariant,
      iconBgColor: AppColors.primaryVariant.withValues(alpha: 0.1),
      title: 'Chưa có cây nào được ghi\nnhận',
      description: 'Khu vực này chưa có dữ liệu. Hãy là người\nđầu tiên ghi nhận một cây trồng.',
    );
  }

  // ==========================================
  // LỚP OVERLAY 3: ĐANG TẢI (Loading)
  // ==========================================
  Widget _buildLoadingOverlay() {
    return _buildCenterCard(
      customIcon: CircularProgressIndicator(
        strokeWidth: 3,
        color: AppColors.primaryVariant,
      ),
      title: 'Đang tải bản đồ...',
      description: 'Đang cập nhật dữ liệu cây trồng\nquanh bạn',
    );
  }

  // ==========================================
  // LỚP OVERLAY 4: LỖI (Error)
  // ==========================================
  Widget _buildErrorOverlay() {
    return _buildCenterCard(
      icon: Icons.wifi_off_rounded,
      iconColor: Colors.redAccent,
      iconBgColor: Colors.redAccent.withValues(alpha: 0.1),
      title: 'Không thể tải bản đồ',
      description: 'Kết nối có thể đang gián đoạn. Vui lòng\nkiểm tra mạng và thử lại.',
      buttonText: 'Thử lại',
      onButtonPressed: _loadMapData,
    );
  }

  // ==========================================
  // COMPONENT CHUNG CHO THẺ CĂN GIỮA
  // ==========================================
  Widget _buildCenterCard({
    IconData? icon,
    Widget? customIcon,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    required String description,
    String? buttonText,
    VoidCallback? onButtonPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            if (customIcon != null)
              customIcon
            else if (icon != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: iconColor),
              ),

            const SizedBox(height: 24),

            // Tiêu đề
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            // Mô tả
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),

            // Nút bấm (nếu có)
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryVariant,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}