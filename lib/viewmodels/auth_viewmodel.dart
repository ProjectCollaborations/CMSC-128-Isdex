import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepo;

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  StreamSubscription<User?>? _authSub;

  bool get isLoggedIn => _user != null;
  AppUser? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;
  String get userRole => _user?.role ?? 'user';

  AuthViewModel(this._authRepo) {
    _authSub = _authRepo.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authRepo.signIn(email, password);
    } catch (e) {
      _error = _friendlyMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authRepo.signUp(email, password, username);
    } catch (e) {
      _error = _friendlyMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepo.resetPassword(email);
    } catch (e) {
      _error = _friendlyMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isEmailRegistered(String email) async {
    return await _authRepo.isEmailRegistered(email);
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null && _user == null) {
      _user = await _authRepo.fetchAppUser(firebaseUser.uid);
    } else if (firebaseUser == null) {
      _user = null;
    }
    _initialized = true;
    notifyListeners();
  }

  String _friendlyMessage(String error) {
    if (error.contains('user-not-found')) return 'No account found with this email';
    if (error.contains('wrong-password')) return 'Incorrect password';
    if (error.contains('invalid-email')) return 'Invalid email address';
    if (error.contains('user-disabled')) return 'This account has been disabled';
    if (error.contains('too-many-requests')) return 'Too many failed attempts. Try again later';
    if (error.contains('network-request-failed')) return 'Network error. Please check your connection';
    if (error.contains('invalid-credential')) return 'Invalid email or password';
    if (error.contains('email-already-in-use')) return 'This email is already registered';
    if (error.contains('weak-password')) return 'Password is too weak';
    return error.contains('Exception: ') ? error.replaceFirst('Exception: ', '') : 'An error occurred. Please try again';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
