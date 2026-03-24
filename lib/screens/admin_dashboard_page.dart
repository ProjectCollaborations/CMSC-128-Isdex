// lib/screens/admin_dashboard_page.dart
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
  
  List<Map<String, dynamic>> _pendingSightings = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _listenToPendingSightings();
  }

  // Fetch only sightings where status is 'pending'
  void _listenToPendingSightings() {
    _db.child('user_sightings_temp').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> pending = [];
        
        data.forEach((key, value) {
          final m = value as Map<dynamic, dynamic>;
          if (m['status'] == 'pending') {
            pending.add({
              'id': key.toString(),
              'fishName': m['fishName']?.toString() ?? 'Unknown Fish',
              'displayName': m['displayName']?.toString() ?? 'Anonymous',
              'notes': m['notes']?.toString() ?? 'No notes provided.',
              'timestamp': m['createdAt'] ?? 0,
            });
          }
        });

        // Sort newest first
        pending.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        if (mounted) {
          setState(() {
            _pendingSightings = pending;
            // Remove any selected IDs that are no longer in the pending list
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

  // Handle the Bulk "Allow" or "Archive" Action
  Future<void> _updateSelectedStatus(String newStatus) async {
    if (_selectedIds.isEmpty) return;
    
    setState(() => _isProcessing = true);

    try {
      // Create a batch update map
      final Map<String, dynamic> updates = {};
      for (String id in _selectedIds) {
        updates['user_sightings_temp/$id/status'] = newStatus;
      }

      // Execute all updates simultaneously
      await _db.update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedIds.length} sightings marked as $newStatus!'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.grey[800],
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Dashboard'),
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
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ACTION BAR (Handles Flood Verifications)
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
                      label: const Text('Archive Selected'),
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

              // DATA TABLE
              Expanded(
                child: _pendingSightings.isEmpty
                  ? const Center(
                      child: Text(
                        'Queue is empty! Great job.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
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
                                DataCell(Text(sighting['fishName'])),
                                DataCell(
                                  SizedBox(
                                    width: 300, // Constrain width so long notes don't break layout
                                    child: Text(
                                      sighting['notes'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
          ),
    );
  }
}