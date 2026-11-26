import 'package:thunghiem1/widgets/error_dialog.dart';
import 'package:thunghiem1/models/plants_model.dart';
import 'package:thunghiem1/screens/plant_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:thunghiem1/models/image_response.dart';
import 'package:thunghiem1/screens/map_screen.dart';
import 'package:thunghiem1/screens/camera_screen.dart';
import 'package:thunghiem1/services/history_service.dart';
import 'package:thunghiem1/theme/app_colors.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';

class ImagesListScreen extends StatefulWidget {
  const ImagesListScreen({super.key});

  @override
  State<ImagesListScreen> createState() => _ImagesListScreenState();
}

class _ImagesListScreenState extends State<ImagesListScreen> {
  late final HistoryService _historyService;
  late Future<HistoryPage> _imagesFuture;
  int _page = 1;
  bool _deleting = false;
  bool _deleteMode = false;
  final Set<String> _selected = {};

  Future<void> _delete({bool all = false}) async {
    if (_deleting || (!all && _selected.isEmpty)) return;
    setState(() => _deleting = true);
    final ids = Set<String>.from(_selected);
    try {
      final confirmed = await showErrorDialog(
        context,
        all
            ? 'Xoá toàn bộ ảnh và cây cá nhân đã lưu trên mọi trang? Không thể hoàn tác.'
            : 'Xoá ${ids.length} mục đã chọn cùng cây cá nhân tương ứng? Không thể hoàn tác.',
        title: 'Xác nhận xoá',
        confirmLabel: 'Xoá',
      );
      if (confirmed != true || !mounted) return;
      final count = await _historyService.deleteItems(ids: all ? null : ids);
      if (!mounted) return;
      _selected.clear();
      _page = 1;
      _loadImages();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã xoá $count mục.')));
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _historyService = HistoryService();
    // Gán trực tiếp — không gọi setState trong initState
    _imagesFuture = _historyService.getPage(_page);
  }

  @override
  void dispose() {
    _historyService.dispose();
    super.dispose();
  }

  void _refreshImages() {
    _deleteMode = false;
    _selected.clear();
    _loadImages();
  }

  void _loadImages() {
    // Chỉ setState khi user bấm refresh
    setState(() {
      _imagesFuture = _historyService.getPage(_page);
    });
  }

  Widget _buildNetworkImage(String imageUrl) {
    final colorScheme = Theme.of(context).colorScheme;

    // API trả về URL tuyệt đối (Cloudinary) → dùng trực tiếp.
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      // Giới hạn cache image ~400px để tránh load full-res trong grid
      cacheWidth: 400,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      (loadingProgress.expectedTotalBytes ?? 1)
                : null,
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              size: 40,
            ),
          ),
        );
      },
    );
  }

  /// Mở màn hình Bản đồ và zoom tới toạ độ GPS của ảnh này.
  ///
  /// Yêu cầu: "Nếu mục có toạ độ GPS: Hiển thị icon bản đồ nhỏ, bấm vào có thể
  /// chuyển hướng sang bản đồ zoom thông tin tọa độ của cây đó".
  void _openOnMap(BuildContext context, ImageResponse image) {
    if (!image.hasLocation) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantMapScreen(
          focusLocation: LatLng(image.latitude!, image.longitude!),
        ),
      ),
    );
  }

  void _showImageDetail(BuildContext context, ImageResponse image) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: _buildNetworkImage(image.imageUrl),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.commonName ?? 'Cây đã lưu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (image.scientificName?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          image.scientificName!,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                      if (image.confidence != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Độ tin cậy: ${image.confidence!.toStringAsFixed(2)}%',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text('Đã lưu: ${image.savedAtLabel}'),
                      if (image.plantId?.isNotEmpty == true)
                        TextButton.icon(
                          icon: const Icon(Icons.eco_outlined),
                          label: const Text('Xem chi tiết cây'),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => PlantDetailSheet(
                                showActions: false,
                                prediction: PlantPrediction(
                                  plantId: image.plantId!,
                                  commonName: image.commonName ?? 'Cây đã lưu',
                                  scientificName: image.scientificName ?? '',
                                  confidence: image.confidence ?? 0,
                                  imageUrl: image.imageUrl,
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      Text(
                        image.hasLocation
                            ? 'GPS: ${image.latitude!.toStringAsFixed(6)}, '
                                  '${image.longitude!.toStringAsFixed(6)}'
                            : 'Không có dữ liệu GPS',
                      ),
                      if (image.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text('Ghi chú: ${image.notes}'),
                      ],
                      const SizedBox(height: 16),
                      if (image.hasLocation)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _openOnMap(context, image);
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Xem trên bản đồ'),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const BackNavButton(),
      body: Column(
        children: [
          _buildHeader(), // Thiết kế gốc của bạn
          Expanded(
            child: FutureBuilder<HistoryPage>(
              future: _imagesFuture,
              builder: (context, snapshot) {
                // TRƯỜNG HỢP 3: Trạng thái đang tải (Skeleton)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                }
                // TRƯỜNG HỢP 4: Lỗi tải dữ liệu
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  final images = data.items;
                  // TRƯỜNG HỢP 2: Dữ liệu rỗng
                  if (images.isEmpty) return _buildEmpty();
                  // TRƯỜNG HỢP 1: Tải đầy đủ
                  return Column(
                    children: [
                      if (_deleteMode)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _deleting
                                  ? null
                                  : () => setState(() {
                                      _selected.addAll(images.map((e) => e.id));
                                    }),
                              child: const Text('Chọn trang này'),
                            ),
                            TextButton(
                              onPressed: _deleting || _selected.isEmpty
                                  ? null
                                  : () => setState(_selected.clear),
                              child: const Text('Bỏ chọn'),
                            ),
                            TextButton(
                              onPressed: _deleting || _selected.isEmpty
                                  ? null
                                  : () => _delete(),
                              child: Text('Xoá (${_selected.length})'),
                            ),
                            TextButton(
                              onPressed: _deleting
                                  ? null
                                  : () => _delete(all: true),
                              child: const Text('Xoá tất cả'),
                            ),
                          ],
                        ),
                      if (_deleting) const LinearProgressIndicator(),
                      Expanded(child: _buildGrid(images)),
                      SafeArea(
                        top: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _deleting || _page <= 1
                                  ? null
                                  : () {
                                      _page--;
                                      _loadImages();
                                    },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Trang $_page / ${(data.total / 6).ceil()}'),
                            IconButton(
                              onPressed: _deleting || _page * 6 >= data.total
                                  ? null
                                  : () {
                                      _page++;
                                      _loadImages();
                                    },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử cây',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Danh sách ảnh đã chụp',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _deleteMode ? 'Tắt chế độ xoá' : 'Chọn mục để xoá',
                isSelected: _deleteMode,
                onPressed: _deleting
                    ? null
                    : () => setState(() {
                        _deleteMode = !_deleteMode;
                        _selected.clear();
                      }),
                icon: const Icon(Icons.delete_outline),
                selectedIcon: const Icon(Icons.delete, color: Colors.red),
              ),
              IconButton.filledTonal(
                onPressed: _deleting ? null : _refreshImages,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: AppColors.primaryVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<ImageResponse> images) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) => _buildImageCard(images[index]),
    );
  }

  Widget _buildImageCard(ImageResponse image) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _deleting ? null : () => _showImageDetail(context, image),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: _buildNetworkImage(image.displayImageUrl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_deleteMode)
                    SizedBox(
                      width: 28,
                      child: Checkbox(
                        value: _selected.contains(image.id),
                        onChanged: _deleting
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selected.add(image.id);
                                } else {
                                  _selected.remove(image.id);
                                }
                              }),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          image.commonName ?? image.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          image.savedAtLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icon bản đồ nhỏ — chỉ hiện khi mục có toạ độ GPS.
                  if (image.hasLocation)
                    Tooltip(
                      message: 'Xem trên bản đồ',
                      child: InkWell(
                        onTap: () => _openOnMap(context, image),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryVariant.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.map_outlined,
                            size: 18,
                            color: AppColors.primaryVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor = colorScheme.surfaceContainerHighest;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(4),
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

  Widget _buildError(String error) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 50,
                  color: Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Không thể tải dữ liệu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kết nối có thể đang gián đoạn. Vui lòng\nthử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _deleting ? null : _loadImages,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryVariant,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 14,
                ),
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primaryVariant.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 50,
                  color: AppColors.primaryVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có ảnh nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy chụp cây đầu tiên để bắt đầu bộ sưu\ntập của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const CameraScreen()));
                if (mounted) _loadImages();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryVariant,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 14,
                ),
              ),
              child: const Text(
                'Bắt đầu chụp',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
