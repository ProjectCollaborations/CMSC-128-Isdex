import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'widgets/sightings_queue_view.dart';
import 'widgets/reported_posts_view.dart';
import 'widgets/fish_management_view.dart';
import 'widgets/user_management_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().init();
    });
  }

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
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthViewModel>().signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(vm)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: vm.currentTabIndex,
        onTap: vm.setTab,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.visibility),
            label: 'Sightings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.flag),
            label: 'Reports',
          ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.emoji_nature),
              label: 'Fish',
            ),
          if (vm.visibleTabs > 3)
            const BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
        ],
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
}
