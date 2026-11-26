import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thunghiem1/core/image_compress.dart';
import 'package:thunghiem1/screens/results_screen.dart';
import 'package:thunghiem1/services/api_service.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';
import 'package:thunghiem1/widgets/error_dialog.dart';
import 'package:thunghiem1/services/review_feedback_service.dart';

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
    Position? capturePosition;
    String? feedbackImagePath;

    try {
      // Nén ảnh trước khi gửi: max 1024px, jpeg quality 80
      final compressedPath = await compressImageForUpload(imagePath);
      feedbackImagePath = compressedPath;

      // Lấy GPS chạy SONG SONG với API predict → không làm chậm trải nghiệm.
      final results = await Future.wait<dynamic>([
        _apiService
            .predictImage(compressedPath)
            .timeout(const Duration(seconds: 30)),
        _getCurrentPosition(),
      ]);
      result = results[0] as Map<String, dynamic>;
      capturePosition = results[1] as Position?;
    } on TimeoutException {
      error = Exception('Quá thời gian chờ. Vui lòng thử lại.');
    } catch (e) {
      error = e;
    } finally {
      _isProcessing = false;
      // Đóng loading dialog trong finally, bất kể thành công hay lỗi
      if (dialogShown && context.mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }

    if (!context.mounted) return;

    if (error != null) {
      final msg = error.toString().replaceAll('Exception: ', '');
      showErrorDialog(context, msg, title: 'Lỗi');
      return;
    }

    // Kiểm tra kết quả: nếu status là "unknown" hoặc predictions rỗng → hiện dialog thông báo
    final status = result?['status']?.toString() ?? '';
    final predictions = result?['predictions'];
    final bool isUnknown =
        status == 'unknown' || (predictions is List && predictions.isEmpty);

    if (isUnknown) {
      final message =
          result?['message']?.toString() ??
          'Không nhận diện được. Vui lòng thử lại với ảnh rõ hơn.';
      final send = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Không nhận diện được'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Đóng'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi ảnh cho chuyên gia'),
            ),
          ],
        ),
      );
      if (send == true && context.mounted && feedbackImagePath != null) {
        final userId = context.read<AuthNotifier>().userId;
        if (userId == null) {
          showErrorDialog(
            context,
            'Vui lòng đăng nhập để gửi và quản lý ảnh của bạn.',
            title: 'Cần đăng nhập',
          );
          return;
        }
        try {
          final sent = await ReviewFeedbackService.askAndSubmit(
            context,
            imagePath: feedbackImagePath,
            prediction: result!,
            source: 'low_confidence',
            userId: userId,
          );
          if (sent && context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cảm ơn bạn!'),
                content: const Text(
                  'Ảnh đã được gửi để chuyên gia thẩm định và cải thiện AI. '
                  'Bạn có thể xem hoặc rút lại đồng ý trong Hồ sơ cá nhân.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            );
          }
        } catch (_) {
          if (context.mounted) {
            showErrorDialog(
              context,
              'Không thể gửi ảnh. Vui lòng thử lại.',
              title: 'Lỗi',
            );
          }
        }
      }
      return; // Ở lại màn hình camera, không navigate
    }

    // Chuyển sang ResultScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          result: result!,
          pathImg: imagePath,
          feedbackImagePath: feedbackImagePath,
          capturePosition: capturePosition,
        ),
      ),
    );
  }

  /// Lấy tọa độ GPS hiện tại (chạy ngầm, không chặn luồng chụp).
  ///
  /// Yêu cầu: "Sau khi chụp ảnh và trong lúc chờ API predict, lấy tọa độ
  /// hiện tại của thiết bị... Nếu không lấy được GPS thì vẫn cho phép lưu
  /// (chỉ không có tọa độ)".
  ///
  /// Không xin quyền ở đây — quyền vị trí đã được xin ở màn hình bản đồ.
  /// Nếu chưa có quyền thì trả về null, không ném lỗi.
  Future<Position?> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      if (!mounted) return;
      await _handleCapture(context, picked.path);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, e.toString(), title: 'Lỗi');
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
              if (event.status == MediaCaptureStatus.success &&
                  event.isPicture) {
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

          // Nút BackNavButton ở góc trên bên trái
          Positioned(
            top: 0,
            left: 16,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: BackNavButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // Nút mở thư viện ảnh góc dưới bên trái
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
