import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/sighting.dart';
import '../core/constants/firebase_nodes.dart';

class SightingRepository {
  final DatabaseReference _db;

  SightingRepository(this._db);

  Stream<List<Sighting>> watchAll() {
    return _db.child(FirebaseNodes.sightings).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries.map((entry) {
        return Sighting.fromMap(
          entry.key.toString(),
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
      }).toList();
    });
  }

  Stream<List<Sighting>> watchByUser(String uid) {
    return _db.child(FirebaseNodes.sightings).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <Sighting>[];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((entry) => Sighting.fromMap(
                entry.key.toString(),
                Map<dynamic, dynamic>.from(entry.value as Map),
              ))
          .where((s) => s.userId == uid)
          .toList();
    });
  }

  Future<void> add(Sighting sighting) async {
    await _db.child(FirebaseNodes.sightingById(sighting.id)).set(sighting.toMap());
  }

  Future<String> push(Sighting sighting) async {
    final ref = _db.child(FirebaseNodes.sightings).push();
    await ref.set(sighting.toMap());
    return ref.key ?? '';
  }

  Future<void> updateStatus(String id, SightingStatus status) async {
    await _db.child(FirebaseNodes.sightingById(id)).update({'status': status.name});
  }

  Future<void> archive(String id) async {
    await _db.child(FirebaseNodes.sightingById(id)).remove();
  }

  Future<void> reportSighting(String id) async {
    await _db.child(FirebaseNodes.sightingById(id)).update({'isReported': true});
  }

  Future<void> updateGeoValidation(String id, String status, String message) async {
    await _db.child(FirebaseNodes.sightingById(id)).update({
      'geoValidationStatus': status,
      'geoValidationMessage': message,
    });
  }

  Future<void> delete(String id) async {
    await _db.child(FirebaseNodes.sightingById(id)).remove();
  }
}
