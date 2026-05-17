import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';
import '../core/constants/firebase_nodes.dart';

class ChatRepository {
  final DatabaseReference _db;

  ChatRepository(this._db);

  Stream<List<ChatMessage>> watchMessages(String uid) {
    return _db.child(FirebaseNodes.chatSessionsByUid(uid)).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <ChatMessage>[];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((entry) => ChatMessage.fromMap(
                entry.key.toString(),
                Map<dynamic, dynamic>.from(entry.value as Map),
              ))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  Future<void> addMessage(String uid, {required String role, required String content}) async {
    final ref = _db.child(FirebaseNodes.chatSessionsByUid(uid)).push();
    await ref.set({
      'role': role,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> addModelMessage(String uid, {required String content}) async {
    final ref = _db.child(FirebaseNodes.chatSessionsByUid(uid)).push();
    await ref.set({
      'role': 'model',
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clearHistory(String uid) async {
    await _db.child(FirebaseNodes.chatSessionsByUid(uid)).remove();
  }
}
