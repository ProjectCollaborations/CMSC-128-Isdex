import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/map_location.dart';
import 'package:isdex/models/fish.dart';
import 'package:isdex/viewmodels/map_viewmodel.dart';

class FakeMapRepo {
  final StreamController<List<MapLocation>> _controller =
      StreamController<List<MapLocation>>.broadcast();

  void emitLocations(List<MapLocation> locations) {
    _controller.add(locations);
  }

  Stream<List<MapLocation>> watchAll() => _controller.stream;

  void dispose() => _controller.close();
}

class FakeFishByIdRepo {
  final Map<String, Fish> _fish = {};

  void setFish(Fish fish) {
    _fish[fish.id] = fish;
  }

  Future<Fish?> getById(String id) async => _fish[id];
}

Stream<List<Fish>> emptyFishStream() => Stream.value([]);

void main() {
  group('MapViewModel', () {
    late MapViewModel vm;
    late FakeMapRepo fakeMapRepo;

    final testLocations = [
      MapLocation(
          id: 'loc1',
          fishId: 'fish1',
          latitude: 12.0,
          longitude: 121.0,
          region: 'Coral Reef'),
      MapLocation(
          id: 'loc2',
          fishId: 'fish2',
          latitude: 13.0,
          longitude: 122.0,
          region: 'Mangrove Bay'),
    ];

    setUp(() {
      fakeMapRepo = FakeMapRepo();
    });

    tearDown(() {
      vm.dispose();
      fakeMapRepo.dispose();
    });

    test('default mode loads all map locations', () async {
      vm = MapViewModel(
        watchAll: fakeMapRepo.watchAll,
        fishById: (_) async => null,
        watchAllFish: emptyFishStream,
      );
      fakeMapRepo.emitLocations(testLocations);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.locations.length, 2);
      expect(vm.isLoading, isFalse);
    });

    test('specific fish mode filters by fishId', () async {
      final fakeFishRepo = FakeFishByIdRepo();
      fakeFishRepo.setFish(Fish(
        id: 'fish1',
        commonName: 'Clownfish',
        scientificName: 'Amphiprioninae',
        localName: 'Clown',
        habitat: 'Saltwater',
        sizeRange: '8-11 cm',
        identifyingFeatures: [],
        imageUrl: '',
        conservationStatus: 'LC',
        conservationDetails: '',
        distribution: '',
      ));
      vm = MapViewModel(
        watchAll: fakeMapRepo.watchAll,
        fishById: fakeFishRepo.getById,
        watchAllFish: emptyFishStream,
        fishId: 'fish1',
      );
      fakeMapRepo.emitLocations(testLocations);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.locations.length, 1);
      expect(vm.locations.first.fishId, 'fish1');
    });

    test('isLoading is true before data arrives', () {
      vm = MapViewModel(
        watchAll: fakeMapRepo.watchAll,
        fishById: (_) async => null,
        watchAllFish: emptyFishStream,
      );
      expect(vm.isLoading, isTrue);
    });

    test('specificFishActive updates based on fish existence', () async {
      final fakeFishRepo = FakeFishByIdRepo();
      final fish = Fish(
        id: 'fish1',
        commonName: 'Clownfish',
        scientificName: 'Amphiprioninae',
        localName: 'Clown',
        habitat: 'Saltwater',
        sizeRange: '8-11 cm',
        identifyingFeatures: [],
        imageUrl: '',
        conservationStatus: 'LC',
        conservationDetails: '',
        distribution: '',
      );
      fakeFishRepo.setFish(fish);

      vm = MapViewModel(
        watchAll: fakeMapRepo.watchAll,
        fishById: fakeFishRepo.getById,
        watchAllFish: emptyFishStream,
        fishId: 'fish1',
      );

      fakeMapRepo.emitLocations([]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.specificFishActive, isTrue);
    });

    test('specific fish mode handles missing fish', () async {
      vm = MapViewModel(
        watchAll: fakeMapRepo.watchAll,
        fishById: (_) async => null,
        watchAllFish: emptyFishStream,
        fishId: 'nonexistent',
      );
      fakeMapRepo.emitLocations(testLocations);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.specificFishActive, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.locations, isEmpty);
    });
  });
}
