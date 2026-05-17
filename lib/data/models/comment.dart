import 'package:flutter/foundation.dart';

@immutable
class Comment {
  final String id;
  final String postId;
  final String uid;
  final String username;
  final String text;
  final int timePosted;

  const Comment({
    required this.id,
    required this.postId,
    required this.uid,
    required this.username,
    required this.text,
    required this.timePosted,
  });

  factory Comment.fromSnapshot(String id, String postId, Map<dynamic, dynamic> data) {
    return Comment(
      id: id,
      postId: postId,
      uid: data['uid']?.toString() ?? '',
      username: data['username']?.toString() ?? 'Anonymous',
      text: data['text']?.toString() ?? '',
      timePosted: (data['timePosted'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'text': text,
      'timePosted': timePosted,
    };
  }
}