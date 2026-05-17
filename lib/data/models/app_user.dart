import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  final String uid;
  final String email;
  final String username;
  final String role; // 'user', 'mod', 'admin'
  final DateTime createdAt;
  final String? photoUrl;
  final String? phoneNumber;

  const AppUser({
    required this.uid,
    required this.email,
    required this.username,
    required this.role,
    required this.createdAt,
    this.photoUrl,
    this.phoneNumber,
  });

  factory AppUser.fromSnapshot(String uid, Map<dynamic, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email']?.toString() ?? '',
      username: data['username']?.toString() ?? 'User',
      role: data['role']?.toString() ?? 'user',
      createdAt: _parseCreatedAt(data['createdAt']),
      photoUrl: data['photoUrl']?.toString(),
      phoneNumber: data['phoneNumber']?.toString(),
    );
  }

  static DateTime _parseCreatedAt(dynamic raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'role': role,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? username,
    String? role,
    DateTime? createdAt,
    String? photoUrl,
    String? phoneNumber,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, username: $username, role: $role)';
  }
}