import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_viewmodel.dart';

class ReportedPostsView extends StatelessWidget {
  const ReportedPostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();

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
        return _ReportedPostCard(post: post);
      },
    );
  }
}

class _ReportedPostCard extends StatelessWidget {
  final dynamic post;

  const _ReportedPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<AdminViewModel>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
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
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.flag, size: 14, color: Colors.red),
                  label: const Text('Reported',
                      style: TextStyle(fontSize: 11, color: Colors.red)),
                  backgroundColor: Colors.red[50],
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(post.imageBase64),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: vm.isProcessing
                      ? null
                      : () => vm.dismissReport(post.id),
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  label: const Text('Dismiss',
                      style: TextStyle(color: Colors.green)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: vm.isProcessing
                      ? null
                      : () => _confirmArchive(context, post.id),
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Archive'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminViewModel>().archiveReportedPost(postId);
            },
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
