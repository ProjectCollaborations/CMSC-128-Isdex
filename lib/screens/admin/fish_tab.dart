import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../data/models/fish.dart';

class FishTab extends StatefulWidget {
  const FishTab({super.key});

  @override
  State<FishTab> createState() => _FishTabState();
}

class _FishTabState extends State<FishTab> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }
  
  void _onSearchChanged() {
    context.read<AdminViewModel>().setFishSearchQuery(_searchController.text);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _showAddFishDialog() async {
    final vm = context.read<AdminViewModel>();
    final autoFishId = vm.getNextFishId();
    
    final fishIdController = TextEditingController(text: autoFishId);
    final commonNameController = TextEditingController();
    final scientificNameController = TextEditingController();
    final localNameController = TextEditingController();
    final habitatController = TextEditingController();
    final sizeRangeController = TextEditingController();
    final imageUrlController = TextEditingController();
    final identifyingFeaturesController = TextEditingController();
    final conservationStatusController = TextEditingController(text: 'Not Evaluated (NE)');
    final conservationDetailsController = TextEditingController();
    final distributionController = TextEditingController();
    
    final formKey = GlobalKey<FormState>();
    
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Fish Data'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormField('Fish ID (Firebase key)', fishIdController, readOnly: true),
                  const SizedBox(height: 12),
                  _buildFormField('Common Name *', commonNameController, required: true),
                  const SizedBox(height: 12),
                  _buildFormField('Scientific Name *', scientificNameController, required: true),
                  const SizedBox(height: 12),
                  _buildFormField('Local Name', localNameController),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Habitat & Size'),
                  const SizedBox(height: 8),
                  _buildFormField('Habitat', habitatController),
                  const SizedBox(height: 12),
                  _buildFormField('Size Range', sizeRangeController),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Media & Features'),
                  const SizedBox(height: 8),
                  _buildFormField('Image Asset Path', imageUrlController),
                  const SizedBox(height: 12),
                  _buildFormField('Identifying Features (comma-separated)', identifyingFeaturesController, maxLines: 2),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Conservation'),
                  const SizedBox(height: 8),
                  _buildFormField('Conservation Status', conservationStatusController),
                  const SizedBox(height: 12),
                  _buildFormField('Conservation Details', conservationDetailsController, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildFormField('Distribution', distributionController, maxLines: 2),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (shouldSave != true) {
      _disposeControllers([
        fishIdController, commonNameController, scientificNameController,
        localNameController, habitatController, sizeRangeController,
        imageUrlController, identifyingFeaturesController,
        conservationStatusController, conservationDetailsController, distributionController,
      ]);
      return;
    }
    
    final features = identifyingFeaturesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    final fish = Fish(
      key: fishIdController.text.trim(),
      fishId: fishIdController.text.trim(),
      commonName: commonNameController.text.trim(),
      scientificName: scientificNameController.text.trim(),
      localName: localNameController.text.trim(),
      habitat: habitatController.text.trim(),
      sizeRange: sizeRangeController.text.trim(),
      imageUrl: imageUrlController.text.trim(),
      identifyingFeatures: features,
      conservationStatus: conservationStatusController.text.trim(),
      conservationDetails: conservationDetailsController.text.trim(),
      distribution: distributionController.text.trim(),
    );
    
    final result = await vm.addFish(fish);
    
    _disposeControllers([
      fishIdController, commonNameController, scientificNameController,
      localNameController, habitatController, sizeRangeController,
      imageUrlController, identifyingFeaturesController,
      conservationStatusController, conservationDetailsController, distributionController,
    ]);
    
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fish data added.'), backgroundColor: Colors.green),
      );
    } else if (mounted && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: Colors.red),
      );
      vm.clearError();
    }
  }
  
  void _disposeControllers(List<TextEditingController> controllers) {
    for (final c in controllers) {
      c.dispose();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final visibleFish = vm.getFilteredFishList();
    final totalCount = vm.showArchivedFish ? vm.archivedFish.length : vm.fishCatalog.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.showArchivedFish ? 'Archived Fish Records: $totalCount' : 'Total Fish Records: $totalCount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Active'),
                    selected: !vm.showArchivedFish,
                    onSelected: (selected) {
                      if (selected) vm.setShowArchivedFish(false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Archived'),
                    selected: vm.showArchivedFish,
                    onSelected: (selected) {
                      if (selected) vm.setShowArchivedFish(true);
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or fish ID...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.blue[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[100]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: vm.fishHabitatFilter,
                      items: vm.habitats.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                      onChanged: (value) {
                        if (value != null) vm.setFishHabitatFilter(value);
                      },
                      decoration: InputDecoration(
                        labelText: 'Habitat',
                        filled: true,
                        fillColor: Colors.blue[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[100]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: vm.fishSortMode,
                      items: vm.sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (value) {
                        if (value != null) vm.setFishSortMode(value);
                      },
                      decoration: InputDecoration(
                        labelText: 'Sort by',
                        filled: true,
                        fillColor: Colors.blue[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[100]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!vm.showArchivedFish)
                    ElevatedButton.icon(
                      onPressed: _showAddFishDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Fish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // Fish list table
        Expanded(
          child: visibleFish.isEmpty
              ? const Center(
                  child: Text('No fish records found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                      columnSpacing: 24,
                      horizontalMargin: 12,
                      dividerThickness: 0.8,
                      columns: [
                        const DataColumn(label: Text('Fish ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Common Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Scientific Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Habitat', style: TextStyle(fontWeight: FontWeight.bold))),
                        if (vm.showArchivedFish)
                          const DataColumn(label: Text('Archived At', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: visibleFish.map((fish) {
                        return DataRow(
                          cells: [
                            DataCell(Text(fish.fishId, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(fish.commonName)),
                            DataCell(SizedBox(
                              width: 220,
                              child: Text(fish.scientificName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic)),
                            )),
                            DataCell(Text(fish.habitat)),
                            if (vm.showArchivedFish)
                              DataCell(Text(vm.formatArchiveDate(
                                vm.archivedFish.firstWhere(
                                  (f) => f['key'] == fish.key,
                                  orElse: () => {},
                                )['archivedAt'],
                              ))),
                            DataCell(
                              Row(
                                children: vm.showArchivedFish
                                    ? [
                                        IconButton(
                                          tooltip: 'Restore fish',
                                          onPressed: () => _confirmRestore(context, fish.key, fish.commonName),
                                          icon: const Icon(Icons.restore, color: Colors.green),
                                        ),
                                        IconButton(
                                          tooltip: 'Hard delete',
                                          onPressed: () => _confirmHardDelete(context, fish.key, fish.commonName, isArchived: true),
                                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                                        ),
                                      ]
                                    : [
                                        IconButton(
                                          tooltip: 'Edit fish',
                                          onPressed: () => _editFish(context, fish),
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                        ),
                                        IconButton(
                                          tooltip: 'Archive fish',
                                          onPressed: () => _confirmArchive(context, fish.key, fish.commonName),
                                          icon: const Icon(Icons.archive, color: Colors.orange),
                                        ),
                                        IconButton(
                                          tooltip: 'Hard delete',
                                          onPressed: () => _confirmHardDelete(context, fish.key, fish.commonName),
                                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildFormField(String label, TextEditingController controller, {
    bool readOnly = false,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black87, fontSize: 15),
            children: required ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : const [],
          ),
        ),
        filled: true,
        fillColor: Colors.blue[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue[100]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue[100]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue[400]!)),
      ),
      validator: required
          ? (value) => (value == null || value.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900]));
  }
  
  Future<void> _editFish(BuildContext context, Fish fish) async {
    // This would open an edit dialog similar to add but with pre-filled values
    // For brevity, showing snackbar; full implementation would be similar to _showAddFishDialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality - implement full form pre-fill')),
    );
  }
  
  Future<void> _confirmArchive(BuildContext context, String key, String name) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Archive Fish',
      message: 'Archive "$name"? You can restore it later.',
      confirmLabel: 'Archive',
      confirmColor: Colors.orange,
    );
    
    if (confirmed) {
      final vm = context.read<AdminViewModel>();
      final success = await vm.archiveFish(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Fish archived.' : vm.error ?? 'Archive failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (!success) vm.clearError();
      }
    }
  }
  
  Future<void> _confirmRestore(BuildContext context, String key, String name) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Restore Fish',
      message: 'Restore "$name" back to active records?',
      confirmLabel: 'Restore',
      confirmColor: Colors.green,
    );
    
    if (confirmed) {
      final vm = context.read<AdminViewModel>();
      final success = await vm.restoreFish(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Fish restored.' : vm.error ?? 'Restore failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (!success) vm.clearError();
      }
    }
  }
  
  Future<void> _confirmHardDelete(BuildContext context, String key, String name, {bool isArchived = false}) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Hard Delete Fish',
      message: 'Permanently delete "${isArchived ? 'archived ' : ''}$name"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
      requireTextConfirmation: true,
    );
    
    if (confirmed) {
      final vm = context.read<AdminViewModel>();
      final success = await vm.deleteFish(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Fish deleted.' : vm.error ?? 'Delete failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (!success) vm.clearError();
      }
    }
  }
  
  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    bool requireTextConfirmation = false,
  }) async {
    final controller = TextEditingController();
    bool showError = false;
    
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (requireTextConfirmation) ...[
                const SizedBox(height: 12),
                const Text('Type DELETE to confirm.', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: const OutlineInputBorder(),
                    errorText: showError ? 'Please type DELETE to confirm.' : null,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
              onPressed: () {
                if (requireTextConfirmation) {
                  final ok = controller.text.trim().toUpperCase() == 'DELETE';
                  if (!ok) {
                    setState(() => showError = true);
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ) ?? false;
  }
}