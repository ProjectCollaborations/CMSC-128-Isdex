import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/map_location.dart';
import '../core/constants/firebase_nodes.dart';

class MapRepository {
  final DatabaseReference _db;

  MapRepository(this._db);

  Stream<List<MapLocation>> watchAll() {
    return _db.child(FirebaseNodes.map).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries.map((entry) {
        return MapLocation.fromMap(
          entry.key.toString(),
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
      }).toList();
    });
  }

  Stream<List<MapLocation>> watchByFishId(String fishId) {
    return _db
        .child(FirebaseNodes.map)
        .orderByChild('fishId')
        .equalTo(fishId)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries.map((entry) {
        return MapLocation.fromMap(
          entry.key.toString(),
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
      }).toList();
    });
  }
}
