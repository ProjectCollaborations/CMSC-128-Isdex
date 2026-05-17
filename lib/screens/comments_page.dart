import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../viewmodels/community_viewmodel.dart';
import '../data/models/comment.dart';
import 'theme.dart';

// ─────────────────────────────────────────────
// Design tokens (shared with community_page)
// ─────────────────────────────────────────────
class _T {
  static const navy      = kDarkNavy;
  static const accent    = kAccentBlue;
  static const lightBlue = kLightBlue;
  static const bg        = kBackground;
  static const textPri   = Color(0xFF0D1B2A);
  static const textSec   = Color(0xFF6B7B8D);
  static const divider   = Color(0xFFE4EBF2);
}

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
    _communityVm.watchComments(widget.postId).listen(
      (comments) {
        if (mounted) {
          setState(() {
            _comments = comments;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading comments: $error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showLoginPrompt(); return; }

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
        SnackBar(
          content: Text(_communityVm.error ?? 'Failed to add comment'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete comment?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: _T.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _T.textSec)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _communityVm.deleteComment(widget.postId, commentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: _T.navy, size: 22),
            SizedBox(width: 8),
            Text('Login Required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Please log in to comment.',
          style: TextStyle(color: _T.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _T.textSec)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
            style: FilledButton.styleFrom(
              backgroundColor: _T.navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
      backgroundColor: _T.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Logo centred; back arrow auto-added by Flutter
        title: Image.asset(
          'assets/images/isdex_logo.png',
          height: 30,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _T.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          // ── Comment count banner ─────────────────
          if (!_isLoading && _comments.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '${_comments.length} ${_comments.length == 1 ? 'comment' : 'comments'}',
                style: const TextStyle(
                  color: _T.textSec,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // ── Comment list ─────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2.5),
                  )
                : _comments.isEmpty
                    ? _EmptyComments()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isOwner =
                              currentUser != null && comment.uid == currentUser.uid;
                          return _CommentBubble(
                            comment: comment,
                            isOwner: isOwner,
                            onDelete: () => _deleteComment(comment.id),
                          );
                        },
                      ),
          ),

          // ── Input bar ────────────────────────────
          _CommentInput(
            controller: _commentController,
            onSend: _addComment,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────
class _EmptyComments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _T.lightBlue.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: _T.accent),
          ),
          const SizedBox(height: 14),
          const Text(
            'No comments yet',
            style: TextStyle(
              color: _T.textSec,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Be the first to share your thoughts!',
            style: TextStyle(color: _T.textSec, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Comment bubble
// ─────────────────────────────────────────────
class _CommentBubble extends StatelessWidget {
  final Comment comment;
  final bool isOwner;
  final VoidCallback onDelete;

  const _CommentBubble({
    required this.comment,
    required this.isOwner,
    required this.onDelete,
  });

  String get _initial =>
      comment.username.isNotEmpty ? comment.username[0].toUpperCase() : '?';

  Color get _avatarColor {
    final colors = [
      _T.navy,
      const Color(0xFF1A6FA8),
      _T.accent,
      const Color(0xFF0080B4),
      const Color(0xFF005F8A),
    ];
    return colors[comment.username.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_avatarColor, _avatarColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),

          // Bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _T.navy.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.username,
                    style: const TextStyle(
                      color: _T.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.text,
                    style: const TextStyle(
                      color: _T.textPri,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Delete (owner only)
          if (isOwner)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 6),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade300),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Comment input bar
// ─────────────────────────────────────────────
class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _CommentInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _T.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 8,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _T.bg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _T.divider, width: 1),
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: _T.textPri, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      hintStyle: TextStyle(color: _T.textSec, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Material(
                color: _T.navy,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onSend,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}