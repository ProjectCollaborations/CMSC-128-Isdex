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
  
  // State variables
  String _currentUserRole = 'mod'; // Default fallback
  int _currentTabIndex = 0; // 0 = Sightings, 1 = Users
  bool _isLoading = true;
  bool _isProcessing = false;

  // Data lists
  List<Map<String, dynamic>> _pendingSightings = [];
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
      
      // If Admin, also fetch the user list
      if (_currentUserRole == 'admin') {
        _listenToUsers();
      }
    }
    
    // Everyone here (Admin & Mod) needs the sightings list
    _listenToPendingSightings();
  }

  // ==========================================
  // PHASE 3: SIGHTINGS QUEUE LOGIC
  // ==========================================
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
      for (String id in _selectedIds) {
        updates['user_sightings_temp/$id/status'] = newStatus;
      }
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

        // Sort admins first, then mods, then users
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
        // Action Bar
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

        // Data Table
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTabIndex == 0 ? 'Moderator Dashboard' : 'User Management'),
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
        : (_currentTabIndex == 0 ? _buildSightingsQueue() : _buildUserManagement()),
        
      // Only show the Bottom Nav Bar if the user is an Admin
      bottomNavigationBar: _currentUserRole == 'admin' 
        ? BottomNavigationBar(
            currentIndex: _currentTabIndex,
            onTap: (index) => setState(() => _currentTabIndex = index),
            selectedItemColor: Colors.blue[900],
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Sightings Queue',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'User Management',
              ),
            ],
          )
        : null, // Mods don't get the navigation bar at all
    );
  }
}