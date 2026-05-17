import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../viewmodels/sighting_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/fish_catalog_viewmodel.dart';
import '../data/models/sighting.dart';
import '../data/models/fish.dart';
import 'fish_detail_page.dart';

class UserSightingsMapScreen extends StatefulWidget {
  const UserSightingsMapScreen({super.key});

  @override
  State<UserSightingsMapScreen> createState() => _UserSightingsMapScreenState();
}

class _UserSightingsMapScreenState extends State<UserSightingsMapScreen> {
  final MapController _mapController = MapController();
  late final SightingViewModel _sightingViewModel;
  late final MapViewModel _mapViewModel;
  late final FishCatalogViewModel _fishViewModel;
  
  LatLng? _userLocation;
  bool _isLocating = false;
  
  // Local state for UI (not business logic)
  List<Marker> _markers = [];
  List<Fish> _fishList = [];

  @override
  void initState() {
    super.initState();
    _sightingViewModel = context.read<SightingViewModel>();
    _mapViewModel = context.read<MapViewModel>();
    _fishViewModel = context.read<FishCatalogViewModel>();
    
    _getUserLocationOnStartup();
    _listenToViewModels();
  }

  void _listenToViewModels() {
    // Listen to public sightings (approved only)
    _sightingViewModel.addListener(_rebuildMarkers);
    
    // Load fish list for dropdown
    _fishViewModel.addListener(_updateFishList);
    _updateFishList();
    
    // Initial marker build
    _rebuildMarkers();
  }
  
  void _updateFishList() {
    setState(() {
      _fishList = _fishViewModel.filteredFish;
    });
  }

  void _rebuildMarkers() {
    final sightings = _sightingViewModel.publicSightings;
    final markers = <Marker>[];
    
    for (final sighting in sightings) {
      final isOwner = sighting.userId == FirebaseAuth.instance.currentUser?.uid;
      
      // Only show approved sightings OR user's own pending sightings
      if (sighting.status != SightingStatus.verified && !isOwner) {
        continue;
      }
      
      final pinColor = sighting.status == SightingStatus.pending 
          ? Colors.orange 
          : Colors.red;
      
      markers.add(
        Marker(
          point: LatLng(sighting.latitude, sighting.longitude),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showSightingDetails(sighting),
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
                    sighting.fishName,
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
    }
    
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _showSightingDetails(Sighting sighting) async {
    final isOwner = sighting.userId == FirebaseAuth.instance.currentUser?.uid;
    
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sighting.fishName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              sighting.status == SightingStatus.pending
                  ? 'Status: Pending Moderator Approval'
                  : 'User-submitted sighting. May not be scientifically verified.',
              style: TextStyle(
                fontSize: 13,
                color: sighting.status == SightingStatus.pending 
                    ? Colors.orange[700] 
                    : Colors.grey[700],
                fontStyle: FontStyle.italic,
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
      if (sighting.fishId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This sighting is not linked to a fish.')),
        );
        return;
      }
      final fish = await _mapViewModel.getFishById(sighting.fishId);
      if (fish != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => FishDetailPage(fish: fish),
        ));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fish details not found.')),
        );
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
                Text(sighting.fishName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      isOwner ? 'Submitted by you' : 'Submitted by ${sighting.displayName}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Near ${sighting.latitude.toStringAsFixed(2)}°, ${sighting.longitude.toStringAsFixed(2)}°',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (sighting.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(sighting.notes, style: const TextStyle(fontSize: 15)),
                ],
                const SizedBox(height: 12),
                if (isOwner)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _sightingViewModel.deleteSighting(sighting.id);
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
                else if (sighting.status == SightingStatus.verified)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _sightingViewModel.reportSighting(sighting.id);
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
  }

  Future<void> _getUserLocationOnStartup() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _userLocation = latLng);
      _mapController.move(latLng, 14);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _startAddSighting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add a sighting.')),
      );
      return;
    }

    if (_fishList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading fish list, please wait...')),
      );
      return;
    }

    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
      final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = latLng);
      _mapController.move(latLng, 14.0);
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
    Fish? selectedFish;
    final notesController = TextEditingController();
    bool isAnonymous = false;

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
                const Text('Fish (common name)', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<Fish>(
                  value: selectedFish,
                  items: _fishList.map((f) => DropdownMenuItem<Fish>(
                    value: f,
                    child: Text(f.commonName),
                  )).toList(),
                  onChanged: (value) => setStateDialog(() => selectedFish = value),
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
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: const Text('Post anonymously', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      isAnonymous
                          ? 'Your name will not be shown'
                          : 'Shown as: ${user.displayName?.isNotEmpty == true ? user.displayName! : user.email?.split('@')[0] ?? 'You'}',
                      style: TextStyle(fontSize: 12, color: isAnonymous ? Colors.orange[700] : Colors.grey[600]),
                    ),
                    secondary: Icon(isAnonymous ? Icons.visibility_off : Icons.visibility, color: isAnonymous ? Colors.orange[700] : Colors.blue),
                    value: isAnonymous,
                    activeThumbColor: Colors.orange[700],
                    onChanged: (val) => setStateDialog(() => isAnonymous = val),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedFish == null) {
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

    if (confirmed != true || selectedFish == null) return;

    // Extract to local variable after null check
    final fish = selectedFish!;

    // Resolve display name based on toggle
    final String displayName = isAnonymous
        ? 'Anonymous'
        : (user.displayName?.isNotEmpty == true
            ? user.displayName!
            : user.email?.split('@')[0] ?? 'Anonymous');

    final sighting = Sighting(
      id: '',
      userId: user.uid,
      displayName: displayName,
      isAnonymous: isAnonymous,
      fishId: fish.fishId,
      fishName: fish.commonName,
      notes: notesController.text.trim(),
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      createdAt: DateTime.now(),
      status: SightingStatus.pending,
      isReported: false,
      geoValidationStatus: null,
      geoValidationMessage: null,
    );

    final success = await _sightingViewModel.addSighting(sighting);
    
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAnonymous
                ? 'Anonymous sighting submitted! Awaiting moderator approval.'
                : 'Sighting submitted as $displayName! Awaiting moderator approval.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (mounted && _sightingViewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sightingViewModel.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _sightingViewModel.removeListener(_rebuildMarkers);
    _fishViewModel.removeListener(_updateFishList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _markers.isNotEmpty
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
        options: MapOptions(initialCenter: initialCenter, initialZoom: 6.0),
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
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 38),
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
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_location_alt, color: Colors.white),
        label: Text(_isLocating ? 'Locating...' : 'Add Sighting', style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}