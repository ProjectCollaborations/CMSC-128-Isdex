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
      expect(sighting.isReported, false);
      expect(sighting.geoValidationStatus, 'unknown');
      expect(sighting.geoValidationMessage, '');
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

    test('fromMap reads isReported as true', () {
      final data = <String, dynamic>{
        'fishName': 'Test',
        'fishId': 'f1',
        'isReported': true,
      };
      final sighting = Sighting.fromMap('s4', data);
      expect(sighting.isReported, true);
    });

    test('fromMap reads geoValidationStatus and geoValidationMessage', () {
      final data = <String, dynamic>{
        'fishName': 'Test',
        'fishId': 'f1',
        'geoValidationStatus': 'water',
        'geoValidationMessage': 'Detected on water',
      };
      final sighting = Sighting.fromMap('s5', data);
      expect(sighting.geoValidationStatus, 'water');
      expect(sighting.geoValidationMessage, 'Detected on water');
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
      expect(map['isReported'], false);
      expect(map['geoValidationStatus'], 'unknown');
      expect(map['geoValidationMessage'], '');
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

      final updated =
          sighting.copyWith(status: SightingStatus.approved);
      expect(updated.status, SightingStatus.approved);
      expect(updated.id, 's1');
      expect(sighting.status, SightingStatus.pending);
    });

    test('SightingStatus parsing handles approved and rejected', () {
      expect(sightingStatusFromString('approved'), SightingStatus.approved);
      expect(sightingStatusFromString('rejected'), SightingStatus.rejected);
      expect(sightingStatusFromString('pending'), SightingStatus.pending);
      expect(sightingStatusFromString('unknown'), SightingStatus.pending);
    });

    test('toMap includes isReported, geoValidationStatus, geoValidationMessage when set', () {
      final sighting = Sighting(
        id: 's6',
        fishName: 'Test',
        fishId: 'f1',
        displayName: 'User',
        userId: 'uid',
        notes: '',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: '0',
        status: SightingStatus.pending,
        isAnonymous: false,
        isReported: true,
        geoValidationStatus: 'water',
        geoValidationMessage: 'On water',
      );

      final map = sighting.toMap();
      expect(map['isReported'], true);
      expect(map['geoValidationStatus'], 'water');
      expect(map['geoValidationMessage'], 'On water');
    });

    test('copyWith handles isReported and geoValidationStatus', () {
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

      final updated = sighting.copyWith(
        isReported: true,
        geoValidationStatus: 'land',
        geoValidationMessage: 'On land',
      );
      expect(updated.isReported, true);
      expect(updated.geoValidationStatus, 'land');
      expect(updated.geoValidationMessage, 'On land');
    });
  });
}
