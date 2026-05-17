// lib/data/datasources/firebase_data_source.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../core/constants/firebase_nodes.dart';

/// Raw Firebase operations abstraction.
/// All Firebase interactions go through this class.
class FirebaseDataSource {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  FirebaseDataSource(this._database) : _auth = FirebaseAuth.instance;

  // MARK: - Auth Operations

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // MARK: - Realtime Database CRUD

  Future<DatabaseReference> set(String path, Map<String, dynamic> data) async {
    final ref = _database.ref(path);
    await ref.set(data);
    return ref;
  }

  Future<void> update(String path, Map<String, dynamic> data) async {
    await _database.ref(path).update(data);
  }

  Future<void> delete(String path) async {
    await _database.ref(path).remove();
  }

  Future<DataSnapshot> get(String path) async {
    return await _database.ref(path).get();
  }

  DatabaseReference push(String path) {
    return _database.ref(path).push();
  }

  // MARK: - Real-time Streams

  Stream<DatabaseEvent> onValue(String path) {
    return _database.ref(path).onValue;
  }

  Stream<DatabaseEvent> onChildAdded(String path) {
    return _database.ref(path).onChildAdded;
  }

  // MARK: - Query Helpers

  DatabaseReference ref(String path) {
    return _database.ref(path);
  }

  // MARK: - User Data Helpers

  String normalizeEmailKey(String email) {
    return email.trim().toLowerCase().replaceAll('.', ',');
  }

  Future<void> storeUserData(String uid, Map<String, dynamic> userData) async {
    await _database.ref(FirebaseNodes.userById(uid)).set(userData);
  }

  Future<void> indexEmail(String email, String uid) async {
    final emailKey = normalizeEmailKey(email);
    await _database.ref(FirebaseNodes.userEmailLookup(emailKey)).set(uid);
  }

  Future<bool> isEmailRegistered(String email) async {
    final emailKey = normalizeEmailKey(email);
    final snapshot = await _database.ref(FirebaseNodes.userEmailLookup(emailKey)).get();
    return snapshot.exists && snapshot.value != null;
  }

  Future<String?> getUserRole(String uid) async {
    final snapshot = await _database.ref(FirebaseNodes.userRole(uid)).get();
    if (snapshot.exists && snapshot.value != null) {
      return snapshot.value.toString();
    }
    return 'user';
  }
}