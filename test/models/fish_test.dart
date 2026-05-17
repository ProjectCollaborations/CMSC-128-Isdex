import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/fish.dart';

void main() {
  group('Fish', () {
    test('fromMap creates Fish from RTDB snapshot data', () {
      final data = <String, dynamic>{
        'commonName': 'Bangus',
        'scientificName': 'Chanos chanos',
        'localName': 'Bangus',
        'habitat': 'Saltwater',
        'sizeRange': 'Up to 1.8m',
        'identifyingFeatures': ['Silver body', 'Forked tail'],
        'imageUrl': 'https://example.com/bangus.png',
        'conservationStatus': 'Least Concern (LC)',
        'conservationDetails': 'Stable population',
        'distribution': 'Indo-Pacific',
      };

      final fish = Fish.fromMap('fish_1', data);

      expect(fish.id, 'fish_1');
      expect(fish.commonName, 'Bangus');
      expect(fish.scientificName, 'Chanos chanos');
      expect(fish.localName, 'Bangus');
      expect(fish.habitat, 'Saltwater');
      expect(fish.sizeRange, 'Up to 1.8m');
      expect(fish.identifyingFeatures, ['Silver body', 'Forked tail']);
      expect(fish.imageUrl, 'https://example.com/bangus.png');
      expect(fish.conservationStatus, 'Least Concern (LC)');
      expect(fish.conservationDetails, 'Stable population');
      expect(fish.distribution, 'Indo-Pacific');
    });

    test('fromMap handles missing fields with defaults', () {
      final data = <String, dynamic>{};
      final fish = Fish.fromMap('fish_2', data);

      expect(fish.id, 'fish_2');
      expect(fish.commonName, '');
      expect(fish.identifyingFeatures, []);
    });

    test('toMap produces correct map', () {
      final fish = Fish(
        id: 'fish_1',
        commonName: 'Bangus',
        scientificName: 'Chanos chanos',
        localName: 'Bangus',
        habitat: 'Saltwater',
        sizeRange: 'Up to 1.8m',
        identifyingFeatures: ['Silver body'],
        imageUrl: 'https://example.com/bangus.png',
        conservationStatus: 'Least Concern (LC)',
        conservationDetails: 'Stable',
        distribution: 'Indo-Pacific',
      );

      final map = fish.toMap();
      expect(map['commonName'], 'Bangus');
      expect(map['identifyingFeatures'], ['Silver body']);
    });

    test('copyWith creates modified copy', () {
      final fish = Fish(
        id: 'fish_1',
        commonName: 'Bangus',
        scientificName: 'Chanos chanos',
        localName: 'Bangus',
        habitat: 'Saltwater',
        sizeRange: 'Up to 1.8m',
        identifyingFeatures: [],
        imageUrl: '',
        conservationStatus: 'LC',
        conservationDetails: '',
        distribution: 'Indo-Pacific',
      );

      final updated = fish.copyWith(commonName: 'Milkfish');
      expect(updated.commonName, 'Milkfish');
      expect(updated.id, 'fish_1');
      expect(fish.commonName, 'Bangus');
    });

    test('fromMap handles identifyingFeatures as List<dynamic>', () {
      final data = <String, dynamic>{
        'commonName': 'Test',
        'scientificName': 'Testus testus',
        'localName': 'T',
        'habitat': 'Freshwater',
        'sizeRange': '10cm',
        'identifyingFeatures': ['Feature A', 'Feature B'],
        'imageUrl': '',
        'conservationStatus': 'NE',
        'conservationDetails': '',
        'distribution': 'Local',
      };

      final fish = Fish.fromMap('f1', data);
      expect(fish.identifyingFeatures, ['Feature A', 'Feature B']);
    });
  });
}
