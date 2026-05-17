class FirebaseNodes {
  FirebaseNodes._();

  // ── Fish catalog ──────────────────────────────────────────────────
  static String get fish => 'fish';
  static String fishById(String id) => 'fish/$id';
  static String get fishArchive => 'fish_archive';
  static String fishArchiveById(String id) => 'fish_archive/$id';

  // ── Map locations ────────────────────────────────────────────────
  static String get map => 'map';
  static String mapById(String id) => 'map/$id';

  // ── Users ────────────────────────────────────────────────────────
  static String get users => 'users';
  static String userById(String uid) => 'users/$uid';
  static String userRoleByUid(String uid) => 'users/$uid/role';
  static String get userEmails => 'userEmails';
  static String emailKey(String email) =>
      'userEmails/${email.replaceAll('.', ',')}';

  // ── Sightings ───────────────────────────────────────────────────
  static String get sightings => 'user_sightings_temp';
  static String sightingById(String id) => 'user_sightings_temp/$id';

  // ── Community posts ──────────────────────────────────────────────
  static String get communityPosts => 'community_posts';
  static String communityPostById(String id) => 'community_posts/$id';

  // ── Post likes ───────────────────────────────────────────────────
  static String postLikesByPostId(String postId) => 'post_likes/$postId';
  static String postLikeByUser(String postId, String uid) =>
      'post_likes/$postId/$uid';

  // ── Post comments ───────────────────────────────────────────────
  static String postCommentsByPostId(String postId) =>
      'post_comments/$postId';
  static String postCommentById(String postId, String commentId) =>
      'post_comments/$postId/$commentId';

  // ── Chat sessions ───────────────────────────────────────────────
  static String chatSessionsByUid(String uid) => 'chat_sessions/$uid';
}
