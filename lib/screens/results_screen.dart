import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marquee/marquee.dart';
import 'package:thunghiem1/models/plants_model.dart';
import 'package:thunghiem1/screens/plant_detail_sheet.dart';
import 'package:thunghiem1/services/user_plant_api_service.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String pathImg;

  /// Tọa độ GPS lúc chụp (null nếu không lấy được).
  final Position? capturePosition;

  const ResultScreen({
    super.key,
    required this.result,
    required this.pathImg,
    this.capturePosition,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final UserPlantApiService _userPlantApi = UserPlantApiService();

  bool _isOpeningSheet = false;
  bool _isSaving = false;
  List<PlantPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _predictions = PlantPrediction.listFrom(widget.result);
  }

  @override
  void dispose() {
    _userPlantApi.dispose();
    super.dispose();
  }

  void _openDetailSheet(PlantPrediction plant) async {
    if (_isOpeningSheet) return;

    setState(() => _isOpeningSheet = true);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlantDetailSheet(prediction: plant),
    );

    if (mounted) {
      setState(() => _isOpeningSheet = false);
    }
  }

  // ── Lưu vào Lịch sử & Bản đồ ─────────────────────────────────────────────

  /// Lưu cây đã chọn vào lịch sử + bản đồ.
  ///
  /// Yêu cầu:
  ///   • Nút hành động nổi bật kết quả Top Match (hoặc cạnh nút "Xem chi tiết").
  ///   • Nhấn → hiển thị loading spinner trên nút.
  ///   • Gọi API → thành công: Snackbar xanh "Đã lưu cây vào Lịch sử và bản đồ!".
  ///   • Vô hiệu hóa nút (đổi thành "Đã lưu") để tránh bấm trùng.
  Future<void> _saveToHistoryAndMap(PlantPrediction plant) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _userPlantApi.saveUserPlant(
        imagePath: widget.pathImg,
        name: plant.commonName,
        plantId: plant.plantId,
        scientificName: plant.scientificName,
        confidence: plant.confidence,
        latitude: widget.capturePosition?.latitude,
        longitude: widget.capturePosition?.longitude,
      );

      if (!mounted) return;
      _showSaveResult(
        message: 'Đã lưu cây vào Lịch sử và bản đồ!',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSaveResult(message: msg, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveResult({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _predictions.take(3).toList();
    if (displayList.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Không nhận diện được loại cây nào')),
      );
    }

    final topMatch = displayList.first;
    final suggestions = displayList.skip(1).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kết quả nhận diện',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 16,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KẾT QUẢ NHẬN DIỆN TỐI ƯU',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTopMatchCard(topMatch),

            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CÁC ĐỀ XUẤT KHÁC',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...suggestions.map((plant) => _buildSuggestionCard(plant)),
            ],

            const SizedBox(height: 24),
            _buildWarningBox(),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.lightSurface,
                ),
                label: const Text(
                  'Chụp lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMatchCard(PlantPrediction plant) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.file(
                  File(
                    widget.pathImg,
                  ), // Hiển thị trực tiếp ảnh người dùng vừa chụp
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      plant.imageUrl ?? 'https://via.placeholder.com/400x200',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Độ tin cậy cao nhất • ${plant.confidenceLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ảnh bạn chụp',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.commonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 16,
                        child: Marquee(
                          text: plant.scientificName,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                          blankSpace: 30,
                          velocity: 30,
                          pauseAfterRound: const Duration(seconds: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _openDetailSheet(plant),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Xem chi tiết',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.lightSurface,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 20,
                            color: AppColors.lightSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SaveButton(
                  isSaving: _isSaving,
                  onPressed: () => _saveToHistoryAndMap(plant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nút "Lưu vào Lịch sử & Bản đồ" — hiển thị spinner khi đang gọi API.
  Widget _buildSuggestionCard(PlantPrediction plant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              plant.imageUrl ?? 'https://via.placeholder.com/80',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade300,
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.commonName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  child: Marquee(
                    text: plant.scientificName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    blankSpace: 30,
                    velocity: 30,
                    pauseAfterRound: const Duration(seconds: 1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Độ tin cậy • ${plant.confidenceLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => _openDetailSheet(plant),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Xem chi tiết',
                  style: TextStyle(fontSize: 12, color: AppColors.lightSurface),
                ),
              ),
              const SizedBox(height: 6),
              // Tuỳ chọn nâng cao: lưu đề xuất khác khi Top 1 chưa chuẩn.
              _SaveIconButton(
                isSaving: _isSaving,
                onPressed: () => _saveToHistoryAndMap(plant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nếu mẫu đưa ra không giống với hình ảnh thực tế bạn đang thấy\nThử chụp gần gân lá (cây) hoặc chụp góc có ánh sáng rõ hơn',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nút lưu ─────────────────────────────────────────────────────────────────

/// Nút lớn "Lưu" cho Top Match.
class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onPressed;

  const _SaveButton({required this.isSaving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : onPressed,
        icon: isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.bookmark_add_outlined,
                color: Colors.white,
                size: 20,
              ),
        label: Text(
          isSaving ? 'Đang lưu' : 'Lưu',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryVariant,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

/// Nút icon nhỏ cho danh sách "đề xuất khác".
class _SaveIconButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onPressed;

  const _SaveIconButton({required this.isSaving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryVariant.withValues(alpha: 0.15),
          foregroundColor: AppColors.primaryVariant,
          elevation: 0,
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bookmark_add_outlined, size: 18),
      ),
    );
  }
}
