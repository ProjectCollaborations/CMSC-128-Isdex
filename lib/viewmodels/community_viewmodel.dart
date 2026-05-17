import 'package:flutter/material.dart';
import '../data/models/community_post.dart';
import '../data/models/comment.dart';
import '../data/repositories/community_repository.dart';

class CommunityViewModel extends ChangeNotifier {
  final CommunityRepository _repository;
  
  CommunityViewModel(this._repository) {
    _init();
  }
  
  // State
  List<CommunityPost> _posts = [];
  List<CommunityPost> _reportedPosts = [];
  Map<String, List<Comment>> _commentsCache = {};
  Map<String, bool> _likeCache = {};
  String? _error;
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  // Getters
  List<CommunityPost> get posts => _posts;
  List<CommunityPost> get reportedPosts => _reportedPosts;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  
  void _init() {
    _repository.watchPosts().listen((posts) {
      _posts = posts;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
    
    _repository.watchReportedPosts().listen((posts) {
      _reportedPosts = posts;
      notifyListeners();
    });
  }
  
  Future<String?> addPost({
    required String uid,
    required String username,
    required String caption,
    required String imageBase64,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    
    try {
      final post = CommunityPost(
        id: '', // Will be generated
        uid: uid,
        username: username,
        caption: caption,
        imageBase64: imageBase64,
        likes: 0,
        timePosted: DateTime.now().millisecondsSinceEpoch,
        status: 'active',
        isReported: false,
      );
      
      final postId = await _repository.addPost(post);
      _isSubmitting = false;
      notifyListeners();
      return postId;
    } catch (e) {
      _isSubmitting = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  Future<bool> deletePost(String postId) async {
    try {
      await _repository.deletePost(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> reportPost(String postId) async {
    try {
      await _repository.reportPost(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> archivePost(String postId) async {
    try {
      await _repository.archivePost(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> dismissReport(String postId) async {
    try {
      await _repository.dismissReport(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> toggleLike(String postId, String userId) async {
    try {
      await _repository.toggleLike(postId, userId);
      // Update local like cache
      final current = _likeCache[postId] ?? false;
      _likeCache[postId] = !current;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> hasUserLiked(String postId, String userId) async {
    if (_likeCache.containsKey(postId)) {
      return _likeCache[postId]!;
    }
    
    final liked = await _repository.hasUserLiked(postId, userId);
    _likeCache[postId] = liked;
    return liked;
  }
  
  Stream<List<Comment>> watchComments(String postId) {
    return _repository.watchComments(postId);
  }
  
  Future<bool> addComment({
    required String postId,
    required String uid,
    required String username,
    required String text,
  }) async {
    try {
      final comment = Comment(
        id: '', // Will be generated
        postId: postId,
        uid: uid,
        username: username,
        text: text,
        timePosted: DateTime.now().millisecondsSinceEpoch,
      );
      
      await _repository.addComment(postId, comment);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await _repository.deleteComment(postId, commentId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}