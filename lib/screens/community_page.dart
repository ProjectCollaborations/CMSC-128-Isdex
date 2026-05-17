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
import 'theme.dart';

// ─────────────────────────────────────────────
// Design tokens (aligned to theme.dart)
// ─────────────────────────────────────────────
class _T {
  // Colors
  static const navy       = kDarkNavy;           // 0xFF002347
  static const accent     = kAccentBlue;         // 0xFF5CC6FF
  static const lightBlue  = kLightBlue;          // 0xFFBFE7FF
  static const bg         = kBackground;         // 0xFFF5F7FB
  static const surface    = Colors.white;
  static const likeRed    = Color(0xFFEF4444);
  static const textPri    = Color(0xFF0D1B2A);
  static const textSec    = Color(0xFF6B7B8D);
  static const divider    = Color(0xFFE4EBF2);
  static const cardShadow = Color(0x10002347);

  // Gradients
  static const navyGradient = LinearGradient(
    colors: [navy, Color(0xFF00407A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text styles
  static const username  = TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: 13.5);
  static const caption   = TextStyle(color: textPri, fontSize: 13.5, height: 1.45);
  static const timeAgo   = TextStyle(color: textSec, fontSize: 11.5);
  static const likeCount = TextStyle(color: textSec, fontWeight: FontWeight.w600, fontSize: 13);
  static const emptyState = TextStyle(color: textSec, fontSize: 15, fontWeight: FontWeight.w500);
}

// ─────────────────────────────────────────────
// CommunityPage
// ─────────────────────────────────────────────
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final communityVm = context.watch<CommunityViewModel>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody(communityVm)),
      floatingActionButton: _BuildFAB(user: user),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/isdex_logo.png',
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          const Text(
            'Isdex Community',
            style: TextStyle(
              color: _T.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _T.divider, height: 1),
      ),
    );
  }

  Widget _buildBody(CommunityViewModel vm) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2.5),
      );
    }
    if (vm.error != null) {
      return _ErrorState(message: vm.error!, onRetry: vm.clearError);
    }
    return const _FeedList();
  }
}

// ─────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────
class _BuildFAB extends StatelessWidget {
  final User? user;
  const _BuildFAB({required this.user});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => user == null ? _showLoginPrompt(context) : _openCreatePostSheet(context),
      backgroundColor: _T.navy,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    );
  }
}

// ─────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: _T.emptyState),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _T.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Feed list
// ─────────────────────────────────────────────
class _FeedList extends StatelessWidget {
  const _FeedList();

  @override
  Widget build(BuildContext context) {
    final communityVm = context.watch<CommunityViewModel>();
    final posts = communityVm.posts;

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _T.lightBlue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.photo_library_outlined, size: 48, color: _T.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts yet.\nBe the first to share!',
              textAlign: TextAlign.center,
              style: _T.emptyState,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 100),
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

// ─────────────────────────────────────────────
// Post item
// ─────────────────────────────────────────────
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

class _PostItemState extends State<_PostItem> with SingleTickerProviderStateMixin {
  late final CommunityViewModel _communityVm;
  late AnimationController _likeController;
  late Animation<double> _likeScale;

