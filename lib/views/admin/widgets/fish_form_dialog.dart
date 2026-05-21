import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/fish.dart';
import '../../../viewmodels/admin_viewmodel.dart';

class FishFormDialog extends StatefulWidget {
  final Fish? fish;

  const FishFormDialog({super.key, this.fish});

  @override
  State<FishFormDialog> createState() => _FishFormDialogState();
}

class _FishFormDialogState extends State<FishFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commonNameCtrl;
  late final TextEditingController _scientificNameCtrl;
  late final TextEditingController _localNameCtrl;
  late final TextEditingController _sizeRangeCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _conservationDetailsCtrl;
  late final TextEditingController _distributionCtrl;
  late final TextEditingController _featureCtrl;

  String _habitat = 'Freshwater';
  String _conservationStatus = 'Not Evaluated (NE)';
  List<String> _features = [];

  bool get _isEditing => widget.fish != null;

  static const _habitats = ['Freshwater', 'Marine', 'Brackish'];
  static const _statusOptions = [
    'Extinct (EX)',
    'Extinct in the Wild (EW)',
    'Critically Endangered (CR)',
    'Endangered (EN)',
    'Vulnerable (VU)',
    'Near Threatened (NT)',
    'Least Concern (LC)',
    'Data Deficient (DD)',
    'Not Evaluated (NE)',
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.fish;
    _commonNameCtrl = TextEditingController(text: f?.commonName ?? '');
    _scientificNameCtrl =
        TextEditingController(text: f?.scientificName ?? '');
    _localNameCtrl = TextEditingController(text: f?.localName ?? '');
    _sizeRangeCtrl = TextEditingController(text: f?.sizeRange ?? '');
    _imageUrlCtrl = TextEditingController(text: f?.imageUrl ?? '');
    _conservationDetailsCtrl =
        TextEditingController(text: f?.conservationDetails ?? '');
    _distributionCtrl =
        TextEditingController(text: f?.distribution ?? '');
    _featureCtrl = TextEditingController();

    if (f != null) {
      _habitat = f.habitat;
      _conservationStatus = f.conservationStatus;
      _features = List.from(f.identifyingFeatures);
    }
  }

  @override
  void dispose() {
    _commonNameCtrl.dispose();
    _scientificNameCtrl.dispose();
    _localNameCtrl.dispose();
    _sizeRangeCtrl.dispose();
    _imageUrlCtrl.dispose();
    _conservationDetailsCtrl.dispose();
    _distributionCtrl.dispose();
    _featureCtrl.dispose();
    super.dispose();
  }

  void _addFeature() {
    final text = _featureCtrl.text.trim();
    if (text.isNotEmpty && !_features.contains(text)) {
      setState(() => _features.add(text));
      _featureCtrl.clear();
    }
  }

  void _removeFeature(String feature) {
    setState(() => _features.remove(feature));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final vm = context.read<AdminViewModel>();
    final fish = Fish(
      id: widget.fish?.id ?? '',
      commonName: _commonNameCtrl.text.trim(),
      scientificName: _scientificNameCtrl.text.trim(),
      localName: _localNameCtrl.text.trim(),
      habitat: _habitat,
      sizeRange: _sizeRangeCtrl.text.trim(),
      identifyingFeatures: _features,
      imageUrl: _imageUrlCtrl.text.trim(),
      conservationStatus: _conservationStatus,
      conservationDetails: _conservationDetailsCtrl.text.trim(),
      distribution: _distributionCtrl.text.trim(),
    );

    if (_isEditing) {
      await vm.updateFish(fish);
    } else {
      await vm.addFish(fish);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_isEditing ? 'Edit Fish' : 'Add Fish'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _commonNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Common Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _scientificNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Scientific Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _localNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Local Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _habitat,
                  decoration: const InputDecoration(
                    labelText: 'Habitat *',
                    border: OutlineInputBorder(),
                  ),
                  items: _habitats
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _habitat = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sizeRangeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Size Range',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _conservationStatus,
                  decoration: const InputDecoration(
                    labelText: 'Conservation Status',
                    border: OutlineInputBorder(),
                  ),
                  items: _statusOptions
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _conservationStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _conservationDetailsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Conservation Details',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _distributionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Distribution',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('Identifying Features',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _featureCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a feature...',
                          border: const OutlineInputBorder(),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: _addFeature,
                          ),
                        ),
                        onSubmitted: (_) => _addFeature(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _features
                      .map((f) => Chip(
                            label: Text(f, style: const TextStyle(fontSize: 12)),
                            onDeleted: () => _removeFeature(f),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
