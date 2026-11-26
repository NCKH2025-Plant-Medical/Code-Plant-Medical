// lib/features/herbal_garden/utils/garden_location.dart
//
// Lấy vị trí GPS an toàn cho các màn hình Vườn Dược Liệu.
//
// ⚠️ VÌ SAO CẦN FILE NÀY:
// `Geolocator.getCurrentPosition()` là call bất đồng bộ tới plugin native.
// Trong widget test (hoặc khi plugin chưa sẵn sàng) Future này có thể
// **không bao giờ hoàn tất**. Nếu màn hình `await` nó → màn hình treo.
//
// → Mỗi lần lấy vị trí trả về một [GardenLocationRequest] có thể **huỷ**.
//   Khi màn hình bị dispose, gọi `cancel()` → timer được huỷ ngay (nếu không,
//   timer còn pending → widget test assert "A Timer is still pending").
//
// Việc xác định vị trí là "nice to have" (để tính thời tiết), KHÔNG được
// để nó chặn việc tải dữ liệu chính.

import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Một lần yêu cầu vị trí, có thể huỷ.
class GardenLocationRequest {
  GardenLocationRequest._(this._completer, this._timer);

  final Completer<Position?> _completer;
  final Timer? _timer;

  /// Kết quả vị trí (null nếu lỗi / hết thời gian / bị huỷ).
  Future<Position?> get future => _completer.future;

  /// Huỷ yêu cầu + huỷ timer (an toàn khi gọi nhiều lần).
  void cancel() {
    _timer?.cancel();
    if (!_completer.isCompleted) _completer.complete(null);
  }
}

/// Bắt đầu lấy vị trí hiện tại.
///
/// [timeout] mặc định 8 giây — đủ để GPS chạy, đủ ngắn để không treo UI.
GardenLocationRequest requestGardenPosition({
  Duration timeout = const Duration(seconds: 8),
}) {
  final completer = Completer<Position?>();
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete(null);
  });

  unawaited(
    _resolve()
        .then(
          (position) {
            if (!completer.isCompleted) completer.complete(position);
          },
          onError: (Object _) {
            if (!completer.isCompleted) completer.complete(null);
          },
        )
        .whenComplete(timer.cancel),
  );

  return GardenLocationRequest._(completer, timer);
}

/// Lấy vị trí hiện tại, trả `null` nếu không lấy được (có timeout + huỷ timer).
Future<Position?> resolveGardenPosition({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final request = requestGardenPosition(timeout: timeout);
  try {
    return await request.future;
  } finally {
    request.cancel();
  }
}

Future<Position?> _resolve() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 8),
    ),
  );
}
