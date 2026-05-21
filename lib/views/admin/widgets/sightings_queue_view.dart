import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_viewmodel.dart';
import '../../../models/sighting.dart';

class SightingsQueueView extends StatelessWidget {
  const SightingsQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();

    if (vm.sightingsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.sightings.isEmpty) {
      return const Center(
        child: Text('No pending sightings', style: TextStyle(fontSize: 16)),
      );
    }

    final knownFishIds = vm.fishCatalog.map((f) => f.id).toSet();
    final allSelected =
        vm.sightings.every((s) => vm.selectedIds.contains(s.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (_) =>
                    allSelected ? vm.clearSelection() : vm.selectAll(),
              ),
              const Text('Select All'),
              const Spacer(),
              TextButton.icon(
                onPressed: vm.selectedIds.isNotEmpty && !vm.isProcessing
                    ? vm.approveSelected
                    : null,
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text('Approve Selected'),
              ),
              TextButton.icon(
                onPressed: vm.selectedIds.isNotEmpty && !vm.isProcessing
                    ? vm.archiveSelected
                    : null,
                icon: const Icon(Icons.archive, color: Colors.orange),
                label: const Text('Archive Selected'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: vm.sightings.length,
            itemBuilder: (context, index) {
              final sighting = vm.sightings[index];
              final errors =
                  vm.approvalValidationErrors(sighting, knownFishIds);
              return _SightingCard(
                sighting: sighting,
                errors: errors,
                isSelected: vm.selectedIds.contains(sighting.id),
                onToggleSelect: () => vm.toggleSelected(sighting.id),
                onApprove: errors.isEmpty
                    ? () => vm.approveSighting(sighting.id)
                    : null,
                onArchive: () => vm.archiveSighting(sighting.id),
                onDelete: () => _confirmDelete(context, sighting.id),
                isProcessing: vm.isProcessing,
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sighting'),
        content: const Text(
          'Are you sure you want to permanently delete this sighting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminViewModel>().deleteSighting(id).catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SightingCard extends StatelessWidget {
  final Sighting sighting;
  final List<String> errors;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback? onApprove;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool isProcessing;

  const _SightingCard({
    required this.sighting,
    required this.errors,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onApprove,
    required this.onArchive,
    required this.onDelete,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelect(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        sighting.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (sighting.isAnonymous)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.visibility_off,
                              size: 14, color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _infoRow(Icons.eco, 'Fish: ${sighting.fishName}'),
                  _infoRow(Icons.location_on,
                      '${sighting.latitude.toStringAsFixed(4)}, ${sighting.longitude.toStringAsFixed(4)}'),
                  _infoRow(Icons.calendar_today, sighting.createdAt),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _StatusChip(status: sighting.status.name),
                      if (errors.isNotEmpty)
                        Tooltip(
                          message: errors.join('\n'),
                          child: Chip(
                            avatar: const Icon(Icons.warning,
                                size: 14, color: Colors.orange),
                            label: Text(
                              '${errors.length} error${errors.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.orange),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Approve',
                  onPressed: isProcessing ? null : onApprove,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.orange),
                  tooltip: 'Reject',
                  onPressed: isProcessing ? null : onArchive,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: isProcessing ? null : onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'pending' => (Colors.orange[100]!, Colors.orange[900]!),
      'approved' => (Colors.green[100]!, Colors.green[900]!),
      'rejected' => (Colors.red[100]!, Colors.red[900]!),
      _ => (Colors.grey[100]!, Colors.grey[900]!),
    };
    return Chip(
      label: Text(status,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
