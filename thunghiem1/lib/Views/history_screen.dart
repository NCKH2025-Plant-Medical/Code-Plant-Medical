import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../Services/flutter_integration.dart';

class ImagesListScreen extends StatefulWidget {
  const ImagesListScreen({Key? key}) : super(key: key);

  @override
  State<ImagesListScreen> createState() => _ImagesListScreenState();
}

class _ImagesListScreenState extends State<ImagesListScreen> {
  final ImageService _imageService = ImageService(
    baseUrl: "http://192.168.1.106:8000",
  );

  late Future<ImagesListResponse> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    setState(() {
      _imagesFuture = _imageService.getAllImages(
        limit: 100,
        orderBy: 'uploaded_at',
      );
    });
  }

  // Chuyển đổi base64 string thành Image widget
  Widget _buildImageFromBase64(String base64String) {
    try {
      // Loại bỏ prefix "data:image/xxx;base64," nếu có
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }

      Uint8List bytes = base64Decode(cleanBase64);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.error, color: Colors.red);
        },
      );
    } catch (e) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }

  // Gọi hàm này khi nhấn vào ảnh
  void _showImageDetail(BuildContext context, ImageResponse image) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54, // Làm tối nền
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Color(0xFFF8F8F8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400), // Giới hạn chiều rộng
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Header Image Section ---
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Hero(
                            tag: image.id,
                            child: _buildImageFromBase64(image.imageBase64),
                          ),
                        ),
                        // Nút đóng hiện đại
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --- Content Section ---
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  image.id,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '#${image.id.split('-').last}',
                                  style: TextStyle(
                                    color: Color.fromRGBO(94, 139, 49, 0.8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 32, thickness: 1),
                          Row(
                            children: [
                              Icon(Icons.date_range, size: 16, color: Colors.grey[600],),
                              Text(" Captured at: ", style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),),
                              Text(
                                image.capturedAt.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          // Nút hành động chính
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromRGBO(94, 139, 49, 0.8),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          _buildHeader(), // Custom Header thay thế AppBar
          Expanded(
            child: FutureBuilder<ImagesListResponse>(
              future: _imagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  if (data.images.isEmpty) return _buildEmpty();
                  return _buildGrid(data.images);
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Images List',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Danh sách ảnh đã chụp',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: _loadImages,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Color.fromRGBO(104, 169, 49, 0.8),
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
      padding: const EdgeInsets.all(20),
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
    return GestureDetector(
      onTap: (){
        _showImageDetail(context, image);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: _buildImageFromBase64(image.imageBase64),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    image.capturedAt.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo[400]!),
          ),
          const SizedBox(height: 16),
          Text(
            'Đang tải dữ liệu...',
            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Rất tiếc, đã có lỗi xảy ra',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadImages,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        'Không tìm thấy hình ảnh nào',
        style: TextStyle(color: Colors.grey[500], fontSize: 16),
      ),
    );
  }
}
