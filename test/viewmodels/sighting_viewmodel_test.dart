import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/sighting.dart';
import 'package:isdex/models/fish.dart';
import 'package:isdex/viewmodels/sighting_viewmodel.dart';

class FakeSightingRepo {
  final StreamController<List<Sighting>> _controller =
      StreamController<List<Sighting>>.broadcast();
  final List<String> deletedIds = [];
  final List<String> reportedIds = [];

  void emitSightings(List<Sighting> sightings) {
    _controller.add(sightings);
  }

  Stream<List<Sighting>> watchAll() => _controller.stream;

  Future<String> push(Sighting s) async => 'new-id-${s.fishName}';

  Future<void> delete(String id) async {
    deletedIds.add(id);
  }

  Future<void> reportSighting(String id) async {
    reportedIds.add(id);
  }

  void dispose() => _controller.close();
}

class FakeFishRepo {
  final StreamController<List<Fish>> _controller =
      StreamController<List<Fish>>.broadcast();
  final List<Fish> fishList = [];

  void emitFish(List<Fish> fish) {
    _controller.add(fish);
  }

  Stream<List<Fish>> watchAll() => _controller.stream;

  void dispose() => _controller.close();
}

class FakeAuthVm {
  String? uid = 'user123';
  String? email = 'test@example.com';
  String? displayName;
  bool get isLoggedIn => uid != null;
}

void main() {
  group('SightingViewModel', () {
    late SightingViewModel vm;
    late FakeSightingRepo fakeSightingRepo;
    late FakeFishRepo fakeFishRepo;
    late FakeAuthVm fakeAuth;

    setUp(() {
      fakeSightingRepo = FakeSightingRepo();
      fakeFishRepo = FakeFishRepo();
      fakeAuth = FakeAuthVm();
      vm = SightingViewModel(
        watchAllSightings: fakeSightingRepo.watchAll,
        pushSighting: fakeSightingRepo.push,
        deleteSighting: fakeSightingRepo.delete,
        reportSighting: fakeSightingRepo.reportSighting,
        watchAllFish: fakeFishRepo.watchAll,
        currentUserId: () => fakeAuth.uid,
        currentUserDisplay: () =>
            fakeAuth.displayName ?? fakeAuth.email?.split('@')[0] ?? 'Anonymous',
      );
    });

    tearDown(() {
      vm.dispose();
      fakeSightingRepo.dispose();
      fakeFishRepo.dispose();
    });

    test('initial state has empty sightings and loading', () {
      expect(vm.sightings, isEmpty);
      expect(vm.isLoading, isTrue);
    });

    test('receives sightings from stream', () async {
      final sightings = [
        Sighting(
            id: 's1',
            fishName: 'Clownfish',
            fishId: 'fish1',
            displayName: 'User1',
            userId: 'user123',
            notes: 'Seen at reef',
            latitude: 12.0,
            longitude: 121.0,
            createdAt: '1000',
            status: SightingStatus.pending,
            isAnonymous: false),
      ];
      fakeSightingRepo.emitSightings(sightings);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.sightings.length, 1);
      expect(vm.isLoading, isFalse);
    });

    test('deleteSighting calls repository', () async {
      await vm.deleteSighting('s1');
      expect(fakeSightingRepo.deletedIds, ['s1']);
    });

    test('reportSighting calls repository', () async {
      await vm.reportSighting('s2');
      expect(fakeSightingRepo.reportedIds, ['s2']);
    });

    test('getVisibleSightings filters by status and fishId', () async {
      fakeFishRepo.emitFish([
        Fish(
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
            distribution: ''),
      ]);

      final sightings = [
        Sighting(
            id: 's1',
            fishName: 'Clownfish',
            fishId: 'fish1',
            displayName: 'User1',
            userId: 'other',
            notes: '',
            latitude: 12.0,
            longitude: 121.0,
            createdAt: '1000',
            status: SightingStatus.approved,
            isAnonymous: false),
        Sighting(
            id: 's2',
            fishName: 'Bangus',
            fishId: 'fish2',
            displayName: 'User2',
            userId: 'other',
            notes: '',
            latitude: 13.0,
            longitude: 122.0,
            createdAt: '2000',
            status: SightingStatus.pending,
            isAnonymous: false),
        Sighting(
            id: 's3',
            fishName: 'Salmon',
            fishId: 'invalid',
            displayName: 'User3',
            userId: 'other',
            notes: '',
            latitude: 14.0,
            longitude: 123.0,
            createdAt: '3000',
            status: SightingStatus.approved,
            isAnonymous: false),
      ];

      fakeSightingRepo.emitSightings(sightings);
      await Future.delayed(const Duration(milliseconds: 50));

      final visible = vm.getVisibleSightings('user123');
      expect(visible.length, 1);
      expect(visible.first.id, 's1');
    });
  });
}
