import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'admin/sightings_tab.dart';
import 'admin/reports_tab.dart';
import 'admin/fish_tab.dart';
import 'admin/users_tab.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AuthService _authService = AuthService();
  
  String _currentUserRole = 'mod';
  int _currentTabIndex = 0;
  
  final List<({String label, IconData icon, Widget Function() builder})> _modTabs = [
    (label: 'Sightings', icon: Icons.map, builder: () => const SightingsTab()),
    (label: 'Reports', icon: Icons.flag, builder: () => const ReportsTab()),
    (label: 'Data', icon: Icons.storage, builder: () => const FishTab()),
  ];
  
  late final List<({String label, IconData icon, Widget Function() builder})> _adminTabs;

  @override
  void initState() {
    super.initState();
    _adminTabs = [
      ..._modTabs,
      (label: 'Users', icon: Icons.people, builder: () => const UsersTab()),
    ];
    _loadUserRole();
  }
  
  Future<void> _loadUserRole() async {
    final user = _authService.currentUser;
    if (user != null) {
      final role = await _authService.getUserRole(user.uid);
      if (mounted) {
        setState(() => _currentUserRole = role ?? 'mod');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _currentUserRole == 'admin' ? _adminTabs : _modTabs;
    final currentSection = tabs[_currentTabIndex].label;
    
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
      body: tabs[_currentTabIndex].builder(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue[900],
        unselectedItemColor: Colors.blueGrey[600],
        items: tabs.map((tab) {
          return BottomNavigationBarItem(
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Icon(tab.icon, size: 22),
              ],
            ),
            activeIcon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue[900]),
                ),
                const SizedBox(height: 4),
                Icon(tab.icon, color: Colors.blue[900], size: 22),
              ],
            ),
            label: '',
          );
        }).toList(),
      ),
    );
  }
}