import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_viewmodel.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange[50],
          child: Text(
            'Reported Posts Awaiting Review: ${vm.reportedPosts.length}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[900]),
          ),
        ),
        Expanded(
          child: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.reportedPosts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_outlined, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No reported posts!', style: TextStyle(color: Colors.grey)),
                          Text('Community is behaving well.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: vm.reportedPosts.length,
                      itemBuilder: (context, index) {
                        final post = vm.reportedPosts[index];
                        Uint8List? imageBytes = post.imageBase64.isNotEmpty 
                            ? base64Decode(post.imageBase64) 
                            : null;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 4,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image preview
                                if (imageBytes != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(imageBytes, width: 120, height: 120, fit: BoxFit.cover),
                                  )
                                else
                                  Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported),
                                  ),
                                
                                const SizedBox(width: 16),
                                
                                // Post details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Posted by: ${post.username}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        post.caption,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _handleReport(context, post.id, 'dismiss'),
                                            icon: const Icon(Icons.thumb_up_alt_outlined, color: Colors.green),
                                            label: const Text('Dismiss Report', style: TextStyle(color: Colors.green)),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.green[300]!),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            onPressed: () => _handleReport(context, post.id, 'archive'),
                                            icon: const Icon(Icons.gavel),
                                            label: const Text('Archive Post'),
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
  
  Future<void> _handleReport(BuildContext context, String postId, String action) async {
    final vm = context.read<AdminViewModel>();
    
    if (action == 'archive') {
      await vm.archiveReportedPost(postId);
    } else {
      await vm.dismissReport(postId);
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'archive' ? 'Post archived and hidden.' : 'Report dismissed.'),
          backgroundColor: action == 'archive' ? Colors.red : Colors.green,
        ),
      );
    }
  }
}