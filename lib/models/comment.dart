class Comment {
  final String id;
  final String uid;
  final String username;
  final String text;
  final int timePosted;

  const Comment({
    required this.id,
    required this.uid,
    required this.username,
    required this.text,
    required this.timePosted,
  });

  factory Comment.fromMap(String id, Map<dynamic, dynamic> map) {
    return Comment(
      id: id,
      uid: map['uid']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timePosted: (map['timePosted'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'text': text,
        'timePosted': timePosted,
      };

  Comment copyWith({
    String? id,
    String? uid,
    String? username,
    String? text,
    int? timePosted,
  }) {
    return Comment(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      text: text ?? this.text,
      timePosted: timePosted ?? this.timePosted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Comment && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
