import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thunghiem1/services/review_feedback_service.dart';

void main() {
  test('review receipts are separated by account on the same device', () async {
    SharedPreferences.setMockInitialValues({
      'review_feedback_revocations_v1': jsonEncode([
        {'prediction_id': 'legacy-unowned'},
      ]),
      'review_feedback_revocations_v2_user-a': jsonEncode([
        {'prediction_id': 'photo-a'},
      ]),
      'review_feedback_revocations_v2_user-b': jsonEncode([
        {'prediction_id': 'photo-b'},
      ]),
    });

    final userA = await ReviewFeedbackService.savedEntries('user-a');
    final userB = await ReviewFeedbackService.savedEntries('user-b');

    expect(userA.map((e) => e['prediction_id']), ['photo-a']);
    expect(userB.map((e) => e['prediction_id']), ['photo-b']);
    expect(await ReviewFeedbackService.savedEntries('new-user'), isEmpty);
  });
}
