import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import '../api_service.dart';
import 'results_screen.dart';

class Camera extends StatefulWidget {
  const Camera({Key? key}) : super(key: key);

  @override
  _CameraState createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  Future<void> _handleCapture(BuildContext context, String imagePath) async {
    if (!mounted) return;
    try {
      final api = ApiService();
      final result = await api.predictImage(imagePath);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi khi gửi ảnh: $e")));
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