import 'package:firebase_database/firebase_database.dart';
import '../datasources/firebase_data_source.dart';
import '../models/community_post.dart';
import '../models/comment.dart';
import 'community_repository.dart';
import '../../core/constants/firebase_nodes.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final FirebaseDataSource _dataSource;

  CommunityRepositoryImpl(this._dataSource);

  @override
  Stream<List<CommunityPost>> watchPosts({bool includeArchived = false}) {
    return _dataSource.onValue(FirebaseNodes.communityPosts).map((event) {
      final List<CommunityPost> posts = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final post = CommunityPost.fromSnapshot(key.toString(), value);
            if (includeArchived || post.status != 'archived') {
              posts.add(post);
            }
          }
        });
        
        posts.sort((a, b) => b.timePosted.compareTo(a.timePosted));
      }
      
      return posts;
    });
  }

  @override
  Stream<List<CommunityPost>> watchReportedPosts() {
    return watchPosts(includeArchived: true).map((posts) {
      return posts.where((p) => p.isReported && p.status != 'archived').toList();
    });
  }

  @override
  Future<String> addPost(CommunityPost post) async {
    final ref = _dataSource.push(FirebaseNodes.communityPosts);
    await ref.set(post.toMap());
    return ref.key!;
  }

  @override
  Future<void> deletePost(String postId) async {
    await _dataSource.delete(FirebaseNodes.communityPostById(postId));
    await _dataSource.delete(FirebaseNodes.postCommentsByPostId(postId));
    await _dataSource.delete('${FirebaseNodes.postLikes}/$postId');
  }

  @override
  Future<void> reportPost(String postId) async {
    await _dataSource.update(
      FirebaseNodes.communityPostById(postId),
      {'isReported': true},
    );
  }

  @override
  Future<void> archivePost(String postId) async {
    await _dataSource.update(
      FirebaseNodes.communityPostById(postId),
      {'status': 'archived', 'isReported': false},
    );
  }

  @override
  Future<void> dismissReport(String postId) async {
    await _dataSource.update(
      FirebaseNodes.communityPostById(postId),
      {'isReported': false},
    );
  }

  @override
  Future<void> toggleLike(String postId, String userId) async {
    final likeRef = _dataSource.ref(FirebaseNodes.postLikeByUser(postId, userId));
    final countRef = _dataSource.ref('${FirebaseNodes.communityPostById(postId)}/likes');
    
    final snapshot = await likeRef.get();
    if (snapshot.exists) {
      await likeRef.remove();
      await countRef.runTransaction((current) {
        final cur = (current as int?) ?? 0;
        // Transaction.success is a function that returns a TransactionResult
        return Transaction.success(cur > 0 ? cur - 1 : 0);
      });
    } else {
      await likeRef.set(true);
      await countRef.runTransaction((current) {
        final cur = (current as int?) ?? 0;
        return Transaction.success(cur + 1);
      });
    }
  }

  @override
  Future<bool> hasUserLiked(String postId, String userId) async {
    final snapshot = await _dataSource.get(FirebaseNodes.postLikeByUser(postId, userId));
    return snapshot.exists;
  }

  @override
  Future<void> addComment(String postId, Comment comment) async {
    final ref = _dataSource.push(FirebaseNodes.postCommentsByPostId(postId));
    await ref.set(comment.toMap());
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    await _dataSource.delete('${FirebaseNodes.postCommentsByPostId(postId)}/$commentId');
  }

  @override
  Stream<List<Comment>> watchComments(String postId) {
    return _dataSource.onValue(FirebaseNodes.postCommentsByPostId(postId)).map((event) {
      final List<Comment> comments = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            comments.add(Comment.fromSnapshot(key.toString(), postId, value));
          }
        });
        
        comments.sort((a, b) => a.timePosted.compareTo(b.timePosted));
      }
      
      return comments;
    });
  }

  @override
  Future<int> getCommentCount(String postId) async {
    final snapshot = await _dataSource.get(FirebaseNodes.postCommentsByPostId(postId));
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return data.length;
    }
    return 0;
  }
}