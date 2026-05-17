// lib/viewmodels/fish_catalog_viewmodel.dart
import 'package:flutter/material.dart';
import '../data/models/fish.dart';
import '../data/repositories/fish_repository.dart';

class FishCatalogViewModel extends ChangeNotifier {
  final FishRepository _fishRepository;

  FishCatalogViewModel(this._fishRepository) {
    _initialize();
  }

  // State
  List<Fish> _allFish = [];
  List<Fish> _filteredFish = [];
  String _searchQuery = '';
  String _selectedHabitat = 'All';
  bool _isLoading = true;
  String? _error;

  // Getters
  List<Fish> get filteredFish => _filteredFish;
  List<Fish> get allFish => _allFish;          // ✅ added getter
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedHabitat => _selectedHabitat;

  List<String> get habitats => ['All', 'Saltwater', 'Freshwater', 'Brackish Water'];

  void _initialize() {
    _fishRepository.watchAllFish().listen((fishList) {
      _allFish = fishList;
      _applyFilters();
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setHabitat(String habitat) {
    _selectedHabitat = habitat;
    _applyFilters();
  }

  void _applyFilters() {
    List<Fish> result = _fishRepository.searchFish(_allFish, _searchQuery);
    result = _fishRepository.filterByHabitat(result, _selectedHabitat);
    _filteredFish = result;
    notifyListeners();
  }

  void refresh() {
    _isLoading = true;
    notifyListeners();
    // Stream will auto-update, just reset loading state
    _isLoading = false;
    notifyListeners();
  }
}