import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thunghiem1/core/image_compress.dart';
import 'package:thunghiem1/services/api_service.dart';
import 'package:thunghiem1/screens/results_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;

  Future<void> _handleCapture(BuildContext context, String imagePath) async {
    if (!mounted || _isProcessing) return;
    _isProcessing = true;

    final colorScheme = Theme.of(context).colorScheme;
    bool dialogShown = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      },
    );
    dialogShown = true;

    Map<String, dynamic>? result;
    Object? error;

    try {
      // Nén ảnh trước khi gửi: max 1024px, jpeg quality 80
      final compressedPath = await compressImageForUpload(imagePath);
      result = await _apiService
          .predictImage(compressedPath)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      error = Exception('Quá thời gian chờ. Vui lòng thử lại.');
    } catch (e) {
      error = e;
    } finally {
      _isProcessing = false;
      // Đóng loading dialog trong finally, bất kể thành công hay lỗi
      if (dialogShown && mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }

    if (!mounted) return;

    if (error != null) {
      final msg = error.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kiểm tra kết quả: nếu status là "unknown" hoặc predictions rỗng → hiện dialog thông báo
    final status = result?['status']?.toString() ?? '';
    final predictions = result?['predictions'];
    final bool isUnknown =
        status == 'unknown' || (predictions is List && predictions.isEmpty);

    if (isUnknown) {
      final message = result?['message']?.toString() ??
          'Không nhận diện được. Vui lòng thử lại với ảnh rõ hơn.';
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2D6A4F)),
              SizedBox(width: 8),
              Text('Không nhận diện được',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Chấp nhận',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
      return; // Ở lại màn hình camera, không navigate
    }

    // Chuyển sang ResultScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          result: result!,
          pathImg: imagePath,
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (!mounted) return;
      await _handleCapture(context, picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn ảnh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(),
            onMediaCaptureEvent: (event) {
              if (_isProcessing) return;
              if (event.status == MediaCaptureStatus.success && event.isPicture) {
                event.captureRequest.when(
                  single: (single) async {
                    final path = single.file?.path;
                    if (path != null) {
                      await _handleCapture(context, path);
                    }
                  },
                );
              }
            },
          ),
          Positioned(
            left: 16,
            bottom: 32,
            child: FloatingActionButton(
              heroTag: 'gallery_btn',
              onPressed: _pickFromGallery,
              child: const Icon(Icons.photo_library),
            ),
          ),
        ],
      ),
    );
  }
}