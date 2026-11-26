import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thunghiem1/models/image_response.dart';
import 'package:thunghiem1/models/user_plant.dart';
import 'package:thunghiem1/services/history_service.dart';
import 'package:thunghiem1/services/user_plant_api_service.dart';

void main() {
  final record = <String, dynamic>{
    'id': 'saved-1',
    'name': 'Ngải cứu',
    'scientific_name': 'Artemisia vulgaris',
    'confidence': '94.20%',
    'image_url': 'https://example.com/plant.jpg',
    'thumbnail_url': 'https://example.com/thumb.jpg',
    'lat': 0.0,
    'lng': 105.8,
    'created_at': '2026-11-12T10:00:00Z',
  };

  test('history reads backend metadata, date and valid zero coordinate', () {
    final image = ImageResponse.fromJson(record);
    expect(image.commonName, 'Ngải cứu');
    expect(image.scientificName, 'Artemisia vulgaris');
    expect(image.confidence, 94.2);
    expect(image.savedAt, DateTime.utc(2026, 11, 12, 10));
    expect(image.displayImageUrl, record['thumbnail_url']);
    expect(image.hasLocation, isTrue);
    expect(UserPlant.fromJson(record).capturedAt, image.savedAt);
    expect(UserPlant.fromJson(record).hasLocation, isTrue);
    expect(ImageResponse.fromJson({...record, 'lat': 91}).hasLocation, isFalse);
    expect(
      ImageResponse.fromJson({...record, 'lat': null}).hasLocation,
      isFalse,
    );
  });

  test('history loads all pages and sorts newest first', () async {
    final pages = <int>[];
    final service = HistoryService(
      tokenReader: () async => 'test-token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        final page = int.parse(request.url.queryParameters['page']!);
        pages.add(page);
        return http.Response(
          jsonEncode({
            'total': 2,
            'page': page,
            'limit': 1,
            'items': [
              {
                ...record,
                'id': 'saved-$page',
                'created_at': '2026-11-${10 + page}T10:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    final images = await service.getHistory(limit: 1);
    expect(pages, [1, 2]);
    expect(images.map((image) => image.id), ['saved-2', 'saved-1']);
  });

  test('history surfaces authentication errors', () async {
    final service = HistoryService(
      tokenReader: () async => 'expired',
      client: MockClient((_) async => http.Response('', 401)),
    );
    addTearDown(service.dispose);
    await expectLater(service.getHistory(), throwsA(isA<Exception>()));
  });

  test(
    'save uploads user image and metadata through injected client',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'plant-save-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/plant.jpg',
      ).writeAsBytes([1, 2, 3]);
      final service = UserPlantApiService(
        tokenReader: () async => 'test-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          final body = utf8.decode(request.bodyBytes, allowMalformed: true);
          expect(body, contains('filename="plant.jpg"'));
          expect(body, contains('name="image"'));
          expect(body, contains('Ngải cứu'));
          expect(body, contains('Artemisia vulgaris'));
          expect(body, contains('94.20'));
          expect(body, contains('16.000000'));
          expect(body, contains('105.800000'));
          return http.Response.bytes(utf8.encode(jsonEncode(record)), 201);
        }),
      );
      addTearDown(service.dispose);
      final saved = await service.saveUserPlant(
        imagePath: file.path,
        name: 'Ngải cứu',
        plantId: 'ngai_cuu',
        scientificName: 'Artemisia vulgaris',
        confidence: 94.2,
        latitude: 16,
        longitude: 105.8,
      );
      expect(saved.id, 'saved-1');
      expect(saved.imageUrl, record['image_url']);
    },
  );

  test(
    'save without GPS omits coordinates and rejects invalid success',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'plant-save-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/plant.jpg').writeAsBytes([1]);
      final service = UserPlantApiService(
        tokenReader: () async => 'test-token',
        client: MockClient((request) async {
          final body = utf8.decode(request.bodyBytes, allowMalformed: true);
          expect(body, isNot(contains('name="latitude"')));
          expect(body, isNot(contains('name="longitude"')));
          return http.Response('{}', 201);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.saveUserPlant(imagePath: file.path, name: 'Cây'),
        throwsA(isA<Exception>()),
      );
    },
  );
  for (final jsonError in [true, false]) {
    test('save handles 502: JSON=$jsonError', () async {
      final directory = await Directory.systemTemp.createTemp(
        'plant-error-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/plant.jpg').writeAsBytes([1]);
      const detail = 'Máy chủ chưa cấu hình đầy đủ Cloudinary.';
      final service = UserPlantApiService(
        tokenReader: () async => 'test-token',
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonError
                  ? jsonEncode({'detail': detail})
                  : '<html>Bad Gateway</html>',
            ),
            502,
          ),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.saveUserPlant(imagePath: file.path, name: 'Cây'),
        throwsA(
          predicate(
            (error) => error.toString().contains(jsonError ? detail : '(502)'),
          ),
        ),
      );
    });
  }
  test(
    'history page requests six items and does not fetch other pages',
    () async {
      var calls = 0;
      final service = HistoryService(
        tokenReader: () async => 'token',
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters, {'page': '2', 'limit': '6'});
          return http.Response(
            jsonEncode({
              'total': 13,
              'items': [record],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      final page = await service.getPage(2);
      expect(page.total, 13);
      expect(page.items.length, 1);
      expect(calls, 1);
    },
  );
  test(
    'delete selection and all use distinct authenticated endpoints',
    () async {
      final paths = <String>[];
      final service = HistoryService(
        tokenReader: () async => 'token',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          paths.add(request.url.path);
          if (request.url.path.endsWith('batch-delete')) {
            expect(jsonDecode(request.body)['ids'], ['one', 'two']);
          }
          return http.Response('{"deleted_count":2}', 200);
        }),
      );
      addTearDown(service.dispose);
      expect(await service.deleteItems(ids: {}), 0);
      expect(paths, isEmpty);
      expect(await service.deleteItems(ids: {'one', 'two'}), 2);
      expect(await service.deleteItems(), 2);
      expect(paths, [
        '/api/v1/user-plants/batch-delete',
        '/api/v1/user-plants/delete-all',
      ]);
    },
  );
  test('legacy UTC and explicit timezone represent the same instant', () {
    for (final date in [
      '2026-11-12T10:00:00',
      '2026-11-12T10:00:00Z',
      '2026-11-12T17:00:00+07:00',
    ]) {
      expect(
        ImageResponse.fromJson({
          ...record,
          'created_at': date,
        }).savedAt!.toUtc(),
        DateTime.utc(2026, 11, 12, 10),
      );
    }
  });
}
