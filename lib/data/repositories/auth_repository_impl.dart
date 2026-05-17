// lib/data/repositories/auth_repository_impl.dart
import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/firebase_data_source.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';
import '../../core/constants/firebase_nodes.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Stream<User?> get authStateChanges => _dataSource.authStateChanges;

  @override
  User? get currentUser => _dataSource.currentUser;

  @override
  Future<User> signUp(String email, String password, String username) async {
    final credential = await _dataSource.signUpWithEmail(email, password);
    final user = credential.user!;

    final appUser = AppUser(
      uid: user.uid,
      email: email.toLowerCase(),
      username: username,
      role: 'user',
      createdAt: DateTime.now(),
    );

    await _dataSource.storeUserData(user.uid, appUser.toMap());
    await _dataSource.indexEmail(email, user.uid);

    return user;
  }

  @override
  Future<User> signIn(String email, String password) async {
    final credential = await _dataSource.signInWithEmail(email, password);
    return credential.user!;
  }

  @override
  Future<void> signOut() async {
    await _dataSource.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _dataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<bool> isEmailRegistered(String email) async {
    return await _dataSource.isEmailRegistered(email);
  }

  @override
  Future<String> getUserRole(String uid) async {
    final role = await _dataSource.getUserRole(uid);
    return role ?? 'user';
  }

  @override
  Future<void> updateUserRole(String uid, String newRole) async {
    await _dataSource.update(FirebaseNodes.userById(uid), {'role': newRole});
  }
}