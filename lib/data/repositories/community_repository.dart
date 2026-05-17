import '../models/community_post.dart';
import '../models/comment.dart';

abstract class CommunityRepository {
  /// Stream of all posts (filtered by status)
  Stream<List<CommunityPost>> watchPosts({bool includeArchived = false});
  
  /// Stream of reported posts (for admin)
  Stream<List<CommunityPost>> watchReportedPosts();
  
  /// Add a new post
  Future<String> addPost(CommunityPost post);
  
  /// Delete a post
  Future<void> deletePost(String postId);
  
  /// Report a post
  Future<void> reportPost(String postId);
  
  /// Archive a post (admin/mod)
  Future<void> archivePost(String postId);
  
  /// Dismiss report (admin/mod)
  Future<void> dismissReport(String postId);
  
  /// Toggle like on a post
  Future<void> toggleLike(String postId, String userId);
  
  /// Check if user liked a post
  Future<bool> hasUserLiked(String postId, String userId);
  
  /// Add a comment
  Future<void> addComment(String postId, Comment comment);
  
  /// Delete a comment
  Future<void> deleteComment(String postId, String commentId);
  
  /// Stream of comments for a post
  Stream<List<Comment>> watchComments(String postId);
  
  /// Get comment count for a post
  Future<int> getCommentCount(String postId);
}