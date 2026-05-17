import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/sighting.dart';

void main() {
  group('Sighting', () {
    test('fromMap creates Sighting from RTDB snapshot data', () {
      final data = <String, dynamic>{
        'fishName': 'Bangus',
        'fishId': 'fish_1',
        'displayName': 'John',
        'userId': 'abc123',
        'notes': 'Saw near reef',
        'latitude': 14.5995,
        'longitude': 120.9842,
        'createdAt': 1700000000000,
        'status': 'pending',
        'isAnonymous': false,
      };

      final sighting = Sighting.fromMap('s1', data);

      expect(sighting.id, 's1');
      expect(sighting.fishName, 'Bangus');
      expect(sighting.fishId, 'fish_1');
      expect(sighting.displayName, 'John');
      expect(sighting.userId, 'abc123');
      expect(sighting.notes, 'Saw near reef');
      expect(sighting.latitude, 14.5995);
      expect(sighting.longitude, 120.9842);
      expect(sighting.createdAt, '1700000000000');
      expect(sighting.status, SightingStatus.pending);
      expect(sighting.isAnonymous, false);
    });

    test('fromMap defaults missing status to pending', () {
      final data = <String, dynamic>{
        'fishName': 'Test',
        'fishId': 'f1',
      };
      final sighting = Sighting.fromMap('s2', data);
      expect(sighting.status, SightingStatus.pending);
    });

    test('fromMap handles createdAt as int', () {
      final data = <String, dynamic>{
        'fishName': 'Test',
        'fishId': 'f1',
        'createdAt': 1700000000000,
      };
      final sighting = Sighting.fromMap('s3', data);
      expect(sighting.createdAt, '1700000000000');
    });

    test('toMap produces correct map', () {
      final sighting = Sighting(
        id: 's1',
        fishName: 'Bangus',
        fishId: 'fish_1',
        displayName: 'John',
        userId: 'abc123',
        notes: 'Saw near reef',
        latitude: 14.5995,
        longitude: 120.9842,
        createdAt: '1700000000000',
        status: SightingStatus.pending,
        isAnonymous: false,
      );

      final map = sighting.toMap();
      expect(map['fishName'], 'Bangus');
      expect(map['status'], 'pending');
      expect(map['isAnonymous'], false);
    });

    test('copyWith creates modified copy', () {
      final sighting = Sighting(
        id: 's1',
        fishName: 'Bangus',
        fishId: 'fish_1',
        displayName: 'John',
        userId: 'abc123',
        notes: '',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: '0',
        status: SightingStatus.pending,
        isAnonymous: false,
      );

      final updated = sighting.copyWith(status: SightingStatus.verified);
      expect(updated.status, SightingStatus.verified);
      expect(updated.id, 's1');
      expect(sighting.status, SightingStatus.pending);
    });

    test('SightingStatus parsing handles verified and rejected', () {
      expect(sightingStatusFromString('verified'), SightingStatus.verified);
      expect(sightingStatusFromString('rejected'), SightingStatus.rejected);
      expect(sightingStatusFromString('pending'), SightingStatus.pending);
      expect(sightingStatusFromString('unknown'), SightingStatus.pending);
    });
  });
}
