import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/community_post.dart';
import '../../../viewmodels/admin_viewmodel.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/app_card.dart';

Uint8List? _tryDecodeBase64(String data) {
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

class ReportedPostsView extends StatelessWidget {
  const ReportedPostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();

    if (vm.reportsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.reportedPosts.isEmpty) {
      return const Center(
        child: Text('No reported posts', style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: vm.reportedPosts.length,
      itemBuilder: (context, index) {
        final post = vm.reportedPosts[index];
        return _ReportedPostCard(
          post: post,
          isProcessing: vm.isProcessing,
          onDismiss: () => _confirmDismiss(context, post.id),
          onArchive: () => _confirmArchive(context, post.id),
        );
      },
    );
  }

  void _confirmArchive(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Post'),
        content: const Text(
          'This will remove the post from the community. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AdminViewModel>().archiveReportedPost(postId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post archived.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Archive failed: $e')),
                  );
                }
              }
            },
            child: const Text('Archive', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDismiss(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Report'),
        content: const Text(
          'This will remove the report flag from this post. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AdminViewModel>().dismissReport(postId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report dismissed.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dismiss failed: $e')),
                  );
                }
              }
            },
            child: const Text('Dismiss',
                style: TextStyle(color: AppTheme.success)),
          ),
        ],
      ),
    );
  }
}

class _ReportedPostCard extends StatelessWidget {
  final CommunityPost post;
  final bool isProcessing;
  final VoidCallback onDismiss;
  final VoidCallback onArchive;

  const _ReportedPostCard({
    required this.post,
    required this.isProcessing,
    required this.onDismiss,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.teal50,
                  child: Text(
                    post.username.isNotEmpty
                        ? post.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.username,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _formatTime(post.timePosted),
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.flag, size: 14, color: AppTheme.error),
                  label: const Text('Reported',
                      style: TextStyle(fontSize: 11, color: AppTheme.error)),
                  backgroundColor: AppTheme.error.withValues(alpha: 0.12),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (post.caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(post.caption, style: const TextStyle(fontSize: 14)),
            ],
            if (post.imageBase64.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildImageConditional(post.imageBase64),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isProcessing ? null : onDismiss,
                  icon: const Icon(Icons.check_circle, color: AppTheme.success),
                  label: const Text('Dismiss',
                      style: TextStyle(color: AppTheme.success)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isProcessing ? null : onArchive,
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Archive'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildImageConditional(String imageBase64) {
    final bytes = _tryDecodeBase64(imageBase64);
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 48),
      ),
    );
  }

  String _formatTime(int millis) {
    if (millis <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
