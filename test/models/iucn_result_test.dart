import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/iucn_result.dart';

void main() {
  group('IucnResult', () {
    test('fromApiMap creates IucnResult from IUCN API response', () {
      final apiMap = <String, dynamic>{
        'category': 'VU',
        'taxonid': 12345,
        'population_trend': 'Decreasing',
      };

      final result = IucnResult.fromApiMap(apiMap);

      expect(result.category, 'VU');
      expect(result.conservationStatus, 'Vulnerable (VU)');
      expect(result.populationTrend, 'Decreasing');
      expect(result.iucnUrl, 'https://www.iucnredlist.org/species/12345');
    });

    test('fromApiMap handles missing category as NE', () {
      final apiMap = <String, dynamic>{};
      final result = IucnResult.fromApiMap(apiMap);

      expect(result.category, 'NE');
      expect(result.conservationStatus, 'Not Evaluated (NE)');
    });

    test('unknown sentinel has NE category', () {
      expect(IucnResult.unknown.category, 'NE');
      expect(IucnResult.unknown.conservationStatus, 'Not Evaluated (NE)');
      expect(IucnResult.unknown.populationTrend, isNull);
    });
  });
}
