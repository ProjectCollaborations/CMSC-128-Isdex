import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/map_location.dart';

void main() {
  group('MapLocation', () {
    final mapData = <String, dynamic>{
      'fishId': 'fish1',
      'latitude': 12.345,
      'longitude': 121.567,
      'region': 'Coral Reef Bay',
    };

    test('fromMap creates MapLocation from RTDB data', () {
      final loc = MapLocation.fromMap('loc1', mapData);
      expect(loc.id, 'loc1');
      expect(loc.fishId, 'fish1');
      expect(loc.latitude, 12.345);
      expect(loc.longitude, 121.567);
      expect(loc.region, 'Coral Reef Bay');
    });

    test('fromMap handles missing fields with defaults', () {
      final loc = MapLocation.fromMap('loc2', {});
      expect(loc.fishId, '');
      expect(loc.latitude, 12.8797);
      expect(loc.longitude, 121.774);
      expect(loc.region, '');
    });

    test('toMap produces correct map', () {
      final loc = MapLocation(
        id: 'loc1',
        fishId: 'fish1',
        latitude: 12.345,
        longitude: 121.567,
        region: 'Coral Reef Bay',
      );
      final m = loc.toMap();
      expect(m['fishId'], 'fish1');
      expect(m['latitude'], 12.345);
      expect(m['longitude'], 121.567);
      expect(m['region'], 'Coral Reef Bay');
    });

    test('copyWith creates modified copy', () {
      final loc = MapLocation(
        id: 'loc1',
        fishId: 'fish1',
        latitude: 12.345,
        longitude: 121.567,
        region: 'Coral Reef Bay',
      );
      final copy = loc.copyWith(region: 'Updated Region');
      expect(copy.region, 'Updated Region');
      expect(copy.fishId, 'fish1');
      expect(copy.id, 'loc1');
    });
  });
}
