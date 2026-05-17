import 'dart:async';
import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/comment.dart';

typedef PostsStreamFactory = Stream<List<CommunityPost>> Function();
typedef CommentsStreamFactory = Stream<List<Comment>> Function(String postId);
typedef AddPostFn = Future<void> Function({
  required String uid,
  required String username,
  required String caption,
  required String imageBase64,
});
typedef ToggleLikeFn = Future<void> Function(String postId, String uid);
typedef IsLikedByFn = Future<bool> Function(String postId, String uid);
typedef ReportPostFn = Future<void> Function(String postId);
typedef DeletePostFn = Future<void> Function(String postId);
typedef CurrentUserIdFn = String? Function();
typedef CurrentUserDisplayFn = String Function();

class CommunityViewModel extends ChangeNotifier {
  final PostsStreamFactory _watchPosts;
  final CommentsStreamFactory _watchComments;
  final AddPostFn _addPost;
  final ToggleLikeFn _toggleLike;
  final IsLikedByFn _isLikedBy;
  final ReportPostFn _reportPost;
  final DeletePostFn _deletePost;
  final CurrentUserIdFn _currentUserId;
  final CurrentUserDisplayFn _currentUserDisplay;

  List<CommunityPost> _posts = [];
  final Map<String, int> _commentCounts = {};
  Set<String> _likedPostIds = {};
  bool _isLoading = true;

  List<CommunityPost> get posts => _posts;
  Map<String, int> get commentCounts => _commentCounts;
  Set<String> get likedPostIds => _likedPostIds;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId();
  String get currentUserDisplay => _currentUserDisplay();

  StreamSubscription<List<CommunityPost>>? _postsSub;
  final Map<String, StreamSubscription<List<Comment>>> _commentSubs = {};

  CommunityViewModel({
    required PostsStreamFactory watchPosts,
    required CommentsStreamFactory watchComments,
    required AddPostFn addPost,
    required ToggleLikeFn toggleLike,
    required IsLikedByFn isLikedBy,
    required ReportPostFn reportPost,
    required DeletePostFn deletePost,
    required CurrentUserIdFn currentUserId,
    required CurrentUserDisplayFn currentUserDisplay,
  })  : _watchPosts = watchPosts,
        _watchComments = watchComments,
        _addPost = addPost,
        _toggleLike = toggleLike,
        _isLikedBy = isLikedBy,
        _reportPost = reportPost,
        _deletePost = deletePost,
        _currentUserId = currentUserId,
        _currentUserDisplay = currentUserDisplay {
    _init();
  }

  void _init() {
    _postsSub = _watchPosts().listen((posts) {
      _posts = posts;
      _isLoading = false;
      _updateCommentSubscriptions(posts);
      _refreshLikedState();
      notifyListeners();
    });
  }

  void _updateCommentSubscriptions(List<CommunityPost> posts) {
    final currentIds = _commentSubs.keys.toSet();
    final neededIds = posts.map((p) => p.id).toSet();

    for (final id in currentIds.difference(neededIds)) {
      _commentSubs[id]?.cancel();
      _commentSubs.remove(id);
    }

    for (final id in neededIds.difference(currentIds)) {
      _commentSubs[id] = _watchComments(id).listen((comments) {
        _commentCounts[id] = comments.length;
        notifyListeners();
      });
    }
  }

  Future<void> _refreshLikedState() async {
    final uid = _currentUserId();
    if (uid == null) {
      _likedPostIds = {};
      return;
    }
    if (_posts.isEmpty) {
      _likedPostIds = {};
      return;
    }
    final results = await Future.wait(
      _posts.map((p) => _isLikedBy(p.id, uid)),
    );
    final liked = <String>{};
    for (int i = 0; i < _posts.length; i++) {
      if (results[i]) liked.add(_posts[i].id);
    }
    _likedPostIds = liked;
  }

  Future<void> toggleLike(String postId) async {
    final uid = _currentUserId();
    if (uid == null) return;
    await _toggleLike(postId, uid);
    if (_likedPostIds.contains(postId)) {
      _likedPostIds.remove(postId);
    } else {
      _likedPostIds.add(postId);
    }
    notifyListeners();
  }

  Future<void> addPost({
    required String caption,
    required String imageBase64,
  }) async {
    final uid = _currentUserId();
    if (uid == null) throw Exception('Must be logged in to create a post');
    await _addPost(
      uid: uid,
      username: currentUserDisplay,
      caption: caption,
      imageBase64: imageBase64,
    );
  }

  Future<void> reportPost(String postId) async {
    await _reportPost(postId);
  }

  Future<void> deletePost(String postId) async {
    await _deletePost(postId);
    _commentSubs[postId]?.cancel();
    _commentSubs.remove(postId);
  }

  @override
  void dispose() {
    _postsSub?.cancel();
    for (final sub in _commentSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
