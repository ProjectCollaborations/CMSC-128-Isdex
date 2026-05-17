import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/fish.dart';
import 'package:isdex/viewmodels/fish_catalog_viewmodel.dart';

class FakeFishRepo {
  final StreamController<List<Fish>> _controller =
      StreamController<List<Fish>>.broadcast();

  void emitFish(List<Fish> fish) {
    _controller.add(fish);
  }

  Stream<List<Fish>> watchAll() => _controller.stream;

  void dispose() => _controller.close();
}

void main() {
  group('FishCatalogViewModel', () {
    late FishCatalogViewModel vm;
    late FakeFishRepo fakeRepo;

    final testFish = [
      Fish(
        id: '1',
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
      ),
      Fish(
        id: '2',
        commonName: 'Bangus',
        scientificName: 'Chanos chanos',
        localName: 'Bangus',
        habitat: 'Brackish Water',
        sizeRange: '50-180 cm',
        identifyingFeatures: ['Elongated body', 'Single dorsal fin'],
        imageUrl: 'assets/images/fish/bangus.png',
        conservationStatus: 'Least Concern (LC)',
        conservationDetails: 'Widely farmed',
        distribution: 'Indo-Pacific',
      ),
    ];

    setUp(() {
      fakeRepo = FakeFishRepo();
      vm = FishCatalogViewModel(fakeRepo.watchAll);
    });

    tearDown(() {
      vm.dispose();
      fakeRepo.dispose();
    });

    test('initial state has empty fish list, no search, habitat All', () {
      expect(vm.allFish, isEmpty);
      expect(vm.filteredFish, isEmpty);
      expect(vm.searchQuery, isEmpty);
      expect(vm.selectedHabitat, 'All');
      expect(vm.isLoading, isTrue);
    });

    test('receives fish list from stream and sets isLoading false', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.allFish.length, 2);
      expect(vm.filteredFish.length, 2);
      expect(vm.isLoading, isFalse);
    });

    test('search filters by commonName', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      vm.search('clown');
      expect(vm.filteredFish.length, 1);
      expect(vm.filteredFish.first.commonName, 'Clownfish');
    });

    test('search filters by scientificName', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      vm.search('Chanos');
      expect(vm.filteredFish.length, 1);
      expect(vm.filteredFish.first.scientificName, 'Chanos chanos');
    });

    test('search filters by localName', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      vm.search('Bangus');
      expect(vm.filteredFish.length, 1);
      expect(vm.filteredFish.first.id, '2');
    });

    test('filterByHabitat filters correctly', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      vm.filterByHabitat('Saltwater');
      expect(vm.filteredFish.length, 1);
      expect(vm.filteredFish.first.commonName, 'Clownfish');
    });

    test('clearSearch resets to full list', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      vm.search('clown');
      expect(vm.filteredFish.length, 1);
      vm.clearSearch();
      expect(vm.filteredFish.length, 2);
      expect(vm.searchQuery, isEmpty);
    });

    test('combined search and habitat filter', () async {
      fakeRepo.emitFish(testFish);
      await Future.delayed(const Duration(milliseconds: 50));
      vm.search('a');
      vm.filterByHabitat('Saltwater');
      expect(vm.filteredFish.length, 1);
      expect(vm.filteredFish.first.commonName, 'Clownfish');
    });
  });
}
