class CommunityPost {
  final String id;
  final String uid;
  final String username;
  final String caption;
  final String imageBase64;
  final int likes;
  final int timePosted;
  final bool isReported;
  final String status;

  const CommunityPost({
    required this.id,
    required this.uid,
    required this.username,
    required this.caption,
    required this.imageBase64,
    required this.likes,
    required this.timePosted,
    required this.isReported,
    required this.status,
  });

  factory CommunityPost.fromMap(String id, Map<dynamic, dynamic> map) {
    return CommunityPost(
      id: id,
      uid: map['uid']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      caption: map['caption']?.toString() ?? '',
      imageBase64: map['imageBase64']?.toString() ?? '',
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      timePosted: (map['timePosted'] as num?)?.toInt() ?? 0,
      isReported: map['isReported'] == true,
      status: map['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'caption': caption,
        'imageBase64': imageBase64,
        'likes': likes,
        'timePosted': timePosted,
        'isReported': isReported,
        'status': status,
      };

  CommunityPost copyWith({
    String? id,
    String? uid,
    String? username,
    String? caption,
    String? imageBase64,
    int? likes,
    int? timePosted,
    bool? isReported,
    String? status,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      caption: caption ?? this.caption,
      imageBase64: imageBase64 ?? this.imageBase64,
      likes: likes ?? this.likes,
      timePosted: timePosted ?? this.timePosted,
      isReported: isReported ?? this.isReported,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityPost &&
          id == other.id &&
          likes == other.likes &&
          isReported == other.isReported &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, likes, isReported, status);
}
