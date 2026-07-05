import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/services/image_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImageService _imageService = ImageService(baseUrl: AppConfig.baseUrl);

  Future<void> _handleCapture(BuildContext context, String imagePath) async {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      },
    );

    try {
      final capturedAt = DateTime.now();

      if (!mounted) return;
      Navigator.of(context).pop();

      _uploadImageInBackground(imagePath, capturedAt.toIso8601String());
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xử lý ảnh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _uploadImageInBackground(String imagePath, String capturedAt) async {
    try {
      await _imageService.uploadImage(
        imagePath: imagePath,
        capturedAt: capturedAt,
      );
    } catch (e) {
      debugPrint('Lỗi khi upload ảnh ngầm: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photo(),
        onMediaCaptureEvent: (event) {
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
    );
  }
}
