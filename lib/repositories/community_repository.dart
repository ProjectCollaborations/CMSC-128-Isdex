import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/community_post.dart';
import '../models/comment.dart';
import '../core/constants/firebase_nodes.dart';

class CommunityRepository {
  final DatabaseReference _db;

  CommunityRepository(this._db);

  Stream<List<CommunityPost>> watchPosts() {
    return _db.child(FirebaseNodes.communityPosts).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <CommunityPost>[];
      }
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map(
            (entry) => CommunityPost.fromMap(
              entry.key.toString(),
              Map<dynamic, dynamic>.from(entry.value as Map),
            ),
          )
          .where((post) => post.status != 'archived')
          .toList()
        ..sort((a, b) => b.timePosted.compareTo(a.timePosted));
    });
  }

  Future<void> addPost({
    required String uid,
    required String username,
    required String caption,
    required String imageBase64,
  }) async {
    final ref = _db.child(FirebaseNodes.communityPosts).push();
    await ref.set({
      'uid': uid,
      'username': username,
      'caption': caption,
      'imageBase64': imageBase64,
      'likes': 0,
      'timePosted': ServerValue.timestamp,
      'status': 'active',
      'isReported': false,
    });
  }

  Future<bool> toggleLike(String postId, String uid) async {
    final likeRef = _db.child(FirebaseNodes.postLikeByUser(postId, uid));
    final countRef = _db.child(
      '${FirebaseNodes.communityPostById(postId)}/likes',
    );

    final result = await likeRef.runTransaction((value) {
      return Transaction.success(value == true ? null : true);
    });
    final isLiked = result.snapshot.exists && result.snapshot.value == true;

    await _syncLikeCount(postId, countRef);
    return isLiked;
  }

  Future<void> _syncLikeCount(String postId, DatabaseReference countRef) async {
    final likesSnap = await _db
        .child(FirebaseNodes.postLikesByPostId(postId))
        .get();
    final likeCount = likesSnap.exists && likesSnap.value is Map
        ? (likesSnap.value as Map).values.where((value) => value == true).length
        : 0;
    await countRef.set(likeCount);
  }

  Future<bool> isLikedBy(String postId, String uid) async {
    final snap = await _db
        .child(FirebaseNodes.postLikeByUser(postId, uid))
        .get();
    return snap.exists && snap.value == true;
  }

  Future<void> reportPost(String postId) async {
    await _db.child(FirebaseNodes.communityPostById(postId)).update({
      'isReported': true,
    });
  }

  Future<void> archivePost(String postId) async {
    await _db.child(FirebaseNodes.communityPostById(postId)).update({
      'status': 'archived',
    });
  }

  Future<void> deletePost(String postId) async {
    await _db.child(FirebaseNodes.communityPostById(postId)).remove();
    await _db.child(FirebaseNodes.postCommentsByPostId(postId)).remove();
    await _db.child(FirebaseNodes.postLikesByPostId(postId)).remove();
  }

  Stream<List<Comment>> watchComments(String postId) {
    return _db.child(FirebaseNodes.postCommentsByPostId(postId)).onValue.map((
      event,
    ) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Comment>[];
      }
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map(
            (entry) => Comment.fromMap(
              entry.key.toString(),
              Map<dynamic, dynamic>.from(entry.value as Map),
            ),
          )
          .toList()
        ..sort((a, b) => a.timePosted.compareTo(b.timePosted));
    });
  }

  Future<void> addComment({
    required String postId,
    required String uid,
    required String username,
    required String text,
  }) async {
    final ref = _db.child(FirebaseNodes.postCommentsByPostId(postId)).push();
    await ref.set({
      'uid': uid,
      'username': username,
      'text': text,
      'timePosted': ServerValue.timestamp,
    });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _db.child(FirebaseNodes.postCommentById(postId, commentId)).remove();
  }

  Future<void> dismissReport(String postId) async {
    await _db.child(FirebaseNodes.communityPostById(postId))
        .update({'isReported': false});
  }

  Stream<List<CommunityPost>> watchReportedPosts() {
    return _db.child(FirebaseNodes.communityPosts).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <CommunityPost>[];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => CommunityPost.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ))
          .where((p) => p.isReported && p.status != 'archived')
          .toList()
            ..sort((a, b) => b.timePosted.compareTo(a.timePosted));
    });
  }
}
