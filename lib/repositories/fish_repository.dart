import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/fish.dart';
import '../core/constants/firebase_nodes.dart';

class FishRepository {
  final DatabaseReference _db;

  FishRepository(this._db);

  Stream<List<Fish>> watchAll() {
    return _db.child(FirebaseNodes.fish).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return [];
      }
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries.map((entry) {
        return Fish.fromMap(
          entry.key.toString(),
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
      }).toList();
    });
  }

  Future<Fish?> getById(String id) async {
    final snap = await _db.child(FirebaseNodes.fishById(id)).get();
    if (!snap.exists || snap.value == null) return null;
    return Fish.fromMap(id, Map<dynamic, dynamic>.from(snap.value as Map));
  }

  Future<void> add(Fish fish) async {
    await _db.child(FirebaseNodes.fishById(fish.id)).set(fish.toMap());
  }

  Future<void> update(Fish fish) async {
    await _db.child(FirebaseNodes.fishById(fish.id)).update(fish.toMap());
  }

  Future<void> archive(String id) async {
    final snap = await _db.child(FirebaseNodes.fishById(id)).get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      await _db.child(FirebaseNodes.fishArchiveById(id)).set(data);
      await _db.child(FirebaseNodes.fishById(id)).remove();
    }
  }

  Future<void> restore(String id) async {
    final snap = await _db.child(FirebaseNodes.fishArchiveById(id)).get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      await _db.child(FirebaseNodes.fishById(id)).set(data);
      await _db.child(FirebaseNodes.fishArchiveById(id)).remove();
    }
  }

  Stream<List<Fish>> watchArchive() {
    return _db.child(FirebaseNodes.fishArchive).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <Fish>[];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => Fish.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ))
          .toList();
    });
  }

  Future<void> hardDelete(String id, {bool fromArchive = false}) async {
    final node = fromArchive
        ? FirebaseNodes.fishArchiveById(id)
        : FirebaseNodes.fishById(id);
    await _db.child(node).remove();
  }
}
