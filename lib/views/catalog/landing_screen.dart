import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(user?.email ?? 'User'),
                subtitle: const Text('Logged in'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out'),
                onTap: () async {
                  Navigator.pop(context);
                  await authVm.signOut();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out successfully')),
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
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(authVm),
            _buildSearchBar(catalogVm),
            _buildHabitatFilters(catalogVm),
            _buildFishList(catalogVm),
            _buildBottomNav(authVm),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AuthViewModel authVm) {
    final user = authVm.user;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/isdex_logo.png',
                height: 40,
                width: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text(
                'Isdex',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              if (!authVm.isLoggedIn) {
                context.go('/login');
              } else {
                _showUserMenu();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  !authVm.isLoggedIn
                      ? 'Log in/Sign up'
                      : user?.email.split('@')[0] ?? 'User',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(FishCatalogViewModel catalogVm) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search Species',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.blue),
              tooltip: 'Search by photo',
              onPressed: () {
                context.push('/fish-search');
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitatFilters(FishCatalogViewModel catalogVm) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: FishCatalogViewModel.habitats.map((habitat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(habitat),
                selected: catalogVm.selectedHabitat == habitat,
                onSelected: (_) {
                  context
                      .read<FishCatalogViewModel>()
                      .filterByHabitat(habitat);
                },
                backgroundColor: Colors.white,
                selectedColor: Colors.blue[100],
                side: BorderSide(
                  color: catalogVm.selectedHabitat == habitat
                      ? Colors.blue
                      : Colors.grey[300]!,
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
              ? const Center(
                  child: Text(
                    'No species found',
                    style: TextStyle(color: Colors.grey),
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

  Widget _buildBottomNav(AuthViewModel authVm) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.home, color: Colors.blue, size: 28),
          ),
          if (authVm.isLoggedIn)
            IconButton(
              onPressed: () {
                context.push('/community');
              },
              icon: Icon(Icons.people, color: Colors.grey[400], size: 28),
            ),
          IconButton(
            onPressed: () {
              context.push('/map');
            },
            icon: Icon(Icons.map, color: Colors.grey[400], size: 28),
            tooltip: 'Reference map',
          ),
          IconButton(
            onPressed: () {
              context.push('/sighting');
            },
            icon: Icon(
              Icons.location_on,
              color: authVm.isLoggedIn ? Colors.grey : Colors.grey[400],
              size: 28,
            ),
            tooltip: authVm.isLoggedIn
                ? 'User sightings (add & view)'
                : 'User sightings (view only)',
          ),
          if (authVm.isLoggedIn)
            IconButton(
              onPressed: () {
                context.push('/chat');
              },
              icon: Icon(
                Icons.auto_awesome,
                color: Colors.grey[400],
                size: 28,
              ),
              tooltip: 'AI Assistant',
            ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[200]!,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image_outlined,
                            size: 30,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image_outlined,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                    ),
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
                    ),
                  ),
                  Text(
                    fish.scientificName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fish.habitat,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
