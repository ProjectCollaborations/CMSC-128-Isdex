// lib/core/constants/firebase_nodes.dart
/// Centralized Firebase Realtime Database node paths.
/// All database references must use these constants.
class FirebaseNodes {
  FirebaseNodes._(); // Private constructor - not instantiable

  // MARK: - Root nodes
  static const String users = 'users';
  static const String userEmails = 'userEmails';
  static const String fish = 'fish';
  static const String fishArchive = 'fish_archive';
  static const String map = 'map';
  static const String userSightingsTemp = 'user_sightings_temp';
  static const String communityPosts = 'community_posts';
  static const String postComments = 'post_comments';
  static const String postLikes = 'post_likes';
  static const String chatSessions = 'chat_sessions';

  // MARK: - Nested paths (helpers)
  static String userRole(String uid) => '$users/$uid/role';
  static String userById(String uid) => '$users/$uid';
  static String userEmailLookup(String emailKey) => '$userEmails/$emailKey';
  static String fishById(String fishId) => '$fish/$fishId';
  static String fishArchiveById(String fishId) => '$fishArchive/$fishId';
  static String sightingById(String sightingId) => '$userSightingsTemp/$sightingId';
  static String communityPostById(String postId) => '$communityPosts/$postId';
  static String postCommentsByPostId(String postId) => '$postComments/$postId';
  static String postLikeByUser(String postId, String userId) => '$postLikes/$postId/$userId';
  static String chatSessionByUser(String userId) => '$chatSessions/$userId';
}