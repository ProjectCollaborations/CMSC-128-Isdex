import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import 'fish_detail_page.dart';

class UserSightingsMapScreen extends StatefulWidget {
  const UserSightingsMapScreen({super.key});

  @override
  State<UserSightingsMapScreen> createState() => _UserSightingsMapScreenState();
}

class _UserSightingsMapScreenState extends State<UserSightingsMapScreen> {
  final MapController _mapController = MapController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final List<Marker> _markers = [];
  LatLng? _userLocation;

  List<Map<String, dynamic>> _fishList = [];
  bool _fishLoaded = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _loadFishList();
    _listenToUserSightings();
    _getUserLocationOnStartup();
  }

  Future<void> _loadFishList() async {
    final snap = await _db.child('fish').get();
    if (!snap.exists || snap.value == null) {
      setState(() { _fishLoaded = true; _fishList = []; });
      return;
    }

    final Map<dynamic, dynamic> fishMap = snap.value as Map<dynamic, dynamic>;
    final List<Map<String, dynamic>> list = [];
    fishMap.forEach((key, value) {
      final m = Map<dynamic, dynamic>.from(value);
      list.add({
        'fishId': m['fishId']?.toString() ?? key.toString(),
        'commonName': m['commonName']?.toString() ?? 'Unknown',
      });
    });

    list.sort((a, b) => a['commonName'].toString().compareTo(b['commonName'].toString()));
    setState(() { _fishList = list; _fishLoaded = true; });
  }

  Future<void> _getUserLocationOnStartup() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _userLocation = latLng;
      });

      // Fly map to user
      _mapController.move(latLng, 14);

    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  void _listenToUserSightings() {
    _db.child('user_sightings_temp').onValue.listen((event) {
      final List<Marker> markers = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final m = value as Map<dynamic, dynamic>;
          final lat = (m['latitude'] as num?)?.toDouble();
          final lng = (m['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) return;

          final fishName = (m['fishName'] ?? 'Sighting').toString();
          final notes = (m['notes'] ?? '').toString();
          final fishId = (m['fishId'] ?? '').toString();
          final ownerId = (m['userId'] ?? '').toString();
          final displayName = (m['displayName'] ?? 'Anonymous').toString();
          final status = (m['status'] ?? 'pending').toString(); // Default to pending
          
          final currentUser = FirebaseAuth.instance.currentUser;
          final isOwner = currentUser != null && currentUser.uid == ownerId;

          // MODERATION FILTER: 
          // If it is NOT approved, and the current user is NOT the owner, hide it.
          if (status != 'approved' && !isOwner) {
            return; 
          }

          // UX: Pending pins are orange, approved are red.
          final pinColor = status == 'pending' ? Colors.orange : Colors.red;

          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () async {
                  if (!mounted) return;

                  final action = await showDialog<String>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fishName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            status == 'pending' 
                                ? 'Status: Pending Moderator Approval' 
                                : 'User-submitted sighting. May not be scientifically verified.',
                            style: TextStyle(
                              fontSize: 13, 
                              color: status == 'pending' ? Colors.orange[700] : Colors.grey[700], 
                              fontStyle: FontStyle.italic,
                              fontWeight: status == 'pending' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, 'viewInfo'),
                          child: const Text('View sighting details', style: TextStyle(fontSize: 16)),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, 'viewFish'),
                          child: const Text('View fish information page', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  );

                  if (action == 'viewFish') {
                    if (fishId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This sighting is not linked to a fish.')),
                      );
                      return;
                    }
                    final fishSnap = await _db.child('fish').child(fishId).get();
                    if (fishSnap.exists && fishSnap.value != null) {
                      final fishData = Map<dynamic, dynamic>.from(fishSnap.value as Map<dynamic, dynamic>);
                      if (mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => FishDetailPage(fish: fishData),
                        ));
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fish details not found.')),
                        );
                      }
                    }
                    return;
                  }

                  if (action == 'viewInfo' && mounted) {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (context) => SafeArea(
                        minimum: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fishName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),

                              // SECURE: show display name, not UID
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOwner ? 'Submitted by you' : 'Submitted by $displayName',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Show only approximate area, not exact coords
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Near ${lat.toStringAsFixed(2)}°, ${lng.toStringAsFixed(2)}°',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),

                              if (notes.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(notes, style: const TextStyle(fontSize: 15)),
                              ],

                              const SizedBox(height: 12),
                              if (isOwner)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _db.child('user_sightings_temp').child(key.toString()).remove();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Sighting deleted')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                                    label: const Text('Delete this pin',
                                        style: TextStyle(color: Colors.red, fontSize: 14)),
                                  ),
                                )
                              else if (status == 'approved') // Only show on public pins
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // Flag the sighting in the database
                                      await _db.child('user_sightings_temp').child(key.toString()).update({'isReported': true});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Sighting reported to moderators.'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.flag, color: Colors.orange, size: 22),
                                    label: const Text('Report inaccurate pin',
                                        style: TextStyle(color: Colors.orange, fontSize: 14)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: pinColor, size: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fishName,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }

      setState(() { _markers..clear()..addAll(markers); });
    });
  }

  /// Gets GPS location then opens the add sighting dialog
  Future<void> _startAddSighting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add a sighting.')),
      );
      return;
    }

    if (!_fishLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading fish list, please wait...')),
      );
      return;
    }

    setState(() => _isLocating = true);

    try {
      // 1. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')),
          );
        }
        return;
      }

      // 2. Get position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng latLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _userLocation = latLng;
      });

      // 3. Fly map to user location
      _mapController.move(latLng, 14.0);

      // 4. Open dialog
      if (mounted) await _showAddSightingDialog(latLng, user);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _showAddSightingDialog(LatLng latLng, User user) async {
    String? selectedFishId;
    String? selectedFishName;
    final notesController = TextEditingController();
    bool isAnonymous = false; // <-- new toggle

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Sighting'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GPS indicator
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Using your current GPS location',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Fish dropdown
                const Text('Fish (common name)',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedFishId,
                  items: _fishList.map((f) => DropdownMenuItem<String>(
                    value: f['fishId'] as String,
                    child: Text(f['commonName'] as String),
                  )).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedFishId = value;
                      selectedFishName = _fishList
                          .firstWhere((f) => f['fishId'] == value)['commonName']
                          .toString();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Select fish',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Anonymous toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: const Text(
                      'Post anonymously',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      isAnonymous
                          ? 'Your name will not be shown'
                          : 'Shown as: ${user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@')[0] ?? 'You'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAnonymous ? Colors.orange[700] : Colors.grey[600],
                      ),
                    ),
                    secondary: Icon(
                      isAnonymous ? Icons.visibility_off : Icons.visibility,
                      color: isAnonymous ? Colors.orange[700] : Colors.blue,
                    ),
                    value: isAnonymous,
                    activeColor: Colors.orange[700],
                    onChanged: (val) => setStateDialog(() => isAnonymous = val),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedFishId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a fish first.')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedFishId == null) return;

    // Resolve display name based on toggle
    final String displayName = isAnonymous
        ? 'Anonymous'
        : (user.displayName?.isNotEmpty == true
            ? user.displayName!
            : user.email?.split('@')[0] ?? 'Anonymous');

    final sightingRef = _db.child('user_sightings_temp').push();
    await sightingRef.set({
      'userId': user.uid,
      'displayName': displayName,
      'isAnonymous': isAnonymous,
      'fishId': selectedFishId,
      'fishName': selectedFishName ?? 'Sighting',
      'notes': notesController.text.trim(),
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
      'createdAt': ServerValue.timestamp,
      'status': 'pending', 
      'isReported': false, // Ensure new pins start clean
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAnonymous
              ? 'Anonymous sighting submitted! Awaiting moderator approval.'
              : 'Sighting submitted as $displayName! Awaiting moderator approval.',
          ),
          duration: const Duration(seconds: 4), // Give them time to read it
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter = _markers.isNotEmpty
        ? _markers.first.point
        : const LatLng(12.8797, 121.7740);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Sightings Map'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 6.0,
          // onTap removed — location is auto-fetched via FAB
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.isdex',
          ),
           if (_userLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _userLocation!,
                  width: 60,
                  height: 60,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 38,
                  ),
                ),
              ],
            ),
          MarkerLayer(markers: _markers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLocating ? null : _startAddSighting,
        backgroundColor: Colors.blue,
        icon: _isLocating
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add_location_alt, color: Colors.white),
        label: Text(
          _isLocating ? 'Locating...' : 'Add Sighting',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}