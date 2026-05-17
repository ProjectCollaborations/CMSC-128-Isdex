import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/fish.dart';
import 'package:isdex/viewmodels/fish_detail_viewmodel.dart';

class FakeFishDetailRepo {
  final Map<String, Fish> _fish = {};

  void setFish(Fish fish) {
    _fish[fish.id] = fish;
  }

  Future<Fish?> getById(String id) async => _fish[id];
}

void main() {
  group('FishDetailViewModel', () {
    late FishDetailViewModel vm;
    late FakeFishDetailRepo fakeRepo;

    final testFish = Fish(
      id: 'fish1',
      commonName: 'Clownfish',
      scientificName: 'Amphiprioninae',
      localName: 'Clown',
      habitat: 'Saltwater',
      sizeRange: '8-11 cm',
      identifyingFeatures: ['Orange body', 'White stripes'],
      imageUrl: 'assets/images/fish/clownfish.png',
      conservationStatus: 'Least Concern (LC)',
      conservationDetails: 'Stable population',
      distribution: 'Indo-Pacific',
    );

    setUp(() {
      fakeRepo = FakeFishDetailRepo();
      vm = FishDetailViewModel(fakeRepo.getById);
    });

    test('initial state has null fish, not loading', () {
      expect(vm.fish, isNull);
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNull);
    });

    test('loadFish sets fish on success', () async {
      fakeRepo.setFish(testFish);
      await vm.loadFish('fish1');
      expect(vm.fish, isNotNull);
      expect(vm.fish!.commonName, 'Clownfish');
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNull);
    });

    test('loadFish sets error on not found', () async {
      await vm.loadFish('nonexistent');
      expect(vm.fish, isNull);
      expect(vm.error, isNotNull);
      expect(vm.isLoading, isFalse);
    });

    test('loadFish sets isLoading during fetch', () async {
      fakeRepo.setFish(testFish);
      final future = vm.loadFish('fish1');
      expect(vm.isLoading, isTrue);
      await future;
      expect(vm.isLoading, isFalse);
    });
  });
}
