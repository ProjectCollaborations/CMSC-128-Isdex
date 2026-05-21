import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/community_viewmodel.dart';
import '../../models/community_post.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityViewModel>();

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
        child: vm.isLoading
            ? const Center(child: CircularProgressIndicator())
            : vm.posts.isEmpty
                ? const Center(child: Text('No posts yet'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: vm.posts.length,
                    itemBuilder: (context, index) {
                      final post = vm.posts[index];
                      return _PostCard(
                        post: post,
                        isLiked: vm.likedPostIds.contains(post.id),
                        commentCount: vm.commentCounts[post.id] ?? 0,
                        isLoggedIn: vm.currentUserId != null,
                        isOwner: vm.currentUserId == post.uid,
                        onLike: () => vm.toggleLike(post.id),
                        onComment: () => context.push('/comments/${post.id}'),
                        onDelete: () => vm.deletePost(post.id),
                        onReport: () => vm.reportPost(post.id),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (vm.currentUserId == null) {
            _showLoginPrompt(context);
          } else {
            _openCreatePostSheet(context, vm);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final bool isLiked;
  final int commentCount;
  final bool isLoggedIn;
  final bool isOwner;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;
  final Future<void> Function() onReport;

  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.commentCount,
    required this.isLoggedIn,
    required this.isOwner,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes =
        post.imageBase64.isNotEmpty ? base64Decode(post.imageBase64) : null;

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
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: isLoggedIn ? onLike : () => _showLoginPrompt(context),
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: isLoggedIn ? onComment : () => _showLoginPrompt(context),
              ),
              const Spacer(),
              if (isLoggedIn)
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showOptionsSheet(context),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('${post.likes} likes',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Text('$commentCount comments',
                    style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(
                    text: '${post.username} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _timeAgoFromMillis(post.timePosted),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
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
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete post'),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post deleted')),
                  );
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text('Report inappropriate post'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await onReport();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post reported to moderators.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to report post. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

void _openCreatePostSheet(BuildContext context, CommunityViewModel vm) {
  final captionController = TextEditingController();
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
                  decoration:
                      const InputDecoration(hintText: 'Write a caption...'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 50);
                    if (picked == null) return;

                    final bytes =
                        await File(picked.path).readAsBytes();
                    setState(() {
                      imageFile = File(picked.path);
                      base64Image = base64Encode(bytes);
                    });
                  },
                  child: const Text('Select Image'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (base64Image == null ||
                        captionController.text.trim().isEmpty) {
                      return;
                    }

                    await vm.addPost(
                      caption: captionController.text.trim(),
                      imageBase64: base64Image!,
                    );

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Post'),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.go('/login');
          },
          child: const Text('Log In'),
        ),
      ],
    ),
  );
}

String _timeAgoFromMillis(int millis) {
  final diff = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
