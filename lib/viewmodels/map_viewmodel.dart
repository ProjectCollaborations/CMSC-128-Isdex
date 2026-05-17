import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import '../data/models/fish.dart';
import '../data/repositories/fish_repository.dart';
import '../data/repositories/sighting_repository.dart';
import '../core/constants/firebase_nodes.dart';
import '../data/datasources/firebase_data_source.dart';

class MapLocation {
  final String id;
  final LatLng coordinates;
  final String fishId;
  final String fishName;
  final String region;

  MapLocation({
    required this.id,
    required this.coordinates,
    required this.fishId,
    required this.fishName,
    required this.region,
  });
}

class MapViewModel extends ChangeNotifier {
  final SightingRepository _sightingRepository;
  final FishRepository _fishRepository;
  final FirebaseDataSource _dataSource;
  
  MapViewModel(this._sightingRepository, this._fishRepository) 
      : _dataSource = FirebaseDataSource(FirebaseDatabase.instance) {
    _init();
  }
  
  // State
  List<MapLocation> _fishLocations = [];
  List<MapLocation> _userSightingLocations = [];
  LatLng? _userLocation;
  String? _error;
  bool _isLoading = true;
  bool _isLoadingLocations = true;
  
  // Getters
  List<MapLocation> get fishLocations => _fishLocations;
  List<MapLocation> get userSightingLocations => _userSightingLocations;
  LatLng? get userLocation => _userLocation;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isLoadingLocations => _isLoadingLocations;
  
  void _init() {
    _loadFishLocations();
    _loadUserSightingLocations();
  }
  
  void _loadFishLocations() {
    _isLoadingLocations = true;
    _error = null;
    notifyListeners();
    
    _dataSource.onValue(FirebaseNodes.map).listen((event) {
      final List<MapLocation> locations = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((locationId, locationData) {
          final m = locationData as Map<dynamic, dynamic>;
          final double lat = (m['latitude'] as num?)?.toDouble() ?? 0.0;
          final double lng = (m['longitude'] as num?)?.toDouble() ?? 0.0;
          final String fishId = m['fishId']?.toString() ?? '';
          final String region = m['region']?.toString() ?? 'Unknown';
          
          if (lat != 0.0 && lng != 0.0) {
            locations.add(MapLocation(
              id: locationId.toString(),
              coordinates: LatLng(lat, lng),
              fishId: fishId,
              fishName: '', // Will be populated asynchronously
              region: region,
            ));
          }
        });
        
        // Sort by region for consistent display
        locations.sort((a, b) => a.region.compareTo(b.region));
        
        // Populate fish names asynchronously
        _populateFishNames(locations);
      } else {
        _isLoadingLocations = false;
        notifyListeners();
      }
    }, onError: (error) {
      _isLoadingLocations = false;
      _error = error.toString();
      notifyListeners();
    });
  }
  
  Future<void> _populateFishNames(List<MapLocation> locations) async {
    for (int i = 0; i < locations.length; i++) {
      final location = locations[i];
      if (location.fishId.isNotEmpty) {
        final fish = await _fishRepository.getFishById(location.fishId);
        if (fish != null) {
          locations[i] = MapLocation(
            id: location.id,
            coordinates: location.coordinates,
            fishId: location.fishId,
            fishName: fish.commonName,
            region: location.region,
          );
        }
      }
    }
    
    _fishLocations = locations;
    _isLoadingLocations = false;
    _isLoading = false;
    notifyListeners();
  }
  
  void _loadUserSightingLocations() {
    _sightingRepository.watchApprovedSightings().listen((sightings) {
      final locations = sightings.map((s) => MapLocation(
        id: s.id,
        coordinates: LatLng(s.latitude, s.longitude),
        fishId: s.fishId,
        fishName: s.fishName,
        region: 'User Sighting',
      )).toList();
      
      _userSightingLocations = locations;
      notifyListeners();
    });
  }
  
  void setUserLocation(LatLng location) {
    _userLocation = location;
    notifyListeners();
  }
  
  Future<Fish?> getFishById(String fishId) async {
    return await _fishRepository.getFishById(fishId);
  }
  
  /// Get locations for a specific fish (when coming from fish detail page)
  Stream<List<MapLocation>> watchLocationsForFish(String fishId) {
    return _dataSource.onValue(FirebaseNodes.map).map((event) {
      final List<MapLocation> locations = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((locationId, locationData) {
          final m = locationData as Map<dynamic, dynamic>;
          final String linkedFishId = m['fishId']?.toString() ?? '';
          
          if (linkedFishId == fishId) {
            final double lat = (m['latitude'] as num?)?.toDouble() ?? 0.0;
            final double lng = (m['longitude'] as num?)?.toDouble() ?? 0.0;
            final String region = m['region']?.toString() ?? 'Unknown';
            
            if (lat != 0.0 && lng != 0.0) {
              locations.add(MapLocation(
                id: locationId.toString(),
                coordinates: LatLng(lat, lng),
                fishId: linkedFishId,
                fishName: '', // Will be populated
                region: region,
              ));
            }
          }
        });
      }
      
      return locations;
    });
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}