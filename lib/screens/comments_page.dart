import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../viewmodels/community_viewmodel.dart';
import '../data/models/comment.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  late final CommunityViewModel _communityVm;
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _communityVm = context.read<CommunityViewModel>();
    _loadComments();
  }

  void _loadComments() {
    _communityVm.watchComments(widget.postId).listen((comments) {
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comments: $error'), backgroundColor: Colors.red),
        );
      }
    });
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginPrompt();
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    
    final success = await _communityVm.addComment(
      postId: widget.postId,
      uid: user.uid,
      username: user.email?.split('@')[0] ?? 'User',
      text: text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_communityVm.error ?? 'Failed to add comment'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _communityVm.deleteComment(widget.postId, commentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please log in to comment.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isOwner = currentUser != null && comment.uid == currentUser.uid;

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
                                        TextSpan(text: '${comment.username} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        TextSpan(text: comment.text),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isOwner)
                                  InkWell(
                                    onTap: () => _deleteComment(comment.id),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
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
                      controller: _commentController,
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
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}