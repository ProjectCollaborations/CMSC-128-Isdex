import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/community_post.dart';

void main() {
  group('CommunityPost', () {
    test('fromMap creates CommunityPost from RTDB data', () {
      final data = <String, dynamic>{
        'uid': 'user1',
        'username': 'johndoe',
        'caption': 'Great catch!',
        'imageBase64': 'base64data',
        'likes': 5,
        'timePosted': 1700000000000,
        'status': 'active',
        'isReported': false,
      };

      final post = CommunityPost.fromMap('post1', data);

      expect(post.id, 'post1');
      expect(post.uid, 'user1');
      expect(post.username, 'johndoe');
      expect(post.caption, 'Great catch!');
      expect(post.likes, 5);
      expect(post.isReported, false);
    });

    test('fromMap defaults missing fields', () {
      final data = <String, dynamic>{};
      final post = CommunityPost.fromMap('p1', data);

      expect(post.uid, '');
      expect(post.likes, 0);
      expect(post.isReported, false);
      expect(post.status, 'active');
    });

    test('toMap produces correct map', () {
      final post = CommunityPost(
        id: 'post1',
        uid: 'user1',
        username: 'johndoe',
        caption: 'Hello',
        imageBase64: 'data',
        likes: 3,
        timePosted: 1700000000000,
        isReported: false,
        status: 'active',
      );

      final map = post.toMap();
      expect(map['uid'], 'user1');
      expect(map['likes'], 3);
      expect(map['status'], 'active');
    });

    test('copyWith creates modified copy', () {
      final post = CommunityPost(
        id: 'p1',
        uid: 'u1',
        username: 'user',
        caption: 'hi',
        imageBase64: '',
        likes: 0,
        timePosted: 0,
        isReported: false,
        status: 'active',
      );

      final reported = post.copyWith(isReported: true);
      expect(reported.isReported, true);
      expect(post.isReported, false);
    });
  });
}
