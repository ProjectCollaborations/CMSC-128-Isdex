import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('fromMap creates AppUser from RTDB data', () {
      final data = <String, dynamic>{
        'userId': 'abc123',
        'username': 'johndoe',
        'email': 'john@example.com',
        'role': 'user',
        'createdAt': 1700000000000,
      };

      final user = AppUser.fromMap('abc123', data);

      expect(user.uid, 'abc123');
      expect(user.username, 'johndoe');
      expect(user.email, 'john@example.com');
      expect(user.role, 'user');
      expect(user.createdAt, '1700000000000');
    });

    test('fromMap defaults role to user if missing', () {
      final data = <String, dynamic>{
        'username': 'janedoe',
      };
      final user = AppUser.fromMap('uid1', data);
      expect(user.role, 'user');
    });

    test('toMap produces correct map', () {
      final user = AppUser(
        uid: 'abc123',
        username: 'johndoe',
        email: 'john@example.com',
        role: 'admin',
        createdAt: '1700000000000',
      );

      final map = user.toMap();
      expect(map['userId'], 'abc123');
      expect(map['username'], 'johndoe');
      expect(map['role'], 'admin');
    });

    test('copyWith creates modified copy', () {
      final user = AppUser(
        uid: 'abc123',
        username: 'johndoe',
        email: 'john@example.com',
        role: 'user',
        createdAt: '0',
      );

      final promoted = user.copyWith(role: 'admin');
      expect(promoted.role, 'admin');
      expect(promoted.uid, 'abc123');
      expect(user.role, 'user');
    });
  });
}
