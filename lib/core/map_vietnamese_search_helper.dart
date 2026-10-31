// lib/core/map_vietnamese_search_helper.dart
//
// Bộ tiện ích xử lý tìm kiếm tiếng Việt toàn diện:
//   1. Khử dấu tiếng Việt chuẩn xác (có dấu hoặc không dấu đều khớp)
//   2. Chuẩn hoá khoảng trắng, loại bỏ ký tự lạ / ký tự đặc biệt
//   3. Hỗ trợ tìm kiếm theo từng từ khóa (token match)
//   4. Chấp nhận lỗi chính tả nhẹ (typo tolerance / Levenshtein distance)

class VietnameseSearchHelper {
  static const Map<String, String> _toneMap = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd',
    'À': 'a', 'Á': 'a', 'Ả': 'a', 'Ã': 'a', 'Ạ': 'a',
    'Ă': 'a', 'Ằ': 'a', 'Ắ': 'a', 'Ẳ': 'a', 'Ẵ': 'a', 'Ặ': 'a',
    'Â': 'a', 'Ầ': 'a', 'Ấ': 'a', 'Ẩ': 'a', 'Ẫ': 'a', 'Ậ': 'a',
    'È': 'e', 'É': 'e', 'Ẻ': 'e', 'Ẽ': 'e', 'Ẹ': 'e',
    'Ê': 'e', 'Ề': 'e', 'Ế': 'e', 'Ể': 'e', 'Ễ': 'e', 'Ệ': 'e',
    'Ì': 'i', 'Í': 'i', 'Ỉ': 'i', 'Ĩ': 'i', 'Ị': 'i',
    'Ò': 'o', 'Ó': 'o', 'Ỏ': 'o', 'Õ': 'o', 'Ọ': 'o',
    'Ô': 'o', 'Ồ': 'o', 'Ố': 'o', 'Ổ': 'o', 'Ỗ': 'o', 'Ộ': 'o',
    'Ơ': 'o', 'Ờ': 'o', 'Ớ': 'o', 'Ở': 'o', 'Ỡ': 'o', 'Ợ': 'o',
    'Ù': 'u', 'Ú': 'u', 'Ủ': 'u', 'Ũ': 'u', 'Ụ': 'u',
    'Ư': 'u', 'Ừ': 'u', 'Ứ': 'u', 'Ử': 'u', 'Ữ': 'u', 'Ự': 'u',
    'Ỳ': 'y', 'Ý': 'y', 'Ỷ': 'y', 'Ỹ': 'y', 'Ỵ': 'y',
    'Đ': 'd',
  };

  /// Chuyển chuỗi tiếng Việt có dấu thành không dấu chữ thường
  static String removeTones(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(_toneMap[char] ?? char);
    }
    return buffer.toString().toLowerCase();
  }

  /// Chuẩn hoá chuỗi: bỏ dấu, loại bỏ ký tự lạ, gộp nhiều khoảng trắng thành 1
  static String normalize(String input) {
    final unaccented = removeTones(input);
    final cleaned = unaccented.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Tách chuỗi thành danh sách từ (tokens)
  static List<String> tokenize(String input) {
    final norm = normalize(input);
    if (norm.isEmpty) return const [];
    return norm.split(' ').where((w) => w.isNotEmpty).toList();
  }

  /// Tính khoảng cách Levenshtein giữa 2 từ để đo độ sai lệch chính tả
  static int levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1, // insertion
          v0[j + 1] + 1, // deletion
          v0[j] + cost, // substitution
        ].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// Đánh giá điểm độ khớp chính xác tên cây (name & scientificName)
  /// Tránh khớp lan man ký tự đơn lẻ vào mô tả.
  static double matchScore(String rawQuery, String name, [String? scientificName]) {
    final normQuery = normalize(rawQuery);
    if (normQuery.isEmpty) return 0.0;

    final normName = normalize(name);
    final normSci = scientificName != null ? normalize(scientificName) : '';

    final queryTokens = tokenize(rawQuery);
    if (queryTokens.isEmpty) return 0.0;

    // 1. Trường hợp từ khóa ngắn (1 hoặc 2 ký tự, vd: "c", "l", "ca"):
    // Chỉ so khớp với tên thông thường tiếng Việt (name), tuyệt đối không khớp tên khoa học Latin
    // để tránh các cây tên tiếng Việt không liên quan (vd gõ "c" ra Bạch đồng nữ vì Latin là Clerodendrum).
    if (normQuery.length <= 2) {
      if (normName.startsWith(normQuery)) return 100.0;
      final words = normName.split(' ');
      if (words.any((w) => w.startsWith(normQuery))) return 85.0;
      return 0.0; // Không liên quan -> không hiển thị
    }

    // 2. Trường hợp từ khóa >= 3 ký tự (vd: "chi", "thien", "chi thien"):
    // Ưu tiên cao nhất cho tên thông thường tiếng Việt
    if (normName == normQuery) return 100.0;
    if (normName.startsWith(normQuery)) return 95.0;
    if (normName.contains(normQuery)) return 85.0;

    final nameWords = normName.split(' ');
    if (nameWords.any((w) => w.startsWith(normQuery))) return 80.0;

    // So khớp theo từng từ khóa tiếng Việt (token match)
    int matchedNameTokens = 0;
    int fuzzyMatches = 0;
    for (final qToken in queryTokens) {
      bool found = false;
      for (final w in nameWords) {
        if (w == qToken || w.startsWith(qToken)) {
          found = true;
          break;
        }
        if (qToken.length >= 4 && w.length >= 4) {
          if (levenshteinDistance(qToken, w) <= 1) {
            fuzzyMatches++;
            found = true;
            break;
          }
        }
      }
      if (found) matchedNameTokens++;
    }

    if (matchedNameTokens == queryTokens.length) {
      return 70.0 + (matchedNameTokens * 5.0) - (fuzzyMatches * 4.0);
    }

    // 3. Chỉ khi từ khóa dài >= 3 ký tự và người dùng có thể đang gõ tên khoa học Latin
    if (normSci.isNotEmpty && normQuery.length >= 3) {
      if (normSci == normQuery) return 65.0;
      if (normSci.startsWith(normQuery)) return 60.0;
      if (normSci.contains(normQuery)) return 50.0;
      final sciWords = normSci.split(' ');
      if (sciWords.any((w) => w.startsWith(normQuery))) return 45.0;
    }

    return 0.0;
  }
}
