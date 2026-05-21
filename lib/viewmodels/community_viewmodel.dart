import 'dart:async';
import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/comment.dart';

typedef PostsStreamFactory = Stream<List<CommunityPost>> Function();
typedef CommentsStreamFactory = Stream<List<Comment>> Function(String postId);
typedef AddPostFn =
    Future<void> Function({
      required String uid,
      required String username,
      required String caption,
      required String imageBase64,
    });
typedef ToggleLikeFn = Future<bool> Function(String postId, String uid);
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
  String? _activeUserId;
  int _likedStateRequestId = 0;
  bool _isDisposed = false;

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
  }) : _watchPosts = watchPosts,
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
      _notifyIfActive();
    });
  }

  void handleCurrentUserChanged(String? uid) {
    if (_activeUserId == uid) return;

    _activeUserId = uid;
    _likedStateRequestId++;
    _likedPostIds = {};
    _notifyIfActive();
    _refreshLikedState();
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
        _notifyIfActive();
      });
    }
  }

  Future<void> _refreshLikedState() async {
    final uid = _currentUserId();
    if (_activeUserId != uid) {
      _activeUserId = uid;
      _likedPostIds = {};
    }

    final requestId = ++_likedStateRequestId;
    final postIds = _posts.map((p) => p.id).toList(growable: false);

    if (uid == null) {
      _likedPostIds = {};
      _notifyIfActive();
      return;
    }
    if (postIds.isEmpty) {
      _likedPostIds = {};
      _notifyIfActive();
      return;
    }
    final results = await Future.wait(
      postIds.map((postId) => _isLikedBy(postId, uid)),
    );
    if (requestId != _likedStateRequestId ||
        uid != _currentUserId() ||
        !_samePostIds(
          postIds,
          _posts.map((p) => p.id).toList(growable: false),
        )) {
      return;
    }

    final liked = <String>{};
    for (int i = 0; i < postIds.length; i++) {
      if (results[i]) liked.add(postIds[i]);
    }
    _likedPostIds = liked;
    _notifyIfActive();
  }

  bool _samePostIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> toggleLike(String postId) async {
    final uid = _currentUserId();
    if (uid == null) return;
    final isLiked = await _toggleLike(postId, uid);
    if (uid != _currentUserId()) return;

    final likedPostIds = Set<String>.from(_likedPostIds);
    if (isLiked) {
      likedPostIds.add(postId);
    } else {
      likedPostIds.remove(postId);
    }
    _likedPostIds = likedPostIds;
    _notifyIfActive();
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
    _isDisposed = true;
    _likedStateRequestId++;
    _postsSub?.cancel();
    for (final sub in _commentSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
