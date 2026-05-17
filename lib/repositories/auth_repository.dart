import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../core/constants/firebase_nodes.dart';

class AuthRepository {
  final AuthService _authService;
  final DatabaseReference _db;

  AuthRepository(this._authService, this._db);

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  User? get currentUser => _authService.currentUser;

  Future<AppUser> signIn(String email, String password) async {
    final user = await _authService.signInWithEmail(email, password);
    if (user == null) throw Exception('Sign-in failed');
    return fetchAppUser(user.uid);
  }

  Future<AppUser> signUp(String email, String password, String username) async {
    final user = await _authService.signUpWithEmail(email, password, username);
    if (user == null) throw Exception('Sign-up failed');
    return fetchAppUser(user.uid);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  Future<String> getUserRole(String uid) async {
    return await _authService.getUserRole(uid) ?? 'user';
  }

  Future<bool> isEmailRegistered(String email) async {
    return await _authService.isEmailRegisteredInAppDb(email);
  }

  Future<AppUser> fetchAppUser(String uid) async {
    final snap = await _db.child(FirebaseNodes.userById(uid)).get();
    if (snap.exists && snap.value != null) {
      return AppUser.fromMap(uid, Map<dynamic, dynamic>.from(snap.value as Map));
    }
    return AppUser(uid: uid, username: '', email: '', role: 'user', createdAt: '0');
  }
}
