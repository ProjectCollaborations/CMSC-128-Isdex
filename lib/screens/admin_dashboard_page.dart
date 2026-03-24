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
  int _currentTabIndex = 0; // 0 = Sightings, 1 = Reports, 2 = Users
  bool _isLoading = true;
  bool _isProcessing = false;

  // Data lists
  List<Map<String, dynamic>> _pendingSightings = [];
  List<Map<String, dynamic>> _reportedPosts = [];
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
          // FIX: Check for BOTH pending status OR reported flag
          if (m['status'] == 'pending' || m['isReported'] == true) {
            pending.add({
              'id': key.toString(),
              'fishName': m['fishName']?.toString() ?? 'Unknown Fish',
              'displayName': m['displayName']?.toString() ?? 'Anonymous',
              'notes': m['notes']?.toString() ?? 'No notes provided.',
              'timestamp': m['createdAt'] ?? 0,
              'isReported': m['isReported'] == true, // Track report status
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
        
        // FIX: If moderator approves a reported pin, clear the report flag
        if (newStatus == 'approved') {
          updates['user_sightings_temp/$id/isReported'] = false;
        }
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

  // Determine which view to render based on the selected tab
  Widget _buildBody() {
    if (_currentTabIndex == 0) return _buildSightingsQueue();
    if (_currentTabIndex == 1) return _buildReportedPostsQueue();
    if (_currentTabIndex == 2 && _currentUserRole == 'admin') return _buildUserManagement();
    return const Center(child: Text('Unauthorized access'));
  }

  // Dynamic tabs based on role
  List<BottomNavigationBarItem> get _navItems {
    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Sightings'),
      const BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Reports'),
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