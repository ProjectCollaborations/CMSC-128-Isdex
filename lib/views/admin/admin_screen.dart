import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'widgets/sightings_queue_view.dart';
import 'widgets/reported_posts_view.dart';
import 'widgets/fish_management_view.dart';
import 'widgets/user_management_view.dart';
import '../../core/constants/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();

    if (!vm.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!vm.isModerator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(
          child: Text(
            'Access denied. You do not have moderator privileges.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitle(vm.currentTabIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await context.read<AuthViewModel>().signOut();
                if (context.mounted) context.go('/');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(vm),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.visibility,
                  label: 'Sightings',
                  description: 'Moderate submissions',
                  isSelected: vm.currentTabIndex == 0,
                  onTap: () => vm.setTab(0),
                ),
                _BottomNavItem(
                  icon: Icons.flag,
                  label: 'Reports',
                  description: 'Manage reported posts',
                  isSelected: vm.currentTabIndex == 1,
                  onTap: () => vm.setTab(1),
                ),
                _BottomNavItem(
                  icon: Icons.pets,
                  label: 'Fish Data',
                  description: 'Manage species data',
                  isSelected: vm.currentTabIndex == 2,
                  onTap: () => vm.setTab(2),
                ),
                if (vm.visibleTabs > 3)
                  _BottomNavItem(
                    icon: Icons.people,
                    label: 'Users',
                    description: 'Manage roles',
                    isSelected: vm.currentTabIndex == 3,
                    onTap: () => vm.setTab(3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AdminViewModel vm) {
    switch (vm.currentTabIndex) {
      case 0:
        return const SightingsQueueView();
      case 1:
        return const ReportedPostsView();
      case 2:
        return const FishManagementView();
      case 3:
        return const UserManagementView();
      default:
        return const SizedBox.shrink();
    }
  }

  String _tabTitle(int tab) {
    return switch (tab) {
      0 => 'Admin — Sightings',
      1 => 'Admin — Reports',
      2 => 'Admin — Fish Data',
      3 => 'Admin — Users',
      _ => 'Admin Panel',
    };
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.teal400 : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(description,
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
