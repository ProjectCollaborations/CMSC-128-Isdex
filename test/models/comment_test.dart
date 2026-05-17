import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/comment.dart';

void main() {
  group('Comment', () {
    test('fromMap creates Comment from RTDB data', () {
      final data = <String, dynamic>{
        'uid': 'user1',
        'username': 'johndoe',
        'text': 'Nice!',
        'timePosted': 1700000000000,
      };

      final comment = Comment.fromMap('c1', data);

      expect(comment.id, 'c1');
      expect(comment.uid, 'user1');
      expect(comment.username, 'johndoe');
      expect(comment.text, 'Nice!');
      expect(comment.timePosted, 1700000000000);
    });

    test('fromMap defaults missing fields', () {
      final data = <String, dynamic>{};
      final comment = Comment.fromMap('c2', data);

      expect(comment.uid, '');
      expect(comment.text, '');
      expect(comment.timePosted, 0);
    });

    test('toMap produces correct map', () {
      final comment = Comment(
        id: 'c1',
        uid: 'user1',
        username: 'johndoe',
        text: 'Nice!',
        timePosted: 1700000000000,
      );

      final map = comment.toMap();
      expect(map['uid'], 'user1');
      expect(map['text'], 'Nice!');
    });
  });
}
