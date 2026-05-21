import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_viewmodel.dart';
import 'fish_form_dialog.dart';

class FishManagementView extends StatelessWidget {
  const FishManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search fish...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: vm.setSearchQuery,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: vm.habitatFilter,
                  decoration: const InputDecoration(
                    labelText: 'Habitat',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['All', 'Freshwater', 'Marine', 'Brackish']
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) vm.setHabitatFilter(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: vm.sortMode,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['Name (A-Z)', 'Name (Z-A)', 'Scientific Name']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) vm.setSortMode(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Archived'),
                  Switch(
                    value: vm.showArchivedFish,
                    onChanged: (_) => vm.toggleShowArchived(),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openAddDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Fish'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: vm.fishProcessing && vm.filteredFish.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : vm.filteredFish.isEmpty
                  ? const Center(child: Text('No fish found'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('Common Name')),
                          DataColumn(label: Text('Scientific Name')),
                          DataColumn(label: Text('Habitat')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: vm.filteredFish.map((fish) {
                          final isArchived = vm.showArchivedFish;
                          return DataRow(cells: [
                            DataCell(Text(fish.commonName)),
                            DataCell(Text(fish.scientificName)),
                            DataCell(Text(fish.habitat)),
                            DataCell(Text(fish.conservationStatus)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  tooltip: 'Edit',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) =>
                                        FishFormDialog(fish: fish),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isArchived
                                        ? Icons.restore
                                        : Icons.archive,
                                    color: Colors.orange,
                                  ),
                                  tooltip:
                                      isArchived ? 'Restore' : 'Archive',
                                  onPressed: () {
                                    if (isArchived) {
                                      vm.restoreFish(fish.id).catchError(
                                          (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content:
                                                    Text(e.toString())),
                                          );
                                        }
                                      });
                                    } else {
                                      vm.archiveFish(fish.id).catchError(
                                          (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content:
                                                    Text(e.toString())),
                                          );
                                        }
                                      });
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.red),
                                  tooltip: 'Permanently delete',
                                  onPressed: () => _confirmHardDelete(
                                      context, fish.id, isArchived),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }

  void _openAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const FishFormDialog(),
    );
  }

  void _confirmHardDelete(
      BuildContext context, String id, bool fromArchive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete Fish'),
        content: const Text(
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<AdminViewModel>()
                  .hardDeleteFish(id, fromArchive: fromArchive)
                  .catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            },
            child: const Text('Delete Forever',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
