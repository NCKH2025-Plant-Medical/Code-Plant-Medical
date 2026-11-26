import 'package:flutter_test/flutter_test.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';

void main() {
  test('Nearby points share a public cell and cache does not move it', () {
    final a = PlantMapMarker(
      id: 'a',
      name: 'A',
      source: PlantSource.system,
      latitude: 21.0123,
      longitude: 105.0234,
    );
    final b = PlantMapMarker(
      id: 'b',
      name: 'B',
      source: PlantSource.system,
      latitude: 21.0199,
      longitude: 105.0299,
    );
    expect(a.location, b.location);
    expect(a.latitude, closeTo(21.015, 0.0000001));
    expect(a.longitude, closeTo(105.025, 0.0000001));
    expect(PlantMapMarker.fromCacheJson(a.toCacheJson()).location, a.location);
  });
  test('Protection flag survives API parsing and cache', () {
    final plant = PlantMapMarker.fromSystemJson({
      'id': 'rare',
      'latitude': 21.05,
      'longitude': 105.05,
      'is_protected': true,
    });
    expect(plant.isProtected, isTrue);
    expect(
      PlantMapMarker.fromCacheJson(plant.toCacheJson()).isProtected,
      isTrue,
    );
  });
}
