import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthViewModel(this._authRepository) {
    _authRepository.authStateChanges.listen((user) {
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Sign up
  Future<bool> signUp(String email, String password, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.signUp(email, password, username);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = _getUserFriendlyMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Sign in
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.signIn(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = _getUserFriendlyMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = _getUserFriendlyMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Check if email is registered
  Future<bool> isEmailRegistered(String email) async {
    return await _authRepository.isEmailRegistered(email);
  }

  // Get user role
  Future<String> getUserRole(String uid) async {
    return await _authRepository.getUserRole(uid);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        default:
          return 'Authentication error: ${error.code}';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}