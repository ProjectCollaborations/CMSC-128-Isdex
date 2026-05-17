// lib/screens/landing_page.dart
import 'package:flutter/material.dart';
import 'package:isdex/screens/community_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../viewmodels/fish_catalog_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'fish_detail_page.dart';
import 'login_page.dart';
import 'map_screen.dart';
import 'user_sightings_map_screen.dart';
import 'ai_chat_screen.dart';
import 'fish_image_search.dart';  // ← ADD THIS IMPORT
import '../services/database_init_service.dart';
import '../data/models/fish.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseInitService _dbInitService = DatabaseInitService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _dbInitService.initializeAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showUserMenu(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(user.email ?? 'User'),
                subtitle: const Text('Logged in'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out'),
                onTap: () async {
                  final authVm = context.read<AuthViewModel>();
                  await authVm.signOut();
                  if (mounted) {
                    Navigator.pop(context);
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
    final fishVm = context.watch<FishCatalogViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
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
                          if (user == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            );
                          } else {
                            _showUserMenu(context, user);
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
                              user == null
                                  ? 'Log in/Sign up'
                                  : user.email?.split('@')[0] ?? 'User',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => fishVm.setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText: 'Search Species',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.blue),
                          tooltip: 'Search by photo',
                          onPressed: () {
                            final allFish = fishVm.filteredFish;
                            
                            if (allFish.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Loading fish data, please wait...'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            
                            // Convert List<Fish> to List<Map<dynamic, dynamic>>
                            final allSpecies = allFish.map((fish) {
                              return {
                                'fishId': fish.fishId,
                                'commonName': fish.commonName,
                                'scientificName': fish.scientificName,
                                'localName': fish.localName,
                                'habitat': fish.habitat,
                                'sizeRange': fish.sizeRange,
                                'imageUrl': fish.imageUrl,
                                'identifyingFeatures': fish.identifyingFeatures,
                                'conservationStatus': fish.conservationStatus,
                                'conservationDetails': fish.conservationDetails,
                                'distribution': fish.distribution,
                              };
                            }).toList();
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FishImageSearch(
                                  allSpecies: allSpecies,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Habitat filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: fishVm.habitats.map((habitat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(habitat),
                            selected: fishVm.selectedHabitat == habitat,
                            onSelected: (_) => fishVm.setHabitat(habitat),
                            backgroundColor: Colors.white,
                            selectedColor: Colors.blue[100],
                            side: BorderSide(
                              color: fishVm.selectedHabitat == habitat
                                  ? Colors.blue
                                  : Colors.grey[300]!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Fish list
            Expanded(
              child: _buildBody(fishVm),
            ),

            // Bottom navigation
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.home, color: Colors.blue, size: 28),
                  ),
                  if (user != null)
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CommunityPage()),
                        );
                      },
                      icon: Icon(Icons.people, color: Colors.grey[400], size: 28),
                    ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      );
                    },
                    icon: Icon(Icons.map, color: Colors.grey[400], size: 28),
                    tooltip: 'Reference map',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserSightingsMapScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.location_on,
                      color: user != null ? Colors.grey : Colors.grey[400],
                      size: 28,
                    ),
                    tooltip: user != null ? 'User sightings' : 'User sightings (view only)',
                  ),
                  if (user != null)
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiChatScreen()),
                        );
                      },
                      icon: Icon(Icons.auto_awesome, color: Colors.grey[400], size: 28),
                      tooltip: 'AI Assistant',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FishCatalogViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(vm.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => vm.refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (vm.filteredFish.isEmpty) {
      return const Center(
        child: Text(
          'No species found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vm.filteredFish.length,
      itemBuilder: (context, index) {
        final fish = vm.filteredFish[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FishDetailPage(fish: fish),
              ),
            );
          },
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
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[200],
                            child: Icon(Icons.image_outlined, color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: Icon(Icons.image_outlined, color: Colors.grey[400]),
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
      },
    );
  }
}