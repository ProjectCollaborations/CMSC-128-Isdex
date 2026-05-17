// lib/data/repositories/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

/// Authentication repository interface.
abstract class AuthRepository {
  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges;

  /// Currently logged in user.
  User? get currentUser;

  /// Sign up with email and password.
  Future<User> signUp(String email, String password, String username);

  /// Sign in with email and password.
  Future<User> signIn(String email, String password);

  /// Sign out.
  Future<void> signOut();

  /// Send password reset email.
  Future<void> resetPassword(String email);

  /// Check if email is already registered.
  Future<bool> isEmailRegistered(String email);

  /// Get user's role (user/mod/admin).
  Future<String> getUserRole(String uid);

  Future<void> updateUserRole(String uid, String newRole);
}