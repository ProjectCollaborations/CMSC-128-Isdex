import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
  LatLng? _pendingTap;

  // Fish list loaded from RTDB
  List<Map<String, dynamic>> _fishList = [];
  bool _fishLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFishList();
    _listenToUserSightings();
  }

  Future<void> _loadFishList() async {
    final snap = await _db.child('fish').get();
    if (!snap.exists || snap.value == null) {
      setState(() {
        _fishLoaded = true;
        _fishList = [];
      });
      return;
    }

    final Map<dynamic, dynamic> fishMap =
        snap.value as Map<dynamic, dynamic>;

    final List<Map<String, dynamic>> list = [];
    fishMap.forEach((key, value) {
      final m = Map<dynamic, dynamic>.from(value);
      list.add({
        'fishId': m['fishId']?.toString() ?? key.toString(),
        'commonName': m['commonName']?.toString() ?? 'Unknown',
      });
    });

    list.sort((a, b) =>
        a['commonName'].toString().compareTo(b['commonName'].toString()));

    setState(() {
      _fishList = list;
      _fishLoaded = true;
    });
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
          final currentUser = FirebaseAuth.instance.currentUser;
          final isOwner = currentUser != null && currentUser.uid == ownerId;

          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () async {
                  if (!mounted) return;

                  // Ask user what to do
                  final action = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      return SimpleDialog(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fishName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Note: User-submitted sighting. Information may not be scientifically verified.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 'viewInfo'),
                            child: const Text(
                              'View sighting details',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 'viewFish'),
                            child: const Text(
                              'View fish information page',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (action == 'viewFish') {
                    if (fishId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This sighting is not linked to a fish.'),
                        ),
                      );
                      return;
                    }

                    final fishSnap =
                        await _db.child('fish').child(fishId).get();
                    if (fishSnap.exists && fishSnap.value != null) {
                      final fishData = Map<dynamic, dynamic>.from(
                          fishSnap.value as Map<dynamic, dynamic>);
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FishDetailPage(fish: fishData),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Fish details not found for this sighting.'),
                          ),
                        );
                      }
                    }
                    return;
                  }

                  if (action == 'viewInfo') {
                    if (!mounted) return;
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return SafeArea(
                            minimum: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fishName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Author line
                                  Text(
                                    ownerId.isNotEmpty
                                        ? (isOwner
                                            ? 'Submitted by you'
                                            : 'Submitted by: $ownerId')
                                        : 'Submitted by: unknown user',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Lat: ${lat.toStringAsFixed(5)}, '
                                    'Lng: ${lng.toStringAsFixed(5)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      notes,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (isOwner)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await _db
                                              .child('user_sightings_temp')
                                              .child(key.toString())
                                              .remove();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Sighting deleted')),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 22,
                                        ),
                                        label: const Text(
                                          'Delete this pin',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                },
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        fishName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

      setState(() {
        _markers
          ..clear()
          ..addAll(markers);
      });
    });
  }

  Future<void> _handleMapTap(TapPosition tapPos, LatLng latLng) async {
    _pendingTap = latLng;
    await _showAddSightingDialog(latLng);
  }

  Future<void> _showAddSightingDialog(LatLng latLng) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add a sighting.')),
      );
      return;
    }

    if (!_fishLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading fish list, try again in a moment.')),
      );
      return;
    }

    String? selectedFishId;
    String? selectedFishName;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Sighting'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lat: ${latLng.latitude.toStringAsFixed(5)}, '
                      'Lng: ${latLng.longitude.toStringAsFixed(5)}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Fish (common name)',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedFishId,
                      items: _fishList
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f['fishId'] as String,
                              child: Text(f['commonName'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedFishId = value;
                          selectedFishName = _fishList
                              .firstWhere(
                                  (f) => f['fishId'] == value)['commonName']
                              .toString();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Select fish',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
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
                        const SnackBar(
                            content: Text('Please select a fish first.')),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedFishId == null) return;

    final sightingRef = _db.child('user_sightings_temp').push();
    await sightingRef.set({
      'userId': user.uid,
      'fishId': selectedFishId,
      'fishName': selectedFishName ?? 'Sighting',
      'notes': notesController.text.trim(),
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
      'createdAt': ServerValue.timestamp,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sighting added')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter =
        _markers.isNotEmpty ? _markers.first.point : const LatLng(12.8797, 121.7740);

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
          onTap: _handleMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.isdex',
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}
