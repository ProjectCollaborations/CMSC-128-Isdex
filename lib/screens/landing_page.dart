import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'map_screen.dart';
import 'community_page.dart';  // Add this import
import 'fish_detail_page.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_sightings_map_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}


class _LandingPageState extends State<LandingPage> {  
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> filteredSpecies = [];
  List<Map<dynamic, dynamic>> allSpecies = [];
  TextEditingController searchController = TextEditingController();
  String selectedHabitat = 'All';
  List<String> habitats = ['All', 'Saltwater', 'Freshwater', 'Brackish Water'];

  @override
  void initState() {
    super.initState();
    _loadSpecies();
    searchController.addListener(_filterSpecies);
  }

  void _loadSpecies() {
  final fishRef = _db.child('fish');

  // Keep this path fresh in the local cache
  fishRef.keepSynced(true);

  fishRef.onValue.listen((event) {
    List<Map<dynamic, dynamic>> species = [];

    if (event.snapshot.exists && event.snapshot.value != null) {
      final speciesMap = event.snapshot.value as Map<dynamic, dynamic>;
      speciesMap.forEach((key, value) {
        species.add(Map<dynamic, dynamic>.from(value));
      });
    }

    setState(() {
      allSpecies = species;
      _filterSpecies();
      });
    });
  }

  void _filterSpecies() {
    String searchText = searchController.text.toLowerCase();
    setState(() {
      filteredSpecies = allSpecies.where((fish) {
        bool matchesSearch = fish['commonName']
                .toString()
                .toLowerCase()
                .contains(searchText) ||
            fish['localName']
                .toString()
                .toLowerCase()
                .contains(searchText) ||
            fish['scientificName']
                .toString()
                .toLowerCase()
                .contains(searchText);

        bool matchesHabitat = selectedHabitat == 'All' ||
            fish['habitat'].toString() == selectedHabitat;

        return matchesSearch && matchesHabitat;
      }).toList();
    });
  }
void _showFishDetails(Map<dynamic, dynamic> fish) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FishDetailPage(fish: fish),
    ),
  );
}


  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

      void _showUserMenu() {
      User? user = FirebaseAuth.instance.currentUser;

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
                    await FirebaseAuth.instance.signOut();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out successfully')),
                    );
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
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
                      StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, snapshot) {
                          User? user = snapshot.data;
                          
                          return ElevatedButton(
                            onPressed: () {
                              if (user == null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginPage()),
                                );
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
                                  user == null 
                                    ? 'Log in/Sign up' 
                                    : user.email?.split('@')[0] ?? 'User',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search Species',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: habitats.map((habitat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(habitat),
                                  selected: selectedHabitat == habitat,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedHabitat = habitat;
                                    });
                                    _filterSpecies();
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: Colors.blue[100],
                                  side: BorderSide(
                                    color: selectedHabitat == habitat
                                        ? Colors.blue
                                        : Colors.grey[300]!,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredSpecies.isEmpty
                  ? const Center(
                      child: Text(
                        'No species found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredSpecies.length,
                      itemBuilder: (context, index) {
                        var fish = filteredSpecies[index];
                        return GestureDetector(
                          onTap: () => _showFishDetails(fish),
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
                                  child: fish['imageUrl'] != null &&
                                          fish['imageUrl'].toString().isNotEmpty
                                      ? Image.asset(
                                          fish['imageUrl'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fish['commonName'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        fish['scientificName'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fish['habitat'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // CONDITIONAL BOTTOM NAVIGATION BAR
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  User? user = snapshot.data;
                  bool isLoggedIn = user != null;
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Home Button (Always visible)
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.home, color: Colors.blue, size: 28),
                      ),

                      // Community Button (Only for logged-in users)
                      if (isLoggedIn)
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CommunityPage(),
                              ),
                            );
                          },
                          icon: Icon(Icons.people, color: Colors.grey[400], size: 28),
                        ),

                      // Dev-verified Map Button (Always visible)
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MapScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.map, color: Colors.grey[400], size: 28),
                        tooltip: 'Reference map',
                      ),

                      // User Sightings Map (View for guests, contribute when logged in)
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserSightingsMapScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.location_on,
                          color: isLoggedIn ? Colors.grey : Colors.grey[400],
                          size: 28,
                        ),
                        tooltip: isLoggedIn ? 'User sightings (add & view)' : 'User sightings (view only)',
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
