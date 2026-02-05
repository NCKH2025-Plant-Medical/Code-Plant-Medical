import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import '../api_service.dart';
import 'results_screen.dart';
import '../Services/flutter_integration.dart';

class Camera extends StatefulWidget {
  const Camera({Key? key}) : super(key: key);

  @override
  _CameraState createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  final ImageService _imageService = ImageService(
    baseUrl: "http://192.168.1.106:8000",
  );
  Future<void> _handleCapture(BuildContext context, String imagePath) async {
    if (!mounted) return;
    try {
      DateTime capturedAt = DateTime.now();
      final api = ApiService();
      final result = await api.predictImage(imagePath);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      _uploadImageInBackground(imagePath, capturedAt);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result, pathImg: imagePath,)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi khi gửi ảnh: $e")));
    }
  }

  void _uploadImageInBackground(String imagePath, DateTime capturedAt) async {
    try {
      final response = await _imageService.uploadImage(
        imagePath: imagePath,
        capturedAt: capturedAt.toIso8601String(),
      );

      if (response.success) {
        print('Image uploaded successfully! ID: ${response.data?.id}');

        // Optional: Show subtle notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ảnh đã được lưu"),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        print('Upload failed: ${response.message}');
      }
    } catch (e) {
      print('Upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photo(),
        onMediaTap: (mediaCapture) {
          mediaCapture.captureRequest.when(
            single: (single) async {
              final path = single.file?.path;
              if (path != null) {
                print('Ảnh lưu tại: $path');
                await _handleCapture(context, path);
              }
            },
          );
        },
      ),
    );
  }
}