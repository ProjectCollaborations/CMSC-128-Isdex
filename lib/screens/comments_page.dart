import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CommentsPage extends StatelessWidget {
  final String postId;
  const CommentsPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref('post_comments/$postId');
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          /// ================= COMMENTS LIST =================
          Expanded(
            child: StreamBuilder(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final raw = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );

                final comments = raw.entries.toList()
                  ..sort(
                    (a, b) => (a.value['timePosted'] as int)
                        .compareTo(b.value['timePosted'] as int),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentId = comments[index].key;
                    final c = comments[index].value;

                    final bool isOwner = currentUser != null &&
                        c['uid'] == currentUser.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// COMMENT TEXT
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style:
                                    const TextStyle(color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: '${c['username']} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: c['text']),
                                ],
                              ),
                            ),
                          ),

                          /// DELETE OPTION (ONLY FOR OWNER)
                          if (isOwner)
                            InkWell(
                              onTap: () {
                                _showDeleteCommentDialog(
                                  context,
                                  ref,
                                  commentId,
                                );
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// ================= COMMENT INPUT =================
          _CommentInput(postId: postId),
        ],
      ),
    );
  }
}

/// ================= COMMENT INPUT =================
class _CommentInput extends StatefulWidget {
  final String postId;
  const _CommentInput({required this.postId});

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          top: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                if (user == null || controller.text.trim().isEmpty) {
                  return;
                }

                final text = controller.text.trim();
                controller.clear(); // Clear FIRST for instant visual feedback
                
                final ref = FirebaseDatabase.instance
                    .ref('post_comments/${widget.postId}')
                    .push();

                await ref.set({
                  'uid': user.uid,
                  'username': user.email?.split('@')[0] ?? 'User',
                  'text': text,
                  'timePosted': ServerValue.timestamp,
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= DELETE CONFIRMATION =================
void _showDeleteCommentDialog(
  BuildContext context,
  DatabaseReference commentsRef,
  String commentId,
) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete comment?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog FIRST
            await commentsRef.child(commentId).remove();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comment deleted')),
            );
          },
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}
