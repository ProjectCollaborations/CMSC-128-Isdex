// lib/core/utils/error_handler.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Standardized error handling across the app.
class ErrorHandler {
  ErrorHandler._();

  /// Converts any error to a user-friendly message.
  static String getUserFriendlyMessage(dynamic error) {
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
        default:
          return 'Authentication error: ${error.code}';
      }
    }

    if (error.toString().contains('permission-denied')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Shows a snackbar with error message.
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = getUserFriendlyMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a success snackbar.
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}