import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Resize + compress ảnh trước khi gửi lên server.
/// Trả về path file nén (temp file). Max cạnh 1024px, jpeg quality 80.
Future<String> compressImageForUpload(String sourcePath) async {
  final sourceFile = File(sourcePath);
  final bytes = await sourceFile.readAsBytes();

  // Decode bằng image package
  final original = img.decodeImage(bytes);
  if (original == null) {
    // Không decode được → trả về file gốc
    return sourcePath;
  }

  // Resize nếu cần: max cạnh 1024
  img.Image resized;
  const maxEdge = 1024;
  if (original.width > maxEdge || original.height > maxEdge) {
    if (original.width >= original.height) {
      resized = img.copyResize(original, width: maxEdge);
    } else {
      resized = img.copyResize(original, height: maxEdge);
    }
  } else {
    resized = original;
  }

  // Encode ra JPEG quality 80
  final Uint8List compressed = Uint8List.fromList(
    img.encodeJpg(resized, quality: 80),
  );

  // Ghi vào temp file
  final tempDir = await getTemporaryDirectory();
  final tempPath = '${tempDir.path}/pv_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(tempPath).writeAsBytes(compressed);

  return tempPath;
}
