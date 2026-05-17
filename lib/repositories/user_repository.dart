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
}
