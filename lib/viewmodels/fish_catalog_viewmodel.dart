import 'dart:async';
import 'package:flutter/material.dart';
import '../models/fish.dart';

typedef FishStreamFactory = Stream<List<Fish>> Function();

class FishCatalogViewModel extends ChangeNotifier {
  final FishStreamFactory _watchAll;

  List<Fish> _allFish = [];
  List<Fish> _filteredFish = [];
  String _searchQuery = '';
  String _selectedHabitat = 'All';
  bool _isLoading = true;
  StreamSubscription<List<Fish>>? _sub;

  List<Fish> get allFish => _allFish;
  List<Fish> get filteredFish => _filteredFish;
  String get searchQuery => _searchQuery;
  String get selectedHabitat => _selectedHabitat;
  bool get isLoading => _isLoading;

  static const List<String> habitats = [
    'All',
    'Saltwater',
    'Freshwater',
    'Brackish Water',
  ];

  FishCatalogViewModel(this._watchAll) {
    _sub = _watchAll().listen(_onData, onError: _onError);
  }

  void _onData(List<Fish> fish) {
    _allFish = fish;
    _isLoading = false;
    _applyFilters();
  }

  void _onError(Object error) {
    _isLoading = false;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void filterByHabitat(String habitat) {
    _selectedHabitat = habitat;
    _applyFilters();
  }

  void clearSearch() {
    _searchQuery = '';
    _applyFilters();
  }

  void _applyFilters() {
    _filteredFish = _allFish.where((fish) {
      final matchesSearch = _searchQuery.isEmpty ||
          fish.commonName.toLowerCase().contains(_searchQuery) ||
          fish.localName.toLowerCase().contains(_searchQuery) ||
          fish.scientificName.toLowerCase().contains(_searchQuery);

      final matchesHabitat =
          _selectedHabitat == 'All' || fish.habitat == _selectedHabitat;

      return matchesSearch && matchesHabitat;
    }).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
