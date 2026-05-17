import '../models/fish.dart';

/// Fish repository interface.
abstract class FishRepository {
  /// Get real-time stream of all fish.
  Stream<List<Fish>> watchAllFish();

  /// Get a single fish by ID (one-time fetch).
  Future<Fish?> getFishById(String fishId);
  
  /// Get a single fish by key (one-time fetch).
  Future<Fish?> getFishByKey(String key);

  /// Search fish by name (client-side filtering).
  List<Fish> searchFish(List<Fish> allFish, String query);

  /// Filter fish by habitat.
  List<Fish> filterByHabitat(List<Fish> allFish, String habitat);
  
  /// Add a new fish.
  Future<String> addFish(Fish fish);
  
  /// Update an existing fish.
  Future<void> updateFish(String key, Fish fish);
  
  /// Archive a fish (move to fish_archive).
  Future<bool> archiveFish(String key, String archivedBy);
  
  /// Restore a fish from archive.
  Future<bool> restoreFish(String key);
  
  /// Permanently delete a fish (only if not referenced).
  Future<bool> deleteFish(String key);
  
  /// Check if fish is referenced in sightings or map.
  Future<bool> isFishReferenced(String fishId, String fishKey);
  
  /// Get archived fish stream.
  Stream<List<Map<String, dynamic>>> watchArchivedFish();
}