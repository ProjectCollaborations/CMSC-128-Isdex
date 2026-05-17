import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:isdex/models/app_user.dart';
import 'package:isdex/repositories/auth_repository.dart';
import 'package:isdex/viewmodels/auth_viewmodel.dart';

class MockAuthRepository implements AuthRepository {
  AppUser? signInResult;
  AppUser? signUpResult;
  AppUser? fetchAppUserResult;
  bool signInShouldThrow = false;
  bool signUpShouldThrow = false;
  bool resetPasswordShouldThrow = false;
  String? signInErrorMessage;
  String? signUpErrorMessage;
  bool signOutCalled = false;
  bool resetPasswordCalled = false;
  bool isEmailRegisteredResult = false;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<AppUser> signIn(String email, String password) async {
    if (signInShouldThrow) {
      throw Exception(signInErrorMessage ?? 'Sign-in failed');
    }
    return signInResult!;
  }

  @override
  Future<AppUser> signUp(String email, String password, String username) async {
    if (signUpShouldThrow) {
      throw Exception(signUpErrorMessage ?? 'Sign-up failed');
    }
    return signUpResult!;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> resetPassword(String email) async {
    if (resetPasswordShouldThrow) {
      throw Exception('Password reset failed');
    }
    resetPasswordCalled = true;
  }

  @override
  Future<String> getUserRole(String uid) async => 'user';

  @override
  Future<bool> isEmailRegistered(String email) async =>
      isEmailRegisteredResult;

  @override
  Future<AppUser> fetchAppUser(String uid) async {
    return fetchAppUserResult ??
        AppUser(
          uid: uid,
          username: 'test',
          email: 'test@test.com',
          role: 'user',
          createdAt: '0',
        );
  }
}

void main() {
  late MockAuthRepository mockRepo;
  late AuthViewModel authVm;

  setUp(() {
    mockRepo = MockAuthRepository();
    authVm = AuthViewModel(mockRepo);
  });

  tearDown(() {
    authVm.dispose();
  });

  test('initial state is unauthenticated', () {
    expect(authVm.isLoggedIn, false);
    expect(authVm.user, isNull);
    expect(authVm.isLoading, false);
    expect(authVm.error, isNull);
    expect(authVm.userRole, 'user');
  });

  test('signIn succeeds and sets user', () async {
    mockRepo.signInResult = AppUser(
      uid: '123',
      username: 'testuser',
      email: 'test@test.com',
      role: 'user',
      createdAt: '0',
    );

    await authVm.signIn('test@test.com', 'password');

    expect(authVm.isLoggedIn, true);
    expect(authVm.user?.uid, '123');
    expect(authVm.user?.email, 'test@test.com');
    expect(authVm.isLoading, false);
    expect(authVm.error, isNull);
  });

  test('signIn sets error on failure', () async {
    mockRepo.signInShouldThrow = true;
    mockRepo.signInErrorMessage = 'user-not-found';

    await authVm.signIn('bad@test.com', 'wrong');

    expect(authVm.isLoggedIn, false);
    expect(authVm.user, isNull);
    expect(authVm.error, isNotNull);
    expect(authVm.isLoading, false);
  });

  test('signUp succeeds and sets user', () async {
    mockRepo.signUpResult = AppUser(
      uid: '456',
      username: 'newuser',
      email: 'new@test.com',
      role: 'user',
      createdAt: '0',
    );

    await authVm.signUp('new@test.com', 'password', 'newuser');

    expect(authVm.isLoggedIn, true);
    expect(authVm.user?.uid, '456');
    expect(authVm.user?.username, 'newuser');
    expect(authVm.isLoading, false);
  });

  test('signOut clears user', () async {
    mockRepo.signInResult = AppUser(
      uid: '123',
      username: 'testuser',
      email: 'test@test.com',
      role: 'user',
      createdAt: '0',
    );

    await authVm.signIn('test@test.com', 'password');
    expect(authVm.isLoggedIn, true);

    await authVm.signOut();
    expect(authVm.isLoggedIn, false);
    expect(authVm.user, isNull);
  });

  test('resetPassword calls repository', () async {
    await authVm.resetPassword('test@test.com');
    expect(mockRepo.resetPasswordCalled, true);
  });

  test('isEmailRegistered delegates to repository', () async {
    mockRepo.isEmailRegisteredResult = true;
    final result = await authVm.isEmailRegistered('test@test.com');
    expect(result, true);
  });

  test('isLoading is true during operation', () async {
    mockRepo.signInResult = AppUser(
      uid: '123',
      username: 't',
      email: 't@t.com',
      role: 'user',
      createdAt: '0',
    );

    bool wasLoading = false;
    authVm.addListener(() {
      if (authVm.isLoading) wasLoading = true;
    });

    await authVm.signIn('t@t.com', 'pass');
    expect(wasLoading, true);
    expect(authVm.isLoading, false);
  });

  test('friendly error messages are returned', () async {
    mockRepo.signInShouldThrow = true;
    mockRepo.signInErrorMessage = 'user-not-found';
    await authVm.signIn('x@x.com', 'p');
    expect(authVm.error, 'No account found with this email');

    mockRepo.signInErrorMessage = 'invalid-credential';
    await authVm.signIn('x@x.com', 'p');
    expect(authVm.error, 'Invalid email or password');
  });
}
