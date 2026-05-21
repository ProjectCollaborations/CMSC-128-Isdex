import 'package:firebase_database/firebase_database.dart';
import '../models/app_user.dart';
import '../core/constants/firebase_nodes.dart';

class UserRepository {
  final DatabaseReference _db;

  UserRepository(this._db);

  Future<AppUser?> getById(String uid) async {
    final snap = await _db.child(FirebaseNodes.userById(uid)).get();
    if (!snap.exists || snap.value == null) return null;
    return AppUser.fromMap(uid, Map<dynamic, dynamic>.from(snap.value as Map));
  }

  Future<void> updateRole(String uid, String role) async {
    await _db.child(FirebaseNodes.userRoleByUid(uid)).set(role);
  }

  Future<bool> isEmailRegistered(String email) async {
    final snap = await _db.child(FirebaseNodes.emailKey(email)).get();
    return snap.exists && snap.value != null;
  }

  Stream<List<AppUser>> watchAll() {
    return _db.child(FirebaseNodes.users).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <AppUser>[];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => AppUser.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ))
          .toList()
            ..sort((a, b) => a.role.compareTo(b.role));
    });
  }
}
