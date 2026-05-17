import '../datasources/firebase_data_source.dart';
import '../models/fish.dart';
import '../models/sighting.dart';
import 'sighting_repository.dart';
import 'fish_repository.dart';
import '../../core/constants/firebase_nodes.dart';

class SightingRepositoryImpl implements SightingRepository {
  final FirebaseDataSource _dataSource;
  final FishRepository _fishRepository;

  SightingRepositoryImpl(this._dataSource, this._fishRepository);

  @override
  Stream<List<Sighting>> watchAllSightings() {
    return _dataSource.onValue(FirebaseNodes.userSightingsTemp).map((event) {
      final List<Sighting> sightings = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            sightings.add(Sighting.fromSnapshot(key.toString(), value));
          }
        });
        
        sightings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return sightings;
    });
  }

  @override
  Stream<List<Sighting>> watchUserSightings(String userId) {
    return watchAllSightings().map((sightings) {
      return sightings.where((s) => s.userId == userId).toList();
    });
  }

  @override
  Stream<List<Sighting>> watchApprovedSightings() {
    return watchAllSightings().map((sightings) {
      return sightings.where((s) => s.status == SightingStatus.verified).toList();
    });
  }

  @override
  Future<void> addSighting(Sighting sighting) async {
    final ref = _dataSource.push(FirebaseNodes.userSightingsTemp);
    await ref.set(sighting.toMap());
  }

  @override
  Future<void> deleteSighting(String sightingId) async {
    await _dataSource.delete(FirebaseNodes.sightingById(sightingId));
  }

  @override
  Future<(bool, String?)> updateSightingStatus(
    String sightingId,
    SightingStatus status,
  ) async {
    // Only validate for approval (verified)
    if (status == SightingStatus.verified) {
      final (isValid, error) = await validateSightingForApproval(sightingId);
      if (!isValid) {
        return (false, error);
      }
    }
    
    await _dataSource.update(
      FirebaseNodes.sightingById(sightingId),
      {'status': status.name},
    );
    
    return (true, null);
  }

  @override
  Future<void> reportSighting(String sightingId) async {
    await _dataSource.update(
      FirebaseNodes.sightingById(sightingId),
      {'isReported': true},
    );
  }

  @override
  Future<void> updateGeoValidation(String sightingId, String status, String message) async {
    await _dataSource.update(
      FirebaseNodes.sightingById(sightingId),
      {
        'geoValidationStatus': status,
        'geoValidationMessage': message,
      },
    );
  }

  @override
  Future<Sighting?> getSightingById(String sightingId) async {
    final snapshot = await _dataSource.get(FirebaseNodes.sightingById(sightingId));
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return Sighting.fromSnapshot(sightingId, data);
    }
    return null;
  }

  @override
  Future<(bool, String?)> validateSightingForApproval(String sightingId) async {
    final sighting = await getSightingById(sightingId);
    if (sighting == null) {
      return (false, 'Sighting not found');
    }
    
    // Check fish exists
    final fish = await _fishRepository.getFishById(sighting.fishId);
    if (fish == null) {
      return (false, 'Fish ID "${sighting.fishId}" does not exist in catalog');
    }
    
    // Check coordinates are valid
    if (sighting.latitude < -90 || sighting.latitude > 90) {
      return (false, 'Invalid latitude: ${sighting.latitude}');
    }
    if (sighting.longitude < -180 || sighting.longitude > 180) {
      return (false, 'Invalid longitude: ${sighting.longitude}');
    }
    
    // Check geo-validation (if present)
    if (sighting.geoValidationStatus != null) {
      if (sighting.geoValidationStatus!.toLowerCase() != 'water') {
        final message = sighting.geoValidationMessage ?? 'Location is not confirmed as water';
        return (false, 'Location validation failed: $message');
      }
    }
    
    return (true, null);
  }

  @override
  Future<(int, Map<String, String>)> bulkUpdateStatus(
    List<String> sightingIds,
    SightingStatus status,
  ) async {
    int successCount = 0;
    final Map<String, String> failures = {};
    
    for (final id in sightingIds) {
      final (success, error) = await updateSightingStatus(id, status);
      if (success) {
        successCount++;
      } else {
        failures[id] = error ?? 'Unknown error';
      }
    }
    
    return (successCount, failures);
  }
}