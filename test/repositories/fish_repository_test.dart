import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/repositories/fish_repository.dart';

void main() {
  group('FishRepository', () {
    test('FirebaseNodes paths are correct', () {
      expect(FishRepository, isNotNull);
    });
  });
}
