fimport 'package:flutter_test/flutter_test.dart';
import 'package:thunghiem1/core/map_vietnamese_search_helper.dart';

void main() {
  group('VietnameseSearchHelper.removeTones', () {
    test('bỏ dấu tiếng Việt', () {
      expect(VietnameseSearchHelper.removeTones('Ngải Cứu'), 'ngai cuu');
      expect(VietnameseSearchHelper.removeTones('Bồ Công Anh'), 'bo cong anh');
      expect(VietnameseSearchHelper.removeTones('Đinh Lăng'), 'dinh lang');
    });
  });

  group('VietnameseSearchHelper.normalize', () {
    test('loại ký tự đặc biệt & gộp khoảng trắng', () {
      expect(
        VietnameseSearchHelper.normalize('  Bạch   Hoa!!  '),
        'bach hoa',
      );
    });
  });

  group('VietnameseSearchHelper.matchScore', () {
    test('khớp chính xác tên → điểm cao nhất', () {
      final score = VietnameseSearchHelper.matchScore('Bồ công anh', 'Bồ công anh');
      expect(score, 100.0);
    });

    test('khớp không dấu với tên có dấu', () {
      final score = VietnameseSearchHelper.matchScore('bo cong anh', 'Bồ công anh');
      expect(score, greaterThan(0));
    });

    test('khớp với tên khoa học Latin', () {
      final score = VietnameseSearchHelper.matchScore(
        'taraxacum',
        'Bồ công anh',
        'Taraxacum mongolicum',
      );
      expect(score, greaterThan(0));
    });

    test('từ khoá quá ngắn không khớp lung tung', () {
      // "c" chỉ nên khớp cây có tên bắt đầu bằng "c",
      // không khớp "Bạch đồng nữ" (tên khoa học Latin bắt đầu bằng C).
      final score = VietnameseSearchHelper.matchScore(
        'c',
        'Bạch đồng nữ',
        'Clerodendrum',
      );
      expect(score, 0.0);
    });

    test('query rỗng → 0 điểm', () {
      expect(VietnameseSearchHelper.matchScore('', 'Bồ công anh'), 0.0);
      expect(VietnameseSearchHelper.matchScore('   ', 'Bồ công anh'), 0.0);
    });

    test('chống lỗi gõ nhẹ (typo tolerance)', () {
      final score = VietnameseSearchHelper.matchScore(
        'bo cong anh',
        'Bồ công anh',
      );
      expect(score, greaterThan(0));
    });
  });

  group('VietnameseSearchHelper.levenshteinDistance', () {
    test('khoảng cách chuẩn', () {
      expect(VietnameseSearchHelper.levenshteinDistance('abc', 'abc'), 0);
      expect(VietnameseSearchHelper.levenshteinDistance('abc', 'abd'), 1);
      expect(VietnameseSearchHelper.levenshteinDistance('', 'abc'), 3);
      expect(VietnameseSearchHelper.levenshteinDistance('kitten', 'sitting'), 3);
    });
  });
}
