import 'package:http/http.dart' as http;
import 'auth_api_service.dart';
import 'secure_storage_service.dart';

/// Buffers each request once so multipart uploads can also be replayed once.
class SessionHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final authenticated = request.headers.keys.any(
      (k) => k.toLowerCase() == 'authorization',
    );
    final sentToken = await SecureStorageService().readToken();
    Future<http.StreamedResponse> attempt(String? token) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = bytes
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects;
      if (authenticated && token != null) {
        copy.headers.removeWhere((k, _) => k.toLowerCase() == 'authorization');
        copy.headers['Authorization'] = 'Bearer $token';
      }
      return _inner.send(copy);
    }

    final response = await attempt(sentToken);
    if (response.statusCode != 401 || !authenticated) return response;
    final latest = await SecureStorageService().readToken();
    final token = latest != sentToken
        ? latest
        : await AuthApiService().refreshToken();
    if (token == null) return response;
    await response.stream.drain<void>();
    return attempt(token);
  }

  @override
  void close() => _inner.close();
}
