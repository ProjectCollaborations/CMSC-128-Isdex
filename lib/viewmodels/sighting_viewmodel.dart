import 'package:flutter/material.dart';
import '../data/models/sighting.dart';
import '../data/repositories/sighting_repository.dart';

class SightingViewModel extends ChangeNotifier {
  final SightingRepository _repository;
  
  SightingViewModel(this._repository) {
    _init();
  }
  
  // State
  List<Sighting> _userSightings = [];
  List<Sighting> _allSightings = [];  // NEW: all sightings (for filtering in UI)
  List<Sighting> _publicSightings = [];
  bool _isLoading = true;
  String? _error;
  bool _isSubmitting = false;
  
  // Getters
  List<Sighting> get userSightings => _userSightings;
  List<Sighting> get allSightings => _allSightings;  // NEW
  List<Sighting> get publicSightings => _publicSightings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSubmitting => _isSubmitting;
  
  void _init() {
    // Listen to ALL sightings (not just approved)
    _repository.watchAllSightings().listen((sightings) {
      _allSightings = sightings;
      
      // For backward compatibility, keep publicSightings as verified only
      // (other parts of the app might expect this)
      _publicSightings = sightings.where((s) => s.status == SightingStatus.verified).toList();
      
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
  }
  
  void loadUserSightings(String userId) {
    _isLoading = true;
    notifyListeners();
    
    _repository.watchUserSightings(userId).listen((sightings) {
      _userSightings = sightings;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
  }
  
  Future<bool> addSighting(Sighting sighting) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    
    try {
      await _repository.addSighting(sighting);
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> deleteSighting(String sightingId) async {
    try {
      await _repository.deleteSighting(sightingId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> reportSighting(String sightingId) async {
    try {
      await _repository.reportSighting(sightingId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<void> updateGeoValidation(String sightingId, String status, String message) async {
    await _repository.updateGeoValidation(sightingId, status, message);
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}