import '../datasources/firebase_data_source.dart';
import '../models/fish.dart';
import 'fish_repository.dart';
import '../../core/constants/firebase_nodes.dart';

class FishRepositoryImpl implements FishRepository {
  final FirebaseDataSource _dataSource;

  FishRepositoryImpl(this._dataSource);

  @override
  Stream<List<Fish>> watchAllFish() {
    return _dataSource.onValue(FirebaseNodes.fish).map((event) {
      final List<Fish> fishList = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            fishList.add(Fish.fromSnapshot(key.toString(), value));
          }
        });

        fishList.sort((a, b) => a.commonName.compareTo(b.commonName));
      }

      return fishList;
    });
  }

  @override
  Future<Fish?> getFishById(String fishId) async {
    final snapshot = await _dataSource.get(FirebaseNodes.fishById(fishId));
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return Fish.fromSnapshot(fishId, data);
    }
    return null;
  }
  
  @override
  Future<Fish?> getFishByKey(String key) async {
    final snapshot = await _dataSource.get(FirebaseNodes.fishById(key));
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return Fish.fromSnapshot(key, data);
    }
    return null;
  }

  @override
  List<Fish> searchFish(List<Fish> allFish, String query) {
    if (query.isEmpty) return allFish;

    final lowerQuery = query.toLowerCase();
    return allFish.where((fish) {
      return fish.commonName.toLowerCase().contains(lowerQuery) ||
          fish.scientificName.toLowerCase().contains(lowerQuery) ||
          fish.localName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  List<Fish> filterByHabitat(List<Fish> allFish, String habitat) {
    if (habitat == 'All') return allFish;
    return allFish.where((fish) => fish.habitat == habitat).toList();
  }
  
  @override
  Future<String> addFish(Fish fish) async {
    final key = fish.fishId;
    await _dataSource.set(FirebaseNodes.fishById(key), fish.toMap());
    return key;
  }
  
  @override
  Future<void> updateFish(String key, Fish fish) async {
    await _dataSource.update(FirebaseNodes.fishById(key), fish.toMap());
  }
  
  @override
  Future<bool> archiveFish(String key, String archivedBy) async {
    // Check if referenced first
    final fish = await getFishByKey(key);
    if (fish == null) return false;
    
    final isReferenced = await isFishReferenced(fish.fishId, key);
    if (isReferenced) return false;
    
    // Get full data
    final snapshot = await _dataSource.get(FirebaseNodes.fishById(key));
    if (!snapshot.exists || snapshot.value == null) return false;
    
    final full = Map<String, dynamic>.from(snapshot.value as Map);
    full['archivedAt'] = DateTime.now().millisecondsSinceEpoch;
    full['archivedBy'] = archivedBy;
    
    // Move to archive
    await _dataSource.set(FirebaseNodes.fishArchiveById(key), full);
    await _dataSource.delete(FirebaseNodes.fishById(key));
    
    return true;
  }
  
  @override
  Future<bool> restoreFish(String key) async {
    final snapshot = await _dataSource.get(FirebaseNodes.fishArchiveById(key));
    if (!snapshot.exists || snapshot.value == null) return false;
    
    final full = Map<String, dynamic>.from(snapshot.value as Map);
    full.remove('archivedAt');
    full.remove('archivedBy');
    
    await _dataSource.set(FirebaseNodes.fishById(key), full);
    await _dataSource.delete(FirebaseNodes.fishArchiveById(key));
    
    return true;
  }
  
  @override
  Future<bool> deleteFish(String key) async {
    final fish = await getFishByKey(key);
    if (fish == null) return false;
    
    final isReferenced = await isFishReferenced(fish.fishId, key);
    if (isReferenced) return false;
    
    await _dataSource.delete(FirebaseNodes.fishById(key));
    return true;
  }
  
  @override
  Future<bool> isFishReferenced(String fishId, String fishKey) async {
    // Check sightings
    final sightingsSnap = await _dataSource.get(FirebaseNodes.userSightingsTemp);
    if (sightingsSnap.exists && sightingsSnap.value != null) {
      final sightings = sightingsSnap.value as Map<dynamic, dynamic>;
      for (final value in sightings.values) {
        final m = Map<dynamic, dynamic>.from(value);
        final linkedFishId = m['fishId']?.toString() ?? '';
        if (linkedFishId == fishId || linkedFishId == fishKey) return true;
      }
    }
    
    // Check map locations
    final mapSnap = await _dataSource.get(FirebaseNodes.map);
    if (mapSnap.exists && mapSnap.value != null) {
      final mapEntries = mapSnap.value as Map<dynamic, dynamic>;
      for (final value in mapEntries.values) {
        final m = Map<dynamic, dynamic>.from(value);
        final linkedFishId = m['fishId']?.toString() ?? '';
        if (linkedFishId == fishId || linkedFishId == fishKey) return true;
      }
    }
    
    return false;
  }
  
  @override
  Stream<List<Map<String, dynamic>>> watchArchivedFish() {
    return _dataSource.onValue(FirebaseNodes.fishArchive).map((event) {
      final List<Map<String, dynamic>> fish = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final m = Map<dynamic, dynamic>.from(value);
          fish.add({
            'key': key.toString(),
            'fishId': m['fishId']?.toString() ?? key.toString(),
            'commonName': m['commonName']?.toString() ?? 'Unknown',
            'scientificName': m['scientificName']?.toString() ?? 'N/A',
            'localName': m['localName']?.toString() ?? 'N/A',
            'habitat': m['habitat']?.toString() ?? 'Unknown',
            'archivedAt': m['archivedAt'],
            'archivedBy': m['archivedBy']?.toString() ?? '',
          });
        });
        
        fish.sort((a, b) => a['commonName'].toString().toLowerCase().compareTo(
              b['commonName'].toString().toLowerCase(),
            ));
      }
      
      return fish;
    });
  }
}