  int _currentLikes = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _communityVm = context.read<CommunityViewModel>();
    _currentLikes = widget.likes;
    _loadLikeStatus();

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _likeScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _loadLikeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final liked = await _communityVm.hasUserLiked(widget.postId, user.uid);
      if (mounted) setState(() => _isLiked = liked);
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showLoginPrompt(context); return; }
    _likeController.forward(from: 0);
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
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionsSheet(
        isOwner: user.uid == widget.ownerUid,
        onDelete: () async {
          Navigator.pop(context);
          await _communityVm.deletePost(widget.postId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post deleted'), behavior: SnackBarBehavior.floating),
            );
          }
        },
        onReport: () async {
          Navigator.pop(context);
          await _communityVm.reportPost(widget.postId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post reported to moderators'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  String get _avatarInitial => widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?';

  Color get _avatarColor {
    final colors = [
      _T.navy,
      const Color(0xFF1A6FA8),
      _T.accent,
      const Color(0xFF0080B4),
      const Color(0xFF005F8A),
    ];
    return colors[widget.username.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? imageBytes =
        widget.imageBase64.isNotEmpty ? base64Decode(widget.imageBase64) : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: _T.cardShadow, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
            child: Row(
              children: [
                _Avatar(initial: _avatarInitial, color: _avatarColor),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username, style: _T.username),
                    Text(widget.timeAgo, style: _T.timeAgo),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: _T.textSec),
                  onPressed: _showOptionsMenu,
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // ── Caption ─────────────────────────────
          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(widget.caption, style: _T.caption),
            ),

          // ── Image ────────────────────────────────
          if (imageBytes != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(imageBytes, fit: BoxFit.cover, width: double.infinity),
            ),

          // ── Thin accent line under image ─────────
          if (imageBytes != null)
            Container(height: 2, color: _T.lightBlue.withOpacity(0.5)),

          // ── Actions ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: ScaleTransition(
                    scale: _likeScale,
                    child: Icon(
                      _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      color: _isLiked ? _T.likeRed : _T.textSec,
                      size: 22,
                    ),
                  ),
                  label: '$_currentLikes',
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: _T.textSec, size: 21),
                  label: 'Comment',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CommentsPage(postId: widget.postId)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initial;
  final Color color;
  const _Avatar({required this.initial, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 5),
            Text(label, style: _T.likeCount),
          ],
        ),
      ),
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _OptionsSheet({required this.isOwner, required this.onDelete, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            if (isOwner)
              _SheetTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete post',
                color: _T.likeRed,
                onTap: onDelete,
              )
            else
              _SheetTile(
                icon: Icons.flag_outlined,
                label: 'Report inappropriate post',
                color: Colors.orange,
                onTap: onReport,
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────
// Create post bottom sheet
// ─────────────────────────────────────────────
void _openCreatePostSheet(BuildContext context) {
  final captionController = TextEditingController();
  final communityVm = context.read<CommunityViewModel>();
  final user = FirebaseAuth.instance.currentUser;

  File? imageFile;
  String? base64Image;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New Post',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _T.textPri),
                ),
                const SizedBox(height: 16),

                // Image picker area
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (picked == null) return;
                    final bytes = await File(picked.path).readAsBytes();
                    setState(() {
                      imageFile = File(picked.path);
                      base64Image = base64Encode(bytes);
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: imageFile != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(imageFile!, fit: BoxFit.cover),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: _T.lightBlue.withOpacity(0.2),
                                border: Border.all(color: _T.accent.withOpacity(0.4), width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 44, color: _T.accent),
                                  const SizedBox(height: 8),
                                  Text('Tap to add a photo',
                                      style: TextStyle(
                                          color: _T.navy.withOpacity(0.6),
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Caption field
                TextField(
                  controller: captionController,
                  maxLines: 3,
                  minLines: 1,
                  style: _T.caption,
                  decoration: InputDecoration(
                    hintText: 'Write a caption…',
                    hintStyle: TextStyle(color: _T.textSec.withOpacity(0.7)),
                    filled: true,
                    fillColor: _T.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _T.accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Post button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: communityVm.isSubmitting
                        ? null
                        : () async {
                            if (base64Image == null || captionController.text.trim().isEmpty) return;
                            final postId = await communityVm.addPost(
                              uid: user!.uid,
                              username: user.email?.split('@')[0] ?? 'User',
                              caption: captionController.text.trim(),
                              imageBase64: base64Image!,
                            );
                            if (postId != null && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Post shared!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (context.mounted && communityVm.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(communityVm.error!),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _T.navy,
                      disabledBackgroundColor: _T.navy.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: communityVm.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Share Post',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ─────────────────────────────────────────────
// Login prompt
// ─────────────────────────────────────────────
void _showLoginPrompt(BuildContext context) {
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
        'Please log in to like, comment, or share posts.',
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
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

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────
String _timeAgoFromMillis(int millis) {
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}