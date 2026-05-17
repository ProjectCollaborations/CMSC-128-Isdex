import 'package:flutter/foundation.dart';

@immutable
class CommunityPost {
  final String id;
  final String uid;
  final String username;
  final String caption;
  final String imageBase64;
  final int likes;
  final int timePosted;
  final String status; // 'active', 'archived'
  final bool isReported;

  const CommunityPost({
    required this.id,
    required this.uid,
    required this.username,
    required this.caption,
    required this.imageBase64,
    required this.likes,
    required this.timePosted,
    required this.status,
    required this.isReported,
  });

  factory CommunityPost.fromSnapshot(String id, Map<dynamic, dynamic> data) {
    return CommunityPost(
      id: id,
      uid: data['uid']?.toString() ?? '',
      username: data['username']?.toString() ?? 'Anonymous',
      caption: data['caption']?.toString() ?? '',
      imageBase64: data['imageBase64']?.toString() ?? '',
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      timePosted: (data['timePosted'] as num?)?.toInt() ?? 0,
      status: data['status']?.toString() ?? 'active',
      isReported: data['isReported'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'caption': caption,
      'imageBase64': imageBase64,
      'likes': likes,
      'timePosted': timePosted,
      'status': status,
      'isReported': isReported,
    };
  }

  CommunityPost copyWith({
    String? id,
    String? uid,
    String? username,
    String? caption,
    String? imageBase64,
    int? likes,
    int? timePosted,
    String? status,
    bool? isReported,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      caption: caption ?? this.caption,
      imageBase64: imageBase64 ?? this.imageBase64,
      likes: likes ?? this.likes,
      timePosted: timePosted ?? this.timePosted,
      status: status ?? this.status,
      isReported: isReported ?? this.isReported,
    );
  }
}