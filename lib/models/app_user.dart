class AppUser {
  final String uid;
  final String username;
  final String email;
  final String role;
  final String createdAt;

  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    return AppUser(
      uid: uid,
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? 'user',
      createdAt: map['createdAt']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': uid,
        'username': username,
        'email': email,
        'role': role,
        'createdAt': createdAt,
      };

  AppUser copyWith({
    String? uid,
    String? username,
    String? email,
    String? role,
    String? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppUser && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
