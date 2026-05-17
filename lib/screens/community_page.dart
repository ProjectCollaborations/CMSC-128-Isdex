import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../viewmodels/community_viewmodel.dart';
import 'login_page.dart';
import 'comments_page.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final communityVm = context.watch<CommunityViewModel>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Isdex Community',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: communityVm.isLoading
            ? const Center(child: CircularProgressIndicator())
            : communityVm.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(communityVm.error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => communityVm.clearError(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _FeedList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (user == null) {
            _showLoginPrompt(context);
          } else {
            _openCreatePostSheet(context);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final communityVm = context.watch<CommunityViewModel>();
    final posts = communityVm.posts;

    if (posts.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _PostItem(
          postId: post.id,
          ownerUid: post.uid,
          username: post.username,
          caption: post.caption,
          likes: post.likes,
          imageBase64: post.imageBase64,
          timeAgo: _timeAgoFromMillis(post.timePosted),
        );
      },
    );
  }
}

class _PostItem extends StatefulWidget {
  final String postId;
  final String ownerUid;
  final String username;
  final String caption;
  final int likes;
  final String imageBase64;
  final String timeAgo;

  const _PostItem({
    required this.postId,
    required this.ownerUid,
    required this.username,
    required this.caption,
    required this.likes,
    required this.imageBase64,
    required this.timeAgo,
  });

  @override
  State<_PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<_PostItem> {
  late final CommunityViewModel _communityVm;
  int _currentLikes = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _communityVm = context.read<CommunityViewModel>();
    _currentLikes = widget.likes;
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final liked = await _communityVm.hasUserLiked(widget.postId, user.uid);
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginPrompt(context);
      return;
    }
    setState(() {
      _isLiked = !_isLiked;
      _currentLikes += _isLiked ? 1 : -1;
    });
    await _communityVm.toggleLike(widget.postId, user.uid);
  }

  Future<void> _showOptionsMenu() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.uid == widget.ownerUid)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete post'),
                onTap: () async {
                  Navigator.pop(context);
                  await _communityVm.deletePost(widget.postId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post deleted')),
                    );
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text('Report inappropriate post'),
                onTap: () async {
                  Navigator.pop(context);
                  await _communityVm.reportPost(widget.postId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post reported to moderators.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes = widget.imageBase64.isNotEmpty ? base64Decode(widget.imageBase64) : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageBytes != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.black),
                onPressed: _toggleLike,
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CommentsPage(postId: widget.postId)),
                  );
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: _showOptionsMenu,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('$_currentLikes likes', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                StreamBuilder<int>(
                  stream: null, // Comment count - would need separate stream
                  builder: (context, snapshot) {
                    // For simplicity, we'll show a placeholder
                    // In production, fetch comment count from ViewModel
                    return Text('0 comments', style: TextStyle(color: Colors.grey[700]));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(text: '${widget.username} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: widget.caption),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(widget.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}

void _openCreatePostSheet(BuildContext context) {
  final captionController = TextEditingController();
  final communityVm = context.read<CommunityViewModel>();
  final user = FirebaseAuth.instance.currentUser;

  File? imageFile;
  String? base64Image;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.cover)
                      : Container(color: Colors.grey[300]),
                ),
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(hintText: 'Write a caption...'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (picked == null) return;
                    final bytes = await File(picked.path).readAsBytes();
                    setState(() {
                      imageFile = File(picked.path);
                      base64Image = base64Encode(bytes);
                    });
                  },
                  child: const Text('Select Image'),
                ),
                ElevatedButton(
                  onPressed: communityVm.isSubmitting
                      ? null
                      : () async {
                          if (base64Image == null || captionController.text.trim().isEmpty) {
                            return;
                          }
                          final postId = await communityVm.addPost(
                            uid: user!.uid,
                            username: user.email?.split('@')[0] ?? 'User',
                            caption: captionController.text.trim(),
                            imageBase64: base64Image!,
                          );
                          if (postId != null && context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post created!')),
                            );
                          } else if (context.mounted && communityVm.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(communityVm.error!), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: communityVm.isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showLoginPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Login Required'),
      content: const Text('Please log in to use this feature.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          },
          child: const Text('Log In'),
        ),
      ],
    ),
  );
}

String _timeAgoFromMillis(int millis) {
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}