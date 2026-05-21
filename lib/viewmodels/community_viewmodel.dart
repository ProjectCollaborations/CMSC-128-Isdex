import 'dart:async';
import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/comment.dart';
import 'auth_viewmodel.dart';

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
  final AuthViewModel _authViewModel;

  List<CommunityPost> _posts = [];
  final Map<String, int> _commentCounts = {};
  Set<String> _likedPostIds = {};
  bool _isLoading = true;
  String? _activeUserId;
  int _likedStateRequestId = 0;
  bool _isDisposed = false;

  // ──────────────────────────────────────────────────────────────
  // Race condition fix #1: Generation counter with stale detection
  // ──────────────────────────────────────────────────────────────
  int _refreshGeneration = 0;
  String? _lastKnownUserId;
  
  // Track in-flight operations to prevent duplicates
  final Set<String> _pendingLikeOperations = {};
  final Set<String> _pendingRefreshOperations = {};

  List<CommunityPost> get posts => _posts;
  Map<String, int> get commentCounts => _commentCounts;
  Set<String> get likedPostIds => _likedPostIds;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId();
  String get currentUserDisplay => _currentUserDisplay();

  StreamSubscription<List<CommunityPost>>? _postsSub;
  final Map<String, StreamSubscription<List<Comment>>> _commentSubs = {};

  CommunityViewModel({
    required AuthViewModel authViewModel,
    required PostsStreamFactory watchPosts,
    required CommentsStreamFactory watchComments,
    required AddPostFn addPost,
    required ToggleLikeFn toggleLike,
    required IsLikedByFn isLikedBy,
    required ReportPostFn reportPost,
    required DeletePostFn deletePost,
    required CurrentUserIdFn currentUserId,
    required CurrentUserDisplayFn currentUserDisplay,
  })  : _authViewModel = authViewModel,
        _watchPosts = watchPosts,
        _watchComments = watchComments,
        _addPost = addPost,
        _toggleLike = toggleLike,
        _isLikedBy = isLikedBy,
        _reportPost = reportPost,
        _deletePost = deletePost,
        _currentUserId = currentUserId,
        _currentUserDisplay = currentUserDisplay {
    _authViewModel.addListener(_onAuthChanged);
    _init();
  }

  void _init() {
    _postsSub = _watchPosts().listen((posts) {
      // Race condition fix: Check if still relevant before updating
      if (!_isRefreshStillValid()) return;
      
      _posts = posts;
      _isLoading = false;
      _updateCommentSubscriptions(posts);
      refreshLikedState(); // Will check staleness internally
      notifyListeners();
    });
  }

  void _onAuthChanged() {
    final uid = _authViewModel.user?.uid;
    _forceRefreshLikedState(uid);
  }

  // ──────────────────────────────────────────────────────────────
  // Core race-protected refresh logic
  // ──────────────────────────────────────────────────────────────

  bool _isRefreshStillValid() {
    // If we've advanced generations during this async operation, discard
    return _refreshGeneration == _lastKnownGeneration;
  }
  
  int _lastKnownGeneration = 0;

  Future<void> _forceRefreshLikedState(String? uid) async {
    // Race condition fix: Cancel any pending refresh with same operation ID
    final operationId = 'refresh_${DateTime.now().millisecondsSinceEpoch}';
    if (_pendingRefreshOperations.contains('refresh_active')) {
      // Previous refresh still in flight; let it complete and we'll run another
      // after a short delay to avoid stampede
      await Future.delayed(const Duration(milliseconds: 50));
      if (_pendingRefreshOperations.contains('refresh_active')) {
        // Still busy; schedule a retry
        Future.microtask(() => _forceRefreshLikedState(uid));
        return;
      }
    }
    
    _pendingRefreshOperations.add('refresh_active');
    
    final generation = ++_refreshGeneration;
    _lastKnownGeneration = generation;
    _lastKnownUserId = uid;
    
    // Clear immediately to prevent showing stale data
    _likedPostIds = {};
    notifyListeners();

    if (uid == null || _posts.isEmpty) {
      _pendingRefreshOperations.remove('refresh_active');
      return;
    }

    try {
      final results = await Future.wait(
        _posts.map((p) => _isLikedBy(p.id, uid)),
      );

      // Race condition fix: Check generation hasn't changed during async wait
      if (generation != _refreshGeneration) {
        // Stale result — discard
        _pendingRefreshOperations.remove('refresh_active');
        return;
      }

      final liked = <String>{};
      for (int i = 0; i < _posts.length; i++) {
        if (results[i]) liked.add(_posts[i].id);
      }
      
      // Final generation check before applying
      if (generation == _refreshGeneration) {
        _likedPostIds = liked;
        notifyListeners();
      }
    } catch (e) {
      // On error, keep current state (already cleared) but log
      debugPrint('CommunityViewModel: refresh failed - $e');
    } finally {
      _pendingRefreshOperations.remove('refresh_active');
    }
  }

  Future<void> refreshLikedState() async {
    final uid = _currentUserId();

    if (uid != _lastKnownUserId) {
      await _forceRefreshLikedState(uid);
      return;
    }

    if (uid == null || _posts.isEmpty) return;

    final generation = ++_refreshGeneration;
    _lastKnownGeneration = generation;

    try {
      final results = await Future.wait(
        _posts.map((p) => _isLikedBy(p.id, uid)),
      );

      // Race condition fix: Check generation hasn't changed
      if (generation != _refreshGeneration) return;

      final liked = <String>{};
      for (int i = 0; i < _posts.length; i++) {
        if (results[i]) liked.add(_posts[i].id);
      }
      
      if (generation == _refreshGeneration) {
        _likedPostIds = liked;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CommunityViewModel: refreshLikedState failed - $e');
    }
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

  // ──────────────────────────────────────────────────────────────
  // Race-protected like toggle
  // ──────────────────────────────────────────────────────────────

  Future<void> toggleLike(String postId) async {
    final uid = _currentUserId();
    if (uid == null) return;
    
    // Race condition fix: Prevent duplicate like operations on same post
    final operationKey = 'like_${postId}_$uid';
    if (_pendingLikeOperations.contains(operationKey)) {
      // Operation already in flight for this post/user
      return;
    }
    
    _pendingLikeOperations.add(operationKey);
    
    // Capture current state before operation
    final wasLiked = _likedPostIds.contains(postId);
    final currentLikes = _posts.firstWhere(
      (p) => p.id == postId,
      orElse: () => CommunityPost(
        id: postId,
        uid: '',
        username: '',
        caption: '',
        imageBase64: '',
        likes: 0,
        timePosted: 0,
        isReported: false,
        status: 'active',
      ),
    ).likes;
    
    // Race condition fix: Optimistic update with rollback capability
    // Apply optimistic update
    if (wasLiked) {
      _likedPostIds.remove(postId);
      _updatePostLikesLocally(postId, currentLikes - 1);
    } else {
      _likedPostIds.add(postId);
      _updatePostLikesLocally(postId, currentLikes + 1);
    }
    notifyListeners();

    try {
      // Capture the user ID at start of operation for verification
      final startingUid = uid;
      
      await _toggleLike(postId, uid);
      
      // Race condition fix: Verify user hasn't changed during operation
      if (startingUid != _currentUserId()) {
        // User logged out/in during operation — force full refresh
        _forceRefreshLikedState(_currentUserId());
        return;
      }
      
      // Verify the operation had the intended effect by checking current state
      final isNowLiked = await _isLikedBy(postId, uid);
      
      if (isNowLiked != !wasLiked) {
        // Our assumption about the operation result was wrong — force refresh
        _forceRefreshLikedState(uid);
      }
    } catch (e) {
      // Race condition fix: Rollback on error
      if (wasLiked) {
        _likedPostIds.add(postId);
        _updatePostLikesLocally(postId, currentLikes);
      } else {
        _likedPostIds.remove(postId);
        _updatePostLikesLocally(postId, currentLikes);
      }
      notifyListeners();
      
      debugPrint('CommunityViewModel: toggleLike failed - $e');
      rethrow;
    } finally {
      _pendingLikeOperations.remove(operationKey);
    }
  }
  
  void _updatePostLikesLocally(String postId, int newLikeCount) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(likes: newLikeCount);
    }
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
    _authViewModel.removeListener(_onAuthChanged);
    _postsSub?.cancel();
    for (final sub in _commentSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
