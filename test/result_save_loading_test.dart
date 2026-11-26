import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunghiem1/models/user_plant.dart';
import 'package:thunghiem1/screens/results_screen.dart';
import 'package:thunghiem1/services/user_plant_api_service.dart';

class PendingSaveApi extends UserPlantApiService {
  final pending = Completer<UserPlant>();
  int calls = 0;
  @override
  Future<UserPlant> saveUserPlant({
    required String imagePath,
    required String name,
    String? plantId,
    String? scientificName,
    double? confidence,
    double? latitude,
    double? longitude,
    String? notes,
  }) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('only selected save spins; failure unlocks buttons', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('result-test');
    final file = File('${directory.path}/image.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
        ),
      );
    final api = PendingSaveApi();
    addTearDown(() {
      api.dispose();
      directory.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          pathImg: file.path,
          userPlantApi: api,
          result: {
            'predictions': [
              for (var i = 0; i < 3; i++)
                {
                  'plant_id': 'plant-$i',
                  'common_name': 'Cây $i',
                  'scientific_name': 'Plant $i',
                  'confidence': 90 - i,
                },
            ],
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(api.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsNWidgets(2));
    for (final icon in find.byIcon(Icons.bookmark_add_outlined).evaluate()) {
      final button = find.ancestor(
        of: find.byWidget(icon.widget),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    }
    api.pending.completeError(Exception('Không thể lưu ảnh'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Lưu'), findsOneWidget);
    expect(find.text('Không thể lưu ảnh'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
