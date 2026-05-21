import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../viewmodels/fish_catalog_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/fish.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    context.read<FishCatalogViewModel>().search(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showUserMenu() {
    final authVm = context.read<AuthViewModel>();
    final user = authVm.user;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: AppTheme.teal400),
                title: Text(user?.email ?? 'User'),
                subtitle: const Text('Logged in'),
              ),
              const Divider(),
              if (authVm.userRole == 'admin' || authVm.userRole == 'mod')
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: AppTheme.teal400),
                  title: const Text('Admin Panel'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: const Text('Sign Out'),
                onTap: () async {
                  Navigator.pop(context);
                  await authVm.signOut();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Signed out successfully')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogVm = context.watch<FishCatalogViewModel>();
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/isdex_logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 8),
            const Text('Isdex'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              if (!authVm.isLoggedIn) {
                context.go('/login');
              } else {
                _showUserMenu();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildHabitatFilters(catalogVm),
          _buildFishList(catalogVm),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          if (authVm.isLoggedIn)
            const BottomNavigationBarItem(
                icon: Icon(Icons.people), label: 'Community'),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.location_on), label: 'Sightings'),
          if (authVm.isLoggedIn)
            const BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome), label: 'AI'),
          if (authVm.userRole == 'admin' || authVm.userRole == 'mod')
            const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
        onTap: (index) {
          final actions = <void Function()>[
            () {}, // Home
          ];
          if (authVm.isLoggedIn) {
            actions.add(() => context.push('/community'));
          }
          actions.add(() => context.push('/map'));
          actions.add(() => context.push('/sighting'));
          if (authVm.isLoggedIn) {
            actions.add(() => context.push('/chat'));
          }
          if (authVm.userRole == 'admin' || authVm.userRole == 'mod') {
            actions.add(() => context.go('/admin'));
          }
          if (index < actions.length) {
            actions[index]();
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search Species',
          prefixIcon:
              const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.camera_alt, color: AppTheme.teal400),
            tooltip: 'Search by photo',
            onPressed: () => context.push('/fish-search'),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitatFilters(FishCatalogViewModel catalogVm) {
    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: FishCatalogViewModel.habitats.map((habitat) {
            final isSelected = catalogVm.selectedHabitat == habitat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(habitat),
                selected: isSelected,
                onSelected: (_) =>
                    context.read<FishCatalogViewModel>().filterByHabitat(habitat),
                selectedColor: AppTheme.teal50,
                side: BorderSide(
                  color: isSelected ? AppTheme.teal400 : Colors.grey[300]!,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFishList(FishCatalogViewModel catalogVm) {
    return Expanded(
      child: catalogVm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : catalogVm.filteredFish.isEmpty
              ? Center(
                  child: Text(
                    'No species found',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: catalogVm.filteredFish.length,
                  itemBuilder: (context, index) {
                    final fish = catalogVm.filteredFish[index];
                    return _FishCard(
                      fish: fish,
                      onTap: () => context.push('/fish/${fish.id}'),
                    );
                  },
                ),
    );
  }
}

class _FishCard extends StatelessWidget {
  final Fish fish;
  final VoidCallback onTap;

  const _FishCard({required this.fish, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: fish.imageUrl.isNotEmpty
                ? Image.asset(
                    fish.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImage(),
                  )
                : _placeholderImage(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fish.commonName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  fish.scientificName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                StatusChip(label: fish.habitat, color: AppTheme.teal400),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[200],
      child:
          Icon(Icons.image_outlined, size: 30, color: Colors.grey[400]),
    );
  }
}
