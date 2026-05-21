import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/comment.dart';
import 'package:isdex/models/community_post.dart';
import 'package:isdex/viewmodels/community_viewmodel.dart';

class FakeCommunityRepo {
  final StreamController<List<CommunityPost>> _postsController =
      StreamController<List<CommunityPost>>.broadcast();
  final Map<String, Set<String>> likedByUser = {};
  bool nextToggleResult = true;
  Duration isLikedDelay = Duration.zero;

  Stream<List<CommunityPost>> watchPosts() => _postsController.stream;

  Stream<List<Comment>> watchComments(String postId) =>
      Stream<List<Comment>>.value(const []);

  void emitPosts(List<CommunityPost> posts) {
    _postsController.add(posts);
  }

  Future<bool> toggleLike(String postId, String uid) async {
    return nextToggleResult;
  }

  Future<bool> isLikedBy(String postId, String uid) async {
    if (isLikedDelay != Duration.zero) {
      await Future.delayed(isLikedDelay);
    }
    return likedByUser[uid]?.contains(postId) ?? false;
  }

  Future<void> addPost({
    required String uid,
    required String username,
    required String caption,
    required String imageBase64,
  }) async {}

  Future<void> reportPost(String postId) async {}

  Future<void> deletePost(String postId) async {}

  void dispose() {
    _postsController.close();
  }
}

void main() {
  group('CommunityViewModel', () {
    late FakeCommunityRepo repo;
    late CommunityViewModel vm;
    String? currentUid;

    CommunityPost post(String id) {
      return CommunityPost(
        id: id,
        uid: 'owner',
        username: 'owner',
        caption: 'caption',
        imageBase64: '',
        likes: 0,
        timePosted: 0,
        isReported: false,
        status: 'active',
      );
    }

    setUp(() {
      repo = FakeCommunityRepo();
      currentUid = 'account-a';
      vm = CommunityViewModel(
        watchPosts: repo.watchPosts,
        watchComments: repo.watchComments,
        addPost: repo.addPost,
        toggleLike: repo.toggleLike,
        isLikedBy: repo.isLikedBy,
        reportPost: repo.reportPost,
        deletePost: repo.deletePost,
        currentUserId: () => currentUid,
        currentUserDisplay: () => currentUid ?? '',
      );
    });

    tearDown(() {
      vm.dispose();
      repo.dispose();
    });

    test(
      'clears liked posts immediately when the current user changes',
      () async {
        repo.likedByUser['account-a'] = {'post-1'};
        repo.emitPosts([post('post-1')]);
        await Future.delayed(const Duration(milliseconds: 20));

        expect(vm.likedPostIds, {'post-1'});

        currentUid = 'account-b';
        vm.handleCurrentUserChanged('account-b');

        expect(vm.likedPostIds, isEmpty);
      },
    );

    test(
      'ignores stale liked-state refresh results from a previous user',
      () async {
        repo.isLikedDelay = const Duration(milliseconds: 40);
        repo.likedByUser['account-a'] = {'post-1'};
        repo.likedByUser['account-b'] = <String>{};

        repo.emitPosts([post('post-1')]);
        await Future.delayed(const Duration(milliseconds: 10));

        currentUid = 'account-b';
        vm.handleCurrentUserChanged('account-b');
        await Future.delayed(const Duration(milliseconds: 80));

        expect(vm.likedPostIds, isEmpty);
      },
    );

    test('uses repository final liked state after toggling', () async {
      repo.likedByUser['account-a'] = {'post-1'};
      repo.emitPosts([post('post-1')]);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(vm.likedPostIds, {'post-1'});

      repo.nextToggleResult = false;
      await vm.toggleLike('post-1');

      expect(vm.likedPostIds, isEmpty);
    });
  });
}
