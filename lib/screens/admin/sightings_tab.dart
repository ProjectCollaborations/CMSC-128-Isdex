import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../data/models/sighting.dart';

class SightingsTab extends StatefulWidget {
  const SightingsTab({super.key});

  @override
  State<SightingsTab> createState() => _SightingsTabState();
}

class _SightingsTabState extends State<SightingsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  static const List<String> _tabLabels = ['Pending', 'Verified', 'Rejected', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      context.read<AdminViewModel>().setSightingsTab(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              Text(
                'Sightings Management',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('${vm.selectedSightingIds.length} selected   '),
              ElevatedButton.icon(
                onPressed: vm.selectedSightingIds.isEmpty || vm.isProcessing
                    ? null
                    : () => _showConfirmDialog(
                        title: 'Disapprove Sightings',
                        message: 'Mark ${vm.selectedSightingIds.length} sighting(s) as rejected?',
                        onConfirm: () => vm.rejectSelectedSightings(),
                      ),
                icon: const Icon(Icons.archive),
                label: const Text('Disapprove Selected'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: vm.selectedSightingIds.isEmpty || vm.isProcessing
                    ? null
                    : () => _showConfirmDialog(
                        title: 'Approve Sightings',
                        message: 'Approve ${vm.selectedSightingIds.length} sighting(s)?',
                        onConfirm: () => vm.approveSelectedSightings(),
                      ),
                icon: const Icon(Icons.check_circle),
                label: const Text('Approve Selected'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Tab bar with counts
        Container(
          color: Colors.blue[50],
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue[900],
            unselectedLabelColor: Colors.blueGrey[600],
            indicatorColor: Colors.blue,
            tabs: [
              _buildTabWithCount('Pending', vm.pendingCount),
              _buildTabWithCount('Verified', vm.verifiedCount),
              _buildTabWithCount('Rejected', vm.rejectedCount),
              _buildTabWithCount('All', vm.allSightings.length),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.filteredSightings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No sightings in this category.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: vm.filteredSightings.length,
                      itemBuilder: (context, index) {
                        final sighting = vm.filteredSightings[index];
                        final isSelected = vm.selectedSightingIds.contains(sighting.id);
                        
                        return _SightingCard(
                          sighting: sighting,
                          isSelected: isSelected,
                          onSelect: (selected) {
                            if (selected) {
                              vm.toggleSelectSighting(sighting.id);
                            } else {
                              vm.toggleSelectSighting(sighting.id);
                            }
                          },
                          onVerify: () => _showConfirmDialog(
                            title: 'Verify Sighting',
                            message: 'Approve sighting of "${sighting.fishName}"?',
                            onConfirm: () => _bulkUpdateWithOne([sighting.id], SightingStatus.verified),
                          ),
                          onReject: () => _showConfirmDialog(
                            title: 'Reject Sighting',
                            message: 'Reject sighting of "${sighting.fishName}"?',
                            onConfirm: () => _bulkUpdateWithOne([sighting.id], SightingStatus.rejected),
                          ),
                          onDelete: () => _showConfirmDialog(
                            title: 'Delete Sighting',
                            message: 'Permanently delete sighting of "${sighting.fishName}"?\nThis cannot be undone.',
                            isDestructive: true,
                            onConfirm: () => vm.deleteSighting(sighting.id),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
  
  Widget _buildTabWithCount(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: label == 'Pending' ? Colors.orange : Colors.blueGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _bulkUpdateWithOne(List<String> ids, SightingStatus status) async {
    final vm = context.read<AdminViewModel>();
    // Temporarily select just this one
    final previousSelection = Set<String>.from(vm.selectedSightingIds);
    vm.clearSelectedSightings();
    for (final id in ids) {
      vm.toggleSelectSighting(id);
    }
    if (status == SightingStatus.verified) {
      await vm.approveSelectedSightings();
    } else {
      await vm.rejectSelectedSightings();
    }
    // Restore previous selection (clear to avoid confusion)
    vm.clearSelectedSightings();
    for (final id in previousSelection) {
      vm.toggleSelectSighting(id);
    }
  }
  
  Future<void> _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isDestructive ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      onConfirm();
      // Show result if error occurred
      await Future.delayed(const Duration(milliseconds: 100));
      final vm = context.read<AdminViewModel>();
      if (vm.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error!), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
        vm.clearError();
      }
    }
  }
}

class _SightingCard extends StatelessWidget {
  final Sighting sighting;
  final bool isSelected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  final VoidCallback onDelete;
  
  const _SightingCard({
    required this.sighting,
    required this.isSelected,
    required this.onSelect,
    required this.onVerify,
    required this.onReject,
    required this.onDelete,
  });
  
  Color get _statusColor {
    switch (sighting.status) {
      case SightingStatus.verified:
        return Colors.green;
      case SightingStatus.rejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy · h:mm a');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection checkbox + header
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelect(value ?? false),
                ),
                Expanded(
                  child: Text(
                    sighting.fishName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: sighting.status, color: _statusColor),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Submitter info
            Row(
              children: [
                Icon(
                  sighting.isAnonymous ? Icons.visibility_off : Icons.person_outline,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  sighting.isAnonymous ? 'Anonymous' : sighting.displayName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const Spacer(),
                Text(
                  df.format(sighting.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Coordinates
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${sighting.latitude.toStringAsFixed(5)}, ${sighting.longitude.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            
            // Notes
            if (sighting.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${sighting.notes}"',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sighting.status != SightingStatus.verified)
                  _ActionChip(
                    label: 'Verify',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    onTap: onVerify,
                  ),
                if (sighting.status != SightingStatus.rejected)
                  _ActionChip(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: Colors.orange,
                    onTap: onReject,
                  ),
                if (sighting.status != SightingStatus.pending)
                  _ActionChip(
                    label: 'Reset to Pending',
                    icon: Icons.refresh,
                    color: Colors.blueGrey,
                    onTap: () => _showResetDialog(context),
                  ),
                _ActionChip(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Pending'),
        content: const Text('Move this sighting back to pending status for re-review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // This would need to call a reset method
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset functionality - implement via ViewModel')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SightingStatus status;
  final Color color;
  
  const _StatusChip({required this.status, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.07),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}