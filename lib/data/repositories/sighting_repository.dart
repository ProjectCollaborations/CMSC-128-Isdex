import '../models/sighting.dart';

/// Sighting repository interface.
abstract class SightingRepository {
  /// Stream of all sightings (for admin)
  Stream<List<Sighting>> watchAllSightings();
  
  /// Stream of user's own sightings
  Stream<List<Sighting>> watchUserSightings(String userId);
  
  /// Stream of approved sightings (public feed)
  Stream<List<Sighting>> watchApprovedSightings();
  
  /// Add a new sighting
  Future<void> addSighting(Sighting sighting);
  
  /// Delete a sighting (user can delete own, admin any)
  Future<void> deleteSighting(String sightingId);
  
  /// Update sighting status (admin/mod only)
  /// Returns true if successful, false with error message if validation fails
  Future<(bool, String?)> updateSightingStatus(String sightingId, SightingStatus status);
  
  /// Report a sighting (user)
  Future<void> reportSighting(String sightingId);
  
  /// Update geo-validation metadata
  Future<void> updateGeoValidation(String sightingId, String status, String message);
  
  /// Get a single sighting by ID
  Future<Sighting?> getSightingById(String sightingId);
  
  /// Validate a sighting for approval
  /// Returns (isValid, errorMessage)
  Future<(bool, String?)> validateSightingForApproval(String sightingId);
  
  /// Bulk update sighting statuses
  /// Returns (successCount, failures map)
  Future<(int, Map<String, String>)> bulkUpdateStatus(
    List<String> sightingIds,
    SightingStatus status,
  );
}