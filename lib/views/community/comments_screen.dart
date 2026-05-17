import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/community_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';

class CommentsScreen extends StatelessWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CommunityRepository>();
    final authVm = context.watch<AuthViewModel>();
    final currentUserId = authVm.user?.uid;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: repo.watchComments(postId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isOwner = comment.uid == currentUserId;

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
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: '${comment.username} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: comment.text),
                                ],
                              ),
                            ),
                          ),
                          if (isOwner)
                            InkWell(
                              onTap: () => _showDeleteCommentDialog(
                                context,
                                repo,
                                postId,
                                comment.id,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
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
          _CommentInput(postId: postId),
        ],
      ),
    );
  }
}

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
    final repo = context.read<CommunityRepository>();
    final authVm = context.read<AuthViewModel>();
    final user = authVm.user;

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
                if (user == null || controller.text.trim().isEmpty) return;

                final text = controller.text.trim();
                controller.clear();

                await repo.addComment(
                  postId: widget.postId,
                  uid: user.uid,
                  username: user.email.split('@')[0],
                  text: text,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

void _showDeleteCommentDialog(
  BuildContext context,
  CommunityRepository repo,
  String postId,
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
            Navigator.pop(context);
            await repo.deleteComment(postId, commentId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comment deleted')),
              );
            }
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
