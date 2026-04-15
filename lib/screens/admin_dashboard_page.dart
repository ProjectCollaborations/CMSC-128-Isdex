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
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final AuthService _authService = AuthService();
  
  // State variables
  String _currentUserRole = 'mod'; // Default fallback
  int _currentTabIndex = 0; // 0 = Sightings, 1 = Reports, 2 = Data, 3 = Users
  bool _isLoading = true;
  bool _isProcessing = false;

  // Data lists
  List<Map<String, dynamic>> _pendingSightings = [];
  List<Map<String, dynamic>> _reportedPosts = [];
  List<Map<String, dynamic>> _fishCatalog = [];
  List<Map<String, dynamic>> _usersList = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
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

  bool _isInvalidFirebaseKey(String value) {
    return value.contains('.') ||
        value.contains('#') ||
        value.contains(r'$') ||
        value.contains('[') ||
        value.contains(']') ||
        value.contains('/');
  }

  Future<void> _showFishFormDialog({Map<String, dynamic>? existingFish}) async {
    final bool isEdit = existingFish != null;

    final fishIdController = TextEditingController(text: existingFish?['fishId']?.toString() ?? '');
    final commonNameController = TextEditingController(text: existingFish?['commonName']?.toString() ?? '');
    final scientificNameController = TextEditingController(text: existingFish?['scientificName']?.toString() ?? '');
    final localNameController = TextEditingController(text: existingFish?['localName']?.toString() ?? '');
    final habitatController = TextEditingController(text: existingFish?['habitat']?.toString() ?? '');
    final sizeRangeController = TextEditingController(text: existingFish?['sizeRange']?.toString() ?? '');
    final imageUrlController = TextEditingController(text: existingFish?['imageUrl']?.toString() ?? '');
    final conservationStatusController = TextEditingController(text: existingFish?['conservationStatus']?.toString() ?? '');
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
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fishIdController,
                    enabled: !isEdit,
                    decoration: const InputDecoration(
                      labelText: 'Fish ID (Firebase key)',
                      hintText: 'example: fish_51',
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'Fish ID is required';
                      if (_isInvalidFirebaseKey(v)) {
                        return 'Fish ID cannot contain . # \$ [ ] /';
                      }
                      final alreadyExists = _fishCatalog.any((f) => f['key'] == v);
                      if (!isEdit && alreadyExists) return 'Fish ID already exists';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: commonNameController,
                    decoration: const InputDecoration(labelText: 'Common Name'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Common name is required'
                        : null,
                  ),
                  TextFormField(
                    controller: scientificNameController,
                    decoration: const InputDecoration(labelText: 'Scientific Name'),
                  ),
                  TextFormField(
                    controller: localNameController,
                    decoration: const InputDecoration(labelText: 'Local Name'),
                  ),
                  TextFormField(
                    controller: habitatController,
                    decoration: const InputDecoration(labelText: 'Habitat'),
                  ),
                  TextFormField(
                    controller: sizeRangeController,
                    decoration: const InputDecoration(labelText: 'Size Range'),
                  ),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(labelText: 'Image Asset Path'),
                  ),
                  TextFormField(
                    controller: identifyingFeaturesController,
                    decoration: const InputDecoration(
                      labelText: 'Identifying Features (comma-separated)',
                    ),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: conservationStatusController,
                    decoration: const InputDecoration(labelText: 'Conservation Status'),
                  ),
                  TextFormField(
                    controller: conservationDetailsController,
                    decoration: const InputDecoration(labelText: 'Conservation Details'),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: distributionController,
                    decoration: const InputDecoration(labelText: 'Distribution'),
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

  Future<void> _deleteFish(Map<String, dynamic> fish) async {
    final fishKey = fish['key'].toString();
    final fishId = fish['fishId'].toString();
    final fishName = fish['commonName'].toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Fish Data'),
        content: Text('Delete "$fishName" ($fishId)? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
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
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: true,
                    columns: const [
                      DataColumn(label: Text('Submitted By', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Fish Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Validation', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('User Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _pendingSightings.map((sighting) {
                      final String id = sighting['id'];
                      return DataRow(
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
                          // FIX: Display orange flag if this pin was reported
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
                    }).toList(),
                  ),
                ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.orange, width: 1)),
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
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Current Role', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Manage Access', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _usersList.map((user) {
                      final isCurrentUser = user['uid'] == _authService.currentUser?.uid;
                      
                      return DataRow(
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
                    }).toList(),
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildFishManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.teal[50],
          child: Row(
            children: [
              Text(
                'Total Fish Records: ${_fishCatalog.length}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[900]),
              ),
              const Spacer(),
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
        ),
        Expanded(
          child: _fishCatalog.isEmpty
              ? const Center(
                  child: Text('No fish records found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Fish ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Common Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Scientific Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Habitat', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _fishCatalog.map((fish) {
                        return DataRow(
                          cells: [
                            DataCell(Text(fish['fishId'].toString())),
                            DataCell(Text(fish['commonName'].toString())),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(
                                  fish['scientificName'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(fish['habitat'].toString())),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Edit fish',
                                    onPressed: () => _openEditFishDialog(fish),
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete fish',
                                    onPressed: () => _deleteFish(fish),
                                    icon: const Icon(Icons.delete, color: Colors.red),
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
      const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Sightings'),
      const BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Reports'),
      const BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'Data'),
    ];
    if (_currentUserRole == 'admin') {
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0 ? 'Sightings Queue' 
          : _currentTabIndex == 1 ? 'Reported Posts' 
          : _currentTabIndex == 2 ? 'Fish Data'
          : 'User Management'
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        selectedItemColor: Colors.blue[900],
        items: _navItems,
      ),
    );
  }
}