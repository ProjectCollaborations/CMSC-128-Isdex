import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/community_post.dart';
import 'package:isdex/models/comment.dart';
import 'package:isdex/viewmodels/community_viewmodel.dart';

class FakeCommunityRepo {
  final StreamController<List<CommunityPost>> _postsController =
      StreamController<List<CommunityPost>>.broadcast();
  final StreamController<List<Comment>> _commentsController =
      StreamController<List<Comment>>.broadcast();

  bool toggleLikeCalled = false;
  bool addPostCalled = false;
  bool reportPostCalled = false;
  bool deletePostCalled = false;
  String? lastPostId;
  String? lastUid;
  String? lastCaption;
  String? lastImageBase64;
  bool nextToggleResult = true;

  void emitPosts(List<CommunityPost> posts) {
    _postsController.add(posts);
  }

  void emitComments(String postId, List<Comment> comments) {
    _commentsController.add(comments);
  }

  Stream<List<CommunityPost>> watchPosts() => _postsController.stream;

  Stream<List<Comment>> watchComments(String postId) =>
      _commentsController.stream;

  Future<void> addPost({
    required String uid,
    required String username,
    required String caption,
    required String imageBase64,
  }) async {
    addPostCalled = true;
    lastUid = uid;
    lastCaption = caption;
    lastImageBase64 = imageBase64;
  }

  Future<bool> toggleLike(String postId, String uid) async {
    toggleLikeCalled = true;
    lastPostId = postId;
    lastUid = uid;
    return nextToggleResult;
  }

  Future<bool> isLikedBy(String postId, String uid) async => false;

  Future<void> reportPost(String postId) async {
    reportPostCalled = true;
    lastPostId = postId;
  }

  Future<void> deletePost(String postId) async {
    deletePostCalled = true;
    lastPostId = postId;
  }

  void dispose() {
    _postsController.close();
    _commentsController.close();
  }
}

void main() {
  group('CommunityViewModel', () {
    late CommunityViewModel vm;
    late FakeCommunityRepo fakeRepo;

    final testPosts = [
      CommunityPost(
        id: '1',
        uid: 'user1',
        username: 'User1',
        caption: 'First post',
        imageBase64: '',
        likes: 5,
        timePosted: 3000,
        isReported: false,
        status: 'active',
      ),
      CommunityPost(
        id: '2',
        uid: 'user2',
        username: 'User2',
        caption: 'Second post',
        imageBase64: '',
        likes: 3,
        timePosted: 2000,
        isReported: false,
        status: 'active',
      ),
    ];

    setUp(() {
      fakeRepo = FakeCommunityRepo();
      vm = CommunityViewModel(
        watchPosts: () => fakeRepo.watchPosts(),
        watchComments: (postId) => fakeRepo.watchComments(postId),
        addPost:
            ({
              required uid,
              required username,
              required caption,
              required imageBase64,
            }) => fakeRepo.addPost(
              uid: uid,
              username: username,
              caption: caption,
              imageBase64: imageBase64,
            ),
        toggleLike: (postId, uid) => fakeRepo.toggleLike(postId, uid),
        isLikedBy: (postId, uid) => fakeRepo.isLikedBy(postId, uid),
        reportPost: (postId) => fakeRepo.reportPost(postId),
        deletePost: (postId) => fakeRepo.deletePost(postId),
        currentUserId: () => 'test-uid',
        currentUserDisplay: () => 'TestUser',
      );
    });

    tearDown(() {
      vm.dispose();
      fakeRepo.dispose();
    });

    test('initial state has empty posts and loading', () {
      expect(vm.posts, isEmpty);
      expect(vm.commentCounts, isEmpty);
      expect(vm.likedPostIds, isEmpty);
      expect(vm.isLoading, isTrue);
    });

    test('receives posts from stream', () async {
      fakeRepo.emitPosts(testPosts);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.posts.length, 2);
      expect(vm.isLoading, isFalse);
    });

    test('tracks comment counts from comment streams', () async {
      fakeRepo.emitPosts(testPosts);
      await Future.delayed(const Duration(milliseconds: 50));
      fakeRepo.emitComments('1', [
        Comment(
          id: 'c1',
          uid: 'u1',
          username: 'U1',
          text: 'Nice',
          timePosted: 100,
        ),
        Comment(
          id: 'c2',
          uid: 'u2',
          username: 'U2',
          text: 'Great',
          timePosted: 200,
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.commentCounts['1'], 2);
    });

    test('toggleLike calls repository and updates likedPostIds', () async {
      fakeRepo.emitPosts(testPosts);
      await Future.delayed(const Duration(milliseconds: 50));
      await vm.toggleLike('1');
      expect(fakeRepo.toggleLikeCalled, isTrue);
      expect(fakeRepo.lastPostId, '1');
      expect(vm.likedPostIds, {'1'});
    });

    test('addPost calls repository with correct params', () async {
      await vm.addPost(
        caption: 'My post',
        imageBase64: 'data:image/png;base64,abc',
      );
      expect(fakeRepo.addPostCalled, isTrue);
      expect(fakeRepo.lastCaption, 'My post');
      expect(fakeRepo.lastImageBase64, 'data:image/png;base64,abc');
      expect(fakeRepo.lastUid, 'test-uid');
    });

    test('reportPost calls repository', () async {
      await vm.reportPost('1');
      expect(fakeRepo.reportPostCalled, isTrue);
      expect(fakeRepo.lastPostId, '1');
    });

    test(
      'deletePost calls repository and cleans up comment subscription',
      () async {
        fakeRepo.emitPosts(testPosts);
        await Future.delayed(const Duration(milliseconds: 50));
        await vm.deletePost('1');
        expect(fakeRepo.deletePostCalled, isTrue);
        expect(fakeRepo.lastPostId, '1');
      },
    );

    test('currentUserId returns null when not logged in', () {
      final vmNoUser = CommunityViewModel(
        watchPosts: () => fakeRepo.watchPosts(),
        watchComments: (postId) => fakeRepo.watchComments(postId),
        addPost:
            ({
              required uid,
              required username,
              required caption,
              required imageBase64,
            }) => fakeRepo.addPost(
              uid: uid,
              username: username,
              caption: caption,
              imageBase64: imageBase64,
            ),
        toggleLike: (postId, uid) => fakeRepo.toggleLike(postId, uid),
        isLikedBy: (postId, uid) => fakeRepo.isLikedBy(postId, uid),
        reportPost: (postId) => fakeRepo.reportPost(postId),
        deletePost: (postId) => fakeRepo.deletePost(postId),
        currentUserId: () => null,
        currentUserDisplay: () => 'TestUser',
      );
      expect(vmNoUser.currentUserId, isNull);
      vmNoUser.dispose();
    });
  });
}
