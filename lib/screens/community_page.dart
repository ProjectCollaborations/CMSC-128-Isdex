// lib/screens/community_page.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

import 'login_page.dart';
import 'comments_page.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const SafeArea(child: _FeedList()),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final user = FirebaseAuth.instance.currentUser;
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

/// ================= FEED =================
class _FeedList extends StatelessWidget {
  const _FeedList();

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref('community_posts');

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('No posts yet'));
        }

        final raw = snapshot.data!.snapshot.value as Map;
        
        // MODERATION: Filter out posts that have been archived by admins
        final entries = raw.entries.where((e) {
          final data = e.value as Map;
          return data['status'] != 'archived'; 
        }).toList()
          ..sort((a, b) =>
              (b.value['timePosted'] ?? 0)
                  .compareTo(a.value['timePosted'] ?? 0));

        if (entries.isEmpty) {
          return const Center(child: Text('No active posts found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final postId = entries[index].key;
            final data = Map<String, dynamic>.from(entries[index].value);

            return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('post_comments/$postId')
                  .onValue,
              builder: (context, commentSnap) {
                int commentCount = 0;
                if (commentSnap.data?.snapshot.value != null) {
                  commentCount =
                      (commentSnap.data!.snapshot.value as Map).length;
                }

                return _PostItem(
                  postId: postId,
                  ownerUid: data['uid'],
                  username: data['username'] ?? 'User',
                  caption: data['caption'] ?? '',
                  likes: data['likes'] ?? 0,
                  commentCount: commentCount,
                  timeAgo: _timeAgoFromMillis(data['timePosted']),
                  imageBase64: data['imageBase64'] ?? '',
                );
              },
            );
          },
        );
      },
    );
  }
}

/// ================= POST CARD =================
class _PostItem extends StatelessWidget {
  final String postId;
  final String? ownerUid;
  final String username;
  final String caption;
  final int likes;
  final int commentCount;
  final String timeAgo;
  final String imageBase64;

  const _PostItem({
    required this.postId,
    required this.ownerUid,
    required this.username,
    required this.caption,
    required this.likes,
    required this.commentCount,
    required this.timeAgo,
    required this.imageBase64,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes =
        imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

    final user = FirebaseAuth.instance.currentUser;

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
              StreamBuilder<DatabaseEvent>(
                stream: user == null
                    ? null
                    : FirebaseDatabase.instance
                        .ref('post_likes/$postId/${user.uid}')
                        .onValue,
                builder: (context, snap) {
                  final isLiked =
                      snap.data?.snapshot.exists ?? false;

                  return IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.black,
                    ),
                    onPressed: () {
                      if (user == null) {
                        _showLoginPrompt(context);
                        return;
                      }
                      toggleLike(postId: postId, userId: user.uid);
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentsPage(postId: postId),
                    ),
                  );
                },
              ),
              const Spacer(),
              
              // MODERATION: Show options menu to all logged-in users
              if (user != null)
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {
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
                            // Option 1: Delete (Only for the owner)
                            if (user.uid == ownerUid)
                              ListTile(
                                leading: const Icon(Icons.delete, color: Colors.red),
                                title: const Text('Delete post'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final db = FirebaseDatabase.instance.ref();
                                  await db.child('community_posts/$postId').remove();
                                  await db.child('post_likes/$postId').remove();
                                  await db.child('post_comments/$postId').remove();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Post deleted')),
                                    );
                                  }
                                },
                              )
                            // Option 2: Report (For everyone else)
                            else
                              ListTile(
                                leading: const Icon(Icons.flag, color: Colors.orange),
                                title: const Text('Report inappropriate post'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  // Flag the post for moderators
                                  await FirebaseDatabase.instance
                                      .ref('community_posts/$postId')
                                      .update({'isReported': true});
                                  
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
                  },
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('$likes likes',
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
                    text: '$username ',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: caption),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              timeAgo,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= CREATE POST =================
void _openCreatePostSheet(BuildContext context) {
  final captionController = TextEditingController();
  final ref = FirebaseDatabase.instance.ref('community_posts');
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

                    await ref.push().set({
                      'uid': user!.uid,
                      'username':
                          user.email?.split('@')[0] ?? 'User',
                      'caption': captionController.text.trim(),
                      'imageBase64': base64Image,
                      'likes': 0,
                      'timePosted': ServerValue.timestamp,
                      // MODERATION: Default states for new posts
                      'status': 'active',
                      'isReported': false,
                    });

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

/// ================= LIKE LOGIC =================
Future<void> toggleLike({
  required String postId,
  required String userId,
}) async {
  final db = FirebaseDatabase.instance.ref();
  final likeRef = db.child('post_likes/$postId/$userId');
  final countRef = db.child('community_posts/$postId/likes');

  final snap = await likeRef.get();
  if (snap.exists) {
    await likeRef.remove();
    await countRef.runTransaction((v) {
      final cur = (v as int?) ?? 0;
      return Transaction.success(cur > 0 ? cur - 1 : 0);
    });
  } else {
    await likeRef.set(true);
    await countRef.runTransaction((v) {
      final cur = (v as int?) ?? 0;
      return Transaction.success(cur + 1);
    });
  }
}

/// ================= HELPERS =================
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          child: const Text('Log In'),
        ),
      ],
    ),
  );
}

String _timeAgoFromMillis(dynamic millis) {
  if (millis == null || millis is! int) return '';
  final diff = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}