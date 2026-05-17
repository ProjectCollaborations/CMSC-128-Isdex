// lib/screens/admin_dashboard_page.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late final AuthService _authService = AuthService(_db);
  
  // State variables
  String _currentUserRole = 'mod'; // Default fallback
  int _currentTabIndex = 0; // 0 = Sightings, 1 = Reports, 2 = Data, 3 = Users
  bool _isLoading = true;
  bool _isProcessing = false;
  final TextEditingController _fishSearchController = TextEditingController();
  String _fishSearchQuery = '';
  String _fishHabitatFilter = 'All';
  String _fishSortMode = 'Name (A-Z)';

  // Data lists
  List<Map<String, dynamic>> _pendingSightings = [];
  List<Map<String, dynamic>> _reportedPosts = [];
  List<Map<String, dynamic>> _fishCatalog = [];
  List<Map<String, dynamic>> _archivedFish = [];
  List<Map<String, dynamic>> _usersList = [];
  final Set<String> _selectedIds = {};
  bool _showArchivedFish = false;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _fishSearchController.dispose();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    final user = _authService.currentUser;
    if (user != null) {
      final role = await _authService.getUserRole(user.uid);
      if (mounted) {
        setState(() => _currentUserRole = role ?? 'mod');
      }
      
      // Admin only data
      if (_currentUserRole == 'admin') {
        _listenToUsers();
      }
    }
    
    // Data needed by both Admins and Mods
    _listenToPendingSightings();
    _listenToReportedPosts();
    _listenToFishCatalog();
    _listenToFishArchive();
  }

  // ==========================================
  // FISH CATALOG MANAGEMENT LOGIC
  // ==========================================
  void _listenToFishCatalog() {
    _db.child('fish').onValue.listen((event) {
      final List<Map<String, dynamic>> fish = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final m = Map<dynamic, dynamic>.from(value);
          fish.add({
            'key': key.toString(),
            'fishId': m['fishId']?.toString() ?? key.toString(),
            'commonName': m['commonName']?.toString() ?? 'Unknown',
            'scientificName': m['scientificName']?.toString() ?? 'N/A',
            'localName': m['localName']?.toString() ?? 'N/A',
            'habitat': m['habitat']?.toString() ?? 'Unknown',
          });
        });

        fish.sort(
          (a, b) => a['commonName'].toString().toLowerCase().compareTo(
                b['commonName'].toString().toLowerCase(),
              ),
        );
      }

      if (mounted) {
        setState(() {
          _fishCatalog = fish;
          _isLoading = false;
        });
      }
    });
  }

  void _listenToFishArchive() {
    _db.child('fish_archive').onValue.listen((event) {
      final List<Map<String, dynamic>> fish = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final m = Map<dynamic, dynamic>.from(value);
          fish.add({
            'key': key.toString(),
            'fishId': m['fishId']?.toString() ?? key.toString(),
            'commonName': m['commonName']?.toString() ?? 'Unknown',
            'scientificName': m['scientificName']?.toString() ?? 'N/A',
            'localName': m['localName']?.toString() ?? 'N/A',
            'habitat': m['habitat']?.toString() ?? 'Unknown',
            'archivedAt': m['archivedAt'],
            'archivedBy': m['archivedBy']?.toString() ?? '',
          });
        });

        fish.sort(
          (a, b) => a['commonName'].toString().toLowerCase().compareTo(
                b['commonName'].toString().toLowerCase(),
              ),
        );
      }

      if (mounted) {
        setState(() {
          _archivedFish = fish;
        });
      }
    });
  }

  bool _isInvalidFirebaseKey(String value) {
    return value.contains('.') ||
        value.contains('#') ||
        value.contains(r'$') ||
        value.contains('[') ||
        value.contains(']') ||
        value.contains('/');
  }

  int _maxFishNumberFromId(String value) {
    final match = RegExp(r'^fish_(\d+)$').firstMatch(value.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  String _nextFishId() {
    final Set<int> used = {};
    for (final fish in _fishCatalog) {
      final fishId = fish['fishId']?.toString() ?? '';
      final value = _maxFishNumberFromId(fishId);
      if (value > 0) used.add(value);
    }

    int next = 1;
    while (used.contains(next)) {
      next += 1;
    }
    return 'fish_$next';
  }

  InputDecoration _fieldDecoration(
    String label, {
    bool required = false,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          children: required
              ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
              : const [],
        ),
      ),
      hintText: hint,
      filled: true,
      fillColor: Colors.blue[50],
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue[700]) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[100]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[100]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[400]!, width: 1.2),
      ),
    );
  }

  Future<void> _showFishFormDialog({Map<String, dynamic>? existingFish}) async {
    final bool isEdit = existingFish != null;

    final String autoFishId = isEdit
        ? (existingFish?['fishId']?.toString() ?? '')
        : _nextFishId();

    final fishIdController = TextEditingController(text: autoFishId);
    final commonNameController = TextEditingController(text: existingFish?['commonName']?.toString() ?? '');
    final scientificNameController = TextEditingController(text: existingFish?['scientificName']?.toString() ?? '');
    final localNameController = TextEditingController(text: existingFish?['localName']?.toString() ?? '');
    final habitatController = TextEditingController(text: existingFish?['habitat']?.toString() ?? '');
    final sizeRangeController = TextEditingController(text: existingFish?['sizeRange']?.toString() ?? '');
    final imageUrlController = TextEditingController(text: existingFish?['imageUrl']?.toString() ?? '');
    final conservationStatusController = TextEditingController(
      text: existingFish?['conservationStatus']?.toString() ?? 'Not Evaluated (NE)',
    );
    final conservationDetailsController = TextEditingController(text: existingFish?['conservationDetails']?.toString() ?? '');
    final distributionController = TextEditingController(text: existingFish?['distribution']?.toString() ?? '');

    final dynamic existingFeaturesDynamic = existingFish?['identifyingFeatures'];
    final List<String> existingFeatures = existingFeaturesDynamic is List
        ? existingFeaturesDynamic.map((e) => e.toString()).toList()
        : [];
    final identifyingFeaturesController = TextEditingController(text: existingFeatures.join(', '));

    final formKey = GlobalKey<FormState>();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Edit Fish Data' : 'Add Fish Data'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Basic Info',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: fishIdController,
                    readOnly: true,
                    decoration: _fieldDecoration(
                      'Fish ID (Firebase key)',
                      hint: 'Auto-generated',
                      icon: Icons.tag,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commonNameController,
                    decoration: _fieldDecoration('Common Name', required: true, icon: Icons.badge),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Common name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: scientificNameController,
                    decoration: _fieldDecoration('Scientific Name', required: true, icon: Icons.science),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Scientific name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: localNameController,
                    decoration: _fieldDecoration('Local Name', icon: Icons.translate),
                  ),
                  const SizedBox(height: 16),

                  Text('Habitat & Size',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: habitatController,
                    decoration: _fieldDecoration('Habitat', icon: Icons.water),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sizeRangeController,
                    decoration: _fieldDecoration('Size Range', icon: Icons.straighten),
                  ),
                  const SizedBox(height: 16),

                  Text('Media & Features',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: _fieldDecoration('Image Asset Path', icon: Icons.image_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: identifyingFeaturesController,
                    decoration: _fieldDecoration(
                      'Identifying Features (comma-separated)',
                      icon: Icons.list_alt,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  Text('Conservation',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: conservationStatusController,
                    decoration: _fieldDecoration('Conservation Status', icon: Icons.shield_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: conservationDetailsController,
                    decoration: _fieldDecoration('Conservation Details', icon: Icons.description_outlined),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: distributionController,
                    decoration: _fieldDecoration('Distribution', icon: Icons.public),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      fishIdController.dispose();
      commonNameController.dispose();
      scientificNameController.dispose();
      localNameController.dispose();
      habitatController.dispose();
      sizeRangeController.dispose();
      imageUrlController.dispose();
      conservationStatusController.dispose();
      conservationDetailsController.dispose();
      distributionController.dispose();
      identifyingFeaturesController.dispose();
      return;
    }

    final String recordKey = isEdit
        ? existingFish!['key'].toString()
        : fishIdController.text.trim();

    final List<String> identifyingFeatures = identifyingFeaturesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final Map<String, dynamic> payload = {
      'fishId': fishIdController.text.trim(),
      'commonName': commonNameController.text.trim(),
      'scientificName': scientificNameController.text.trim(),
      'localName': localNameController.text.trim(),
      'habitat': habitatController.text.trim(),
      'sizeRange': sizeRangeController.text.trim(),
      'imageUrl': imageUrlController.text.trim(),
      'identifyingFeatures': identifyingFeatures,
      'conservationStatus': conservationStatusController.text.trim(),
      'conservationDetails': conservationDetailsController.text.trim(),
      'distribution': distributionController.text.trim(),
    };

    try {
      await _db.child('fish/$recordKey').update(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Fish data updated.' : 'Fish data added.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving fish data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      fishIdController.dispose();
      commonNameController.dispose();
      scientificNameController.dispose();
      localNameController.dispose();
      habitatController.dispose();
      sizeRangeController.dispose();
      imageUrlController.dispose();
      conservationStatusController.dispose();
      conservationDetailsController.dispose();
      distributionController.dispose();
      identifyingFeaturesController.dispose();
    }
  }

  Future<void> _openEditFishDialog(Map<String, dynamic> fishSummary) async {
    try {
      final String key = fishSummary['key'].toString();
      final snap = await _db.child('fish/$key').get();
      if (!snap.exists || snap.value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fish record not found.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final full = Map<dynamic, dynamic>.from(snap.value as Map<dynamic, dynamic>);
      final existingFish = {
        'key': key,
        ...full.map((k, v) => MapEntry(k.toString(), v)),
      };

      await _showFishFormDialog(existingFish: existingFish);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fish data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _isFishReferenced(String fishId, String fishKey) async {
    final sightingsSnap = await _db.child('user_sightings_temp').get();
    if (sightingsSnap.exists && sightingsSnap.value != null) {
      final sightings = sightingsSnap.value as Map<dynamic, dynamic>;
      for (final value in sightings.values) {
        final m = Map<dynamic, dynamic>.from(value);
        final linkedFishId = m['fishId']?.toString() ?? '';
        if (linkedFishId == fishId || linkedFishId == fishKey) return true;
      }
    }

    final mapSnap = await _db.child('map').get();
    if (mapSnap.exists && mapSnap.value != null) {
      final mapEntries = mapSnap.value as Map<dynamic, dynamic>;
      for (final value in mapEntries.values) {
        final m = Map<dynamic, dynamic>.from(value);
        final linkedFishId = m['fishId']?.toString() ?? '';
        if (linkedFishId == fishId || linkedFishId == fishKey) return true;
      }
    }

    return false;
  }


  Future<void> _archiveFish(Map<String, dynamic> fish) async {
    final fishKey = fish['key'].toString();
    final fishId = fish['fishId'].toString();
    final fishName = fish['commonName'].toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Fish Data'),
        content: Text('Archive "$fishName" ($fishId)? You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bool inUse = await _isFishReferenced(fishId, fishKey);
      if (inUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot archive: this fish is referenced by map pins or sightings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final snap = await _db.child('fish/$fishKey').get();
      if (!snap.exists || snap.value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fish record not found.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final Map<dynamic, dynamic> full = Map<dynamic, dynamic>.from(snap.value as Map<dynamic, dynamic>);
      full['archivedAt'] = DateTime.now().millisecondsSinceEpoch;
      full['archivedBy'] = _authService.currentUser?.uid ?? '';

      await _db.child('fish_archive/$fishKey').set(full);
      await _db.child('fish/$fishKey').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fish data archived.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error archiving fish data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _hardDeleteActiveFish(Map<String, dynamic> fish) async {
    final fishKey = fish['key'].toString();
    final fishId = fish['fishId'].toString();
    final fishName = fish['commonName'].toString();

    final confirmController = TextEditingController();
    bool showError = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hard Delete Fish Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permanently delete "$fishName" ($fishId)? This cannot be undone.'),
              const SizedBox(height: 12),
              const Text('Type DELETE to confirm.'),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Please type DELETE to confirm.' : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final ok = confirmController.text.trim().toUpperCase() == 'DELETE';
                if (!ok) {
                  setDialogState(() => showError = true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    confirmController.dispose();

    if (confirm != true) return;

    try {
      final bool inUse = await _isFishReferenced(fishId, fishKey);
      if (inUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot delete: this fish is referenced by map pins or sightings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _db.child('fish/$fishKey').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fish data deleted.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting fish data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreFish(Map<String, dynamic> fish) async {
    final fishKey = fish['key'].toString();
    final fishId = fish['fishId'].toString();
    final fishName = fish['commonName'].toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Fish Data'),
        content: Text('Restore "$fishName" ($fishId) back to active records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final keyConflict = _fishCatalog.any((f) => f['key'].toString() == fishKey);
      final idConflict = _fishCatalog.any((f) => f['fishId'].toString() == fishId);
      if (keyConflict || idConflict) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot restore: fish key or ID already exists in active records.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final snap = await _db.child('fish_archive/$fishKey').get();
      if (!snap.exists || snap.value == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archived fish record not found.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final Map<dynamic, dynamic> full = Map<dynamic, dynamic>.from(snap.value as Map<dynamic, dynamic>);
      full.remove('archivedAt');
      full.remove('archivedBy');

      await _db.child('fish/$fishKey').set(full);
      await _db.child('fish_archive/$fishKey').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fish data restored.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring fish data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _hardDeleteArchivedFish(Map<String, dynamic> fish) async {
    final fishKey = fish['key'].toString();
    final fishId = fish['fishId'].toString();
    final fishName = fish['commonName'].toString();

    final confirmController = TextEditingController();
    bool showError = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hard Delete Fish Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permanently delete archived "$fishName" ($fishId)? This cannot be undone.'),
              const SizedBox(height: 12),
              const Text('Type DELETE to confirm.'),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Please type DELETE to confirm.' : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final ok = confirmController.text.trim().toUpperCase() == 'DELETE';
                if (!ok) {
                  setDialogState(() => showError = true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    confirmController.dispose();

    if (confirm != true) return;

    try {
      await _db.child('fish_archive/$fishKey').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archived fish data deleted.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting archived fish data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatArchiveDate(dynamic raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw).toLocal().toString().split('.').first;
    }
    return 'N/A';
  }

  List<String> _buildHabitatOptions(List<Map<String, dynamic>> source) {
    final Set<String> habitats = {'All'};
    for (final fish in source) {
      final value = fish['habitat']?.toString().trim() ?? '';
      if (value.isNotEmpty) habitats.add(value);
    }
    final List<String> result = habitats.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (result.first != 'All') {
      result.remove('All');
      result.insert(0, 'All');
    }
    return result;
  }

  List<Map<String, dynamic>> _filterFishList(
    List<Map<String, dynamic>> source,
    String habitatFilter,
  ) {
    final query = _fishSearchQuery.trim().toLowerCase();
    final habitat = habitatFilter.toLowerCase();

    final List<Map<String, dynamic>> filtered = source.where((fish) {
      final fishId = fish['fishId']?.toString().toLowerCase() ?? '';
      final commonName = fish['commonName']?.toString().toLowerCase() ?? '';
      final scientificName = fish['scientificName']?.toString().toLowerCase() ?? '';
      final fishHabitat = fish['habitat']?.toString().toLowerCase() ?? '';

      final matchesQuery = query.isEmpty ||
          fishId.contains(query) ||
          commonName.contains(query) ||
          scientificName.contains(query);

      final matchesHabitat = habitat == 'all' || fishHabitat.contains(habitat);

      return matchesQuery && matchesHabitat;
    }).toList();

    if (_fishSortMode == 'Fish ID') {
      filtered.sort((a, b) {
        final aId = _maxFishNumberFromId(a['fishId']?.toString() ?? '');
        final bId = _maxFishNumberFromId(b['fishId']?.toString() ?? '');
        return aId.compareTo(bId);
      });
    } else {
      filtered.sort((a, b) {
        final aName = a['commonName']?.toString().toLowerCase() ?? '';
        final bName = b['commonName']?.toString().toLowerCase() ?? '';
        return aName.compareTo(bName);
      });
    }

    return filtered;
  }

  List<String> _coreSightingValidationErrors(Map<dynamic, dynamic> raw) {
    final errors = <String>[];
    final fishId = raw['fishId']?.toString().trim() ?? '';
    final fishName = raw['fishName']?.toString().trim() ?? '';
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();
    final geoStatus = (raw['geoValidationStatus'] ?? '').toString().toLowerCase();
    final geoMessage = (raw['geoValidationMessage'] ?? '').toString();

    if (fishId.isEmpty) errors.add('Missing fish ID');
    if (fishName.isEmpty) errors.add('Missing fish name');
    if (lat == null || lat < -90 || lat > 90) errors.add('Invalid latitude');
    if (lng == null || lng < -180 || lng > 180) errors.add('Invalid longitude');
    if (geoStatus.isEmpty) {
      errors.add('Location validation missing');
    } else if (geoStatus != 'water') {
      errors.add(
        geoMessage.isNotEmpty
            ? 'Location validation failed: $geoMessage'
            : 'Location is not confirmed as water',
      );
    }

    return errors;
  }

  List<String> _approvalValidationErrors(Map<String, dynamic> sighting, Set<String> knownFishIds) {
    final errors = <String>[];

    final fishId = sighting['fishId']?.toString() ?? '';
    final lat = (sighting['latitude'] as num?)?.toDouble();
    final lng = (sighting['longitude'] as num?)?.toDouble();
    final geoStatus = (sighting['geoValidationStatus'] ?? '').toString().toLowerCase();
    final geoMessage = (sighting['geoValidationMessage'] ?? '').toString();

    if (fishId.isEmpty) errors.add('Missing fish ID');
    if (fishId.isNotEmpty && !knownFishIds.contains(fishId)) {
      errors.add('Fish ID does not exist in catalog');
    }
    if (lat == null || lat < -90 || lat > 90) errors.add('Invalid latitude');
    if (lng == null || lng < -180 || lng > 180) errors.add('Invalid longitude');
    if (geoStatus != 'water') {
      errors.add(
        geoMessage.isNotEmpty
            ? 'Location validation failed: $geoMessage'
            : 'Location is not confirmed as water',
      );
    }

    return errors;
  }

  // ==========================================
  // PHASE 3 & 5: SIGHTINGS QUEUE LOGIC
  // ==========================================
  void _listenToPendingSightings() {
    _db.child('user_sightings_temp').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> pending = [];
        
        data.forEach((key, value) {
          final m = value as Map<dynamic, dynamic>;
          final validationErrors = _coreSightingValidationErrors(m);

          // FIX: Check for BOTH pending status OR reported flag
          if (m['status'] == 'pending' || m['isReported'] == true) {
            pending.add({
              'id': key.toString(),
              'fishId': m['fishId']?.toString() ?? '',
              'fishName': m['fishName']?.toString() ?? 'Unknown Fish',
              'displayName': m['displayName']?.toString() ?? 'Anonymous',
              'notes': m['notes']?.toString() ?? 'No notes provided.',
              'latitude': (m['latitude'] as num?)?.toDouble(),
              'longitude': (m['longitude'] as num?)?.toDouble(),
              'geoValidationStatus': m['geoValidationStatus']?.toString() ?? '',
              'geoValidationMessage': m['geoValidationMessage']?.toString() ?? '',
              'timestamp': m['createdAt'] ?? 0,
              'isReported': m['isReported'] == true, // Track report status
              'isCoreValid': validationErrors.isEmpty,
              'validationMessage': validationErrors.join(', '),
            });
          }
        });

        pending.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        if (mounted) {
          setState(() {
            _pendingSightings = pending;
            _selectedIds.retainWhere((id) => pending.any((item) => item['id'] == id));
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _pendingSightings = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _updateSelectedStatus(String newStatus) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final Map<String, dynamic> updates = {};
      int blockedCount = 0;
      final List<String> blockedReasons = [];

      final Set<String> knownFishIds = {
        ..._fishCatalog.map((f) => f['fishId'].toString()),
        ..._fishCatalog.map((f) => f['key'].toString()),
      };

      for (String id in _selectedIds) {
        final sighting = _pendingSightings.firstWhere(
          (item) => item['id'] == id,
          orElse: () => {},
        );

        if (sighting.isEmpty) continue;

        if (newStatus == 'approved') {
          final errors = _approvalValidationErrors(sighting, knownFishIds);
          if (errors.isNotEmpty) {
            blockedCount++;
            blockedReasons.add('${sighting['fishName']}: ${errors.join(', ')}');
            continue;
          }
        }

        updates['user_sightings_temp/$id/status'] = newStatus;
        
        // FIX: If moderator approves a reported pin, clear the report flag
        if (newStatus == 'approved') {
          updates['user_sightings_temp/$id/isReported'] = false;
        }
      }

      if (updates.isNotEmpty) {
        await _db.update(updates);
      }

      if (mounted) {
        final int updatedCount = updates.keys.where((k) => k.endsWith('/status')).length;
        final String baseMessage = updatedCount > 0
            ? '$updatedCount sightings marked as $newStatus.'
            : 'No sightings were updated.';

        final String blockedMessage = blockedCount > 0
            ? ' $blockedCount blocked by validation.'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$baseMessage$blockedMessage'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.grey[800],
          ),
        );

        if (blockedReasons.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Validation: ${blockedReasons.take(2).join(' | ')}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      setState(() => _selectedIds.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ==========================================
  // PHASE 5: REPORTED COMMUNITY POSTS LOGIC
  // ==========================================
  void _listenToReportedPosts() {
    _db.child('community_posts').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> reported = [];

        data.forEach((key, value) {
          final m = value as Map<dynamic, dynamic>;
          // Only show posts that are reported AND not already archived
          if (m['isReported'] == true && m['status'] != 'archived') {
            reported.add({
              'id': key.toString(),
              'username': m['username']?.toString() ?? 'Unknown',
              'caption': m['caption']?.toString() ?? 'No caption',
              'imageBase64': m['imageBase64']?.toString() ?? '',
              'timestamp': m['timePosted'] ?? 0,
            });
          }
        });

        reported.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        if (mounted) {
          setState(() => _reportedPosts = reported);
        }
      } else {
        if (mounted) setState(() => _reportedPosts = []);
      }
    });
  }

  Future<void> _handleReportedPost(String postId, String action) async {
    try {
      if (action == 'archive') {
        // Hide from feed, unflag as reported
        await _db.child('community_posts/$postId').update({'status': 'archived', 'isReported': false});
      } else if (action == 'dismiss') {
        // Keep on feed, just remove the reported flag
        await _db.child('community_posts/$postId').update({'isReported': false});
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'archive' ? 'Post archived and hidden.' : 'Report dismissed.'),
            backgroundColor: action == 'archive' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing post: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // PHASE 4: ADMIN USER MANAGEMENT LOGIC
  // ==========================================
  void _listenToUsers() {
    _db.child('users').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> users = [];
        
        data.forEach((key, value) {
          final m = value as Map<dynamic, dynamic>;
          users.add({
            'uid': key.toString(),
            'email': m['email']?.toString() ?? 'No Email',
            'username': m['username']?.toString() ?? 'Anonymous',
            'role': m['role']?.toString() ?? 'user',
          });
        });

        users.sort((a, b) => a['role'].compareTo(b['role']));

        if (mounted) {
          setState(() => _usersList = users);
        }
      }
    });
  }

  Future<void> _changeUserRole(String targetUid, String newRole) async {
    try {
      await _db.child('users/$targetUid/role').set(newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role successfully updated to $newRole!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================
  
  Widget _buildSightingsQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue[50],
          child: Row(
            children: [
              Text(
                'Pending Sightings: ${_pendingSightings.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('${_selectedIds.length} selected   '),
              ElevatedButton.icon(
                onPressed: _selectedIds.isEmpty || _isProcessing 
                    ? null 
                    : () => _updateSelectedStatus('archived'),
                icon: const Icon(Icons.archive),
                label: const Text('Disapprove Selected'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectedIds.isEmpty || _isProcessing 
                    ? null 
                    : () => _updateSelectedStatus('approved'),
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
        Expanded(
          child: _pendingSightings.isEmpty
            ? const Center(
                child: Text('Queue is empty! Great job.', style: TextStyle(fontSize: 18, color: Colors.grey)),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: DataTable(
                                showCheckboxColumn: true,
                                headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 68,
                                headingRowHeight: 56,
                                columnSpacing: 24,
                                horizontalMargin: 12,
                                dividerThickness: 0.8,
                                dataRowColor: MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.blue[50];
                                  }
                                  return null;
                                }),
                                columns: const [
                                  DataColumn(label: Text('Submitted By', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Fish Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Validation', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('User Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: List.generate(_pendingSightings.length, (index) {
                                  final sighting = _pendingSightings[index];
                                  final String id = sighting['id'];
                                  final bool shaded = index.isOdd;
                                  return DataRow(
                                    color: MaterialStateProperty.all(
                                      shaded ? Colors.grey[50] : Colors.white,
                                    ),
                                    selected: _selectedIds.contains(id),
                                    onSelectChanged: (bool? selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedIds.add(id);
                                        } else {
                                          _selectedIds.remove(id);
                                        }
                                      });
                                    },
                                    cells: [
                                      DataCell(Text(sighting['displayName'])),
                                      DataCell(
                                        Row(
                                          children: [
                                            Text(sighting['fishName']),
                                            if (sighting['isReported'] == true) ...[
                                              const SizedBox(width: 8),
                                              const Icon(Icons.flag, color: Colors.orange, size: 16),
                                            ]
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Tooltip(
                                          message: sighting['isCoreValid'] == true
                                              ? 'Core validation passed'
                                              : (sighting['validationMessage']?.toString().isNotEmpty == true
                                                  ? sighting['validationMessage'].toString()
                                                  : 'Invalid data'),
                                          child: Chip(
                                            label: Text(
                                              sighting['isCoreValid'] == true ? 'Valid' : 'Invalid',
                                              style: TextStyle(
                                                color: sighting['isCoreValid'] == true ? Colors.green[900] : Colors.red[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: sighting['isCoreValid'] == true
                                                ? Colors.green[100]
                                                : Colors.red[100],
                                            side: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 300,
                                          child: Text(sighting['notes'], overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildReportedPostsQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.orange[50],
          child: Text(
            'Reported Posts Awaiting Review: ${_reportedPosts.length}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[900]),
          ),
        ),
        Expanded(
          child: _reportedPosts.isEmpty
            ? const Center(
                child: Text('No reported posts! Community is behaving.', style: TextStyle(fontSize: 18, color: Colors.grey)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reportedPosts.length,
                itemBuilder: (context, index) {
                  final post = _reportedPosts[index];
                  Uint8List? imageBytes = post['imageBase64'].isNotEmpty 
                      ? base64Decode(post['imageBase64']) 
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
                          // Show the offensive image
                          if (imageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(imageBytes, width: 120, height: 120, fit: BoxFit.cover),
                            )
                          else
                            Container(width: 120, height: 120, color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                          
                          const SizedBox(width: 16),
                          
                          // Post Details & Actions
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Posted by: ${post['username']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text(post['caption'], maxLines: 3, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _handleReportedPost(post['id'], 'dismiss'),
                                      icon: const Icon(Icons.thumb_up_alt_outlined, color: Colors.green),
                                      label: const Text('Dismiss Report', style: TextStyle(color: Colors.green)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.green[300]!),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _handleReportedPost(post['id'], 'archive'),
                                      icon: const Icon(Icons.gavel),
                                      label: const Text('Archive Post'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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

  Widget _buildUserManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue[50],
          child: Text(
            'Total Registered Users: ${_usersList.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _usersList.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 68,
                                headingRowHeight: 56,
                                columnSpacing: 24,
                                horizontalMargin: 12,
                                dividerThickness: 0.8,
                                columns: const [
                                  DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Current Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Manage Access', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: List.generate(_usersList.length, (index) {
                                  final user = _usersList[index];
                                  final isCurrentUser = user['uid'] == _authService.currentUser?.uid;
                                  final bool shaded = index.isOdd;

                                  return DataRow(
                                    color: MaterialStateProperty.all(
                                      shaded ? Colors.grey[50] : Colors.white,
                                    ),
                                    cells: [
                                      DataCell(Text(user['username'])),
                                      DataCell(Text(user['email'])),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: user['role'] == 'admin'
                                                ? Colors.red[100]
                                                : (user['role'] == 'mod' ? Colors.orange[100] : Colors.grey[200]),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            user['role'].toString().toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: user['role'] == 'admin'
                                                  ? Colors.red[900]
                                                  : (user['role'] == 'mod' ? Colors.orange[900] : Colors.grey[800]),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        isCurrentUser
                                            ? const Text('Cannot edit own role', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                                            : DropdownButton<String>(
                                                value: user['role'],
                                                items: const [
                                                  DropdownMenuItem(value: 'user', child: Text('Standard User')),
                                                  DropdownMenuItem(value: 'mod', child: Text('Moderator')),
                                                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                                                ],
                                                onChanged: (newRole) {
                                                  if (newRole != null) {
                                                    _changeUserRole(user['uid'], newRole);
                                                  }
                                                },
                                              ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildFishManagement() {
    final List<Map<String, dynamic>> sourceFish =
        _showArchivedFish ? _archivedFish : _fishCatalog;
    final List<String> habitatOptions = _buildHabitatOptions(sourceFish);
    final List<String> sortOptions = const ['Name (A-Z)', 'Fish ID'];
    final String effectiveHabitat = habitatOptions.contains(_fishHabitatFilter)
        ? _fishHabitatFilter
        : 'All';
    final List<Map<String, dynamic>> visibleFish =
        _filterFishList(sourceFish, effectiveHabitat);
    final int totalCount = sourceFish.length;
    final bool isNarrow = MediaQuery.of(context).size.width < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _showArchivedFish
                    ? 'Archived Fish Records: $totalCount'
                    : 'Total Fish Records: $totalCount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Active'),
                      selected: !_showArchivedFish,
                      onSelected: (selected) {
                        if (selected) setState(() => _showArchivedFish = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Archived'),
                      selected: _showArchivedFish,
                      onSelected: (selected) {
                        if (selected) setState(() => _showArchivedFish = true);
                      },
                    ),
                    const Spacer(),
                    if (!_showArchivedFish)
                      ElevatedButton.icon(
                        onPressed: () => _showFishFormDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Fish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fishSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or fish ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _fishSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _fishSearchController.clear();
                              setState(() => _fishSearchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: Colors.blue[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[100]!),
                    ),
                  ),
                  onChanged: (value) => setState(() => _fishSearchQuery = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: effectiveHabitat,
                  items: habitatOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _fishHabitatFilter = value);
                    }
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _fishSortMode,
                  items: sortOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _fishSortMode = value);
                    }
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
              ] else ...[
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Active'),
                      selected: !_showArchivedFish,
                      onSelected: (selected) {
                        if (selected) setState(() => _showArchivedFish = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Archived'),
                      selected: _showArchivedFish,
                      onSelected: (selected) {
                        if (selected) setState(() => _showArchivedFish = true);
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _fishSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or fish ID...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _fishSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _fishSearchController.clear();
                                    setState(() => _fishSearchQuery = '');
                                  },
                                ),
                          filled: true,
                          fillColor: Colors.blue[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[100]!),
                          ),
                        ),
                        onChanged: (value) => setState(() => _fishSearchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: effectiveHabitat,
                        items: habitatOptions
                            .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _fishHabitatFilter = value);
                          }
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
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _fishSortMode,
                        items: sortOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _fishSortMode = value);
                          }
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
                    if (!_showArchivedFish)
                      ElevatedButton.icon(
                        onPressed: () => _showFishFormDialog(),
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
            ],
          ),
        ),
        Expanded(
          child: visibleFish.isEmpty
              ? const Center(
                  child: Text('No fish records found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                                  dataRowMinHeight: 56,
                                  dataRowMaxHeight: 68,
                                  headingRowHeight: 56,
                                  columnSpacing: 24,
                                  horizontalMargin: 12,
                                  dividerThickness: 0.8,
                                  dataRowColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return Colors.blue[50];
                                    }
                                    return null;
                                  }),
                                  columns: [
                                    const DataColumn(label: Text('Fish ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Common Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Scientific Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Habitat', style: TextStyle(fontWeight: FontWeight.bold))),
                                    if (_showArchivedFish)
                                      const DataColumn(label: Text('Archived At', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: List.generate(visibleFish.length, (index) {
                                    final fish = visibleFish[index];
                                    final bool shaded = index.isOdd;
                                    return DataRow(
                                      color: MaterialStateProperty.all(
                                        shaded ? Colors.grey[50] : Colors.white,
                                      ),
                                      cells: [
                                        DataCell(Text(fish['fishId'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text(fish['commonName'].toString())),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              fish['scientificName'].toString(),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(fish['habitat'].toString())),
                                        if (_showArchivedFish)
                                          DataCell(Text(_formatArchiveDate(fish['archivedAt']))),
                                        DataCell(
                                          Row(
                                            children: [
                                              if (!_showArchivedFish) ...[
                                                IconButton(
                                                  tooltip: 'Edit fish',
                                                  onPressed: () => _openEditFishDialog(fish),
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                ),
                                                IconButton(
                                                  tooltip: 'Archive fish',
                                                  onPressed: () => _archiveFish(fish),
                                                  icon: const Icon(Icons.archive, color: Colors.orange),
                                                ),
                                                IconButton(
                                                  tooltip: 'Hard delete',
                                                  onPressed: () => _hardDeleteActiveFish(fish),
                                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                                ),
                                              ] else ...[
                                                IconButton(
                                                  tooltip: 'Restore fish',
                                                  onPressed: () => _restoreFish(fish),
                                                  icon: const Icon(Icons.restore, color: Colors.green),
                                                ),
                                                IconButton(
                                                  tooltip: 'Hard delete',
                                                  onPressed: () => _hardDeleteArchivedFish(fish),
                                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Determine which view to render based on the selected tab
  Widget _buildBody() {
    if (_currentTabIndex == 0) return _buildSightingsQueue();
    if (_currentTabIndex == 1) return _buildReportedPostsQueue();
    if (_currentTabIndex == 2) return _buildFishManagement();
    if (_currentTabIndex == 3 && _currentUserRole == 'admin') return _buildUserManagement();
    return const Center(child: Text('Unauthorized access'));
  }

  // Dynamic tabs based on role
  List<BottomNavigationBarItem> get _navItems {
    List<BottomNavigationBarItem> items = [
      _navItem(Icons.map, 'Sightings'),
      _navItem(Icons.flag, 'Reports'),
      _navItem(Icons.storage, 'Data'),
    ];
    if (_currentUserRole == 'admin') {
      items.add(_navItem(Icons.people, 'Users'));
    }
    return items;
  }

  BottomNavigationBarItem _navItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: _NavLabelIcon(icon: icon, label: label, color: Colors.blueGrey[600]! ),
      activeIcon: _NavLabelIcon(icon: icon, label: label, color: Colors.blue[900]! ),
      label: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentSection = _currentTabIndex == 0
        ? 'Sightings Queue'
        : _currentTabIndex == 1
            ? 'Reported Posts'
            : _currentTabIndex == 2
                ? 'Fish Data'
                : 'User Management';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/isdex_logo.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Isdex',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  currentSection,
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _authService.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[100],
                foregroundColor: Colors.blue[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Colors.blue[900],
        unselectedItemColor: Colors.blueGrey[600],
        items: _navItems,
      ),
    );
  }
}

class _NavLabelIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _NavLabelIcon({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(height: 4),
        Icon(icon, color: color, size: 22),
      ],
    );
  }
}