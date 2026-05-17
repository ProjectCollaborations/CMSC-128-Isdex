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
    // Rebuild markers whenever sightings change (covers verified + own pending)
    _sightingViewModel.addListener(_rebuildMarkers);
    
    // Load fish list for dropdown
    _fishViewModel.addListener(_updateFishList);
    _updateFishList();
    
    // Initial marker build
    _rebuildMarkers();
  }
  
  void _updateFishList() {
    if (mounted) {
      setState(() {
        _fishList = _fishViewModel.filteredFish;
      });
    }
  }

  void _rebuildMarkers() {
    if (!mounted) return;
    
    // Use allSightings so we can access the current user's pending pins.
    // publicSightings only contains verified ones, which would hide the
    // owner's own pending submissions from the map entirely.
    final sightings = _sightingViewModel.allSightings;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final markers = <Marker>[];
    
    for (final sighting in sightings) {
      final isOwner = sighting.userId == currentUserId;
      
      // Show verified sightings to everyone.
      // Show pending sightings ONLY to the user who submitted them.
      // Rejected/archived sightings are never shown on the map.
      final isVisible = sighting.status == SightingStatus.verified ||
          (sighting.status == SightingStatus.pending && isOwner);
      if (!isVisible) continue;
      
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
                if (sighting.status == SightingStatus.pending && isOwner)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<void> _showSightingDetails(Sighting sighting) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = sighting.userId == currentUserId;

    // Pending pins owned by the current user skip the action menu entirely —
    // tapping the pin goes straight to a details sheet with a delete button.
    if (isOwner && sighting.status == SightingStatus.pending) {
      await _showPendingSightingSheet(sighting);
      return;
    }

    // Store scaffold messenger state BEFORE async operations to avoid deactivation errors
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
              'User-submitted sighting. May not be scientifically verified.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This sighting is not linked to a fish.')),
          );
        }
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
                      'Near ${sighting.latitude.toStringAsFixed(5)}°, ${sighting.longitude.toStringAsFixed(5)}°',
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
                if (!isOwner && sighting.status == SightingStatus.verified) ...[
                  const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
      );
    }
  }

  /// Shows a bottom sheet for the current user's own pending sighting.
  /// Displays the sighting details and a prominent delete button — no
  /// intermediate action menu required.
  Future<void> _showPendingSightingSheet(Sighting sighting) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
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
              // Header row: fish name + PENDING badge
              Row(
                children: [
                  Expanded(
                    child: Text(sighting.fishName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Awaiting moderator approval',
                style: TextStyle(fontSize: 13, color: Colors.orange[700], fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 10),
              // Submitted by
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Submitted by you',
                    style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Coordinates
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Near ${sighting.latitude.toStringAsFixed(5)}°, ${sighting.longitude.toStringAsFixed(5)}°',
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
              const SizedBox(height: 16),
              // Delete button — full width, prominent
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete this pin', style: TextStyle(fontSize: 15)),
                  onPressed: () async {
                    Navigator.pop(context);
                    final confirmed = await _confirmDelete(context, sighting.fishName);
                    if (confirmed == true) {
                      final success = await _sightingViewModel.deleteSighting(sighting.id);
                      if (mounted) {
                        if (success) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Sighting deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _rebuildMarkers();
                        } else {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(_sightingViewModel.error ?? 'Failed to delete sighting'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String fishName) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sighting'),
        content: Text('Are you sure you want to delete the sighting of "$fishName"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add a sighting.')),
        );
      }
      return;
    }

    if (_fishList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading fish list, please wait...')),
        );
      }
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

    final String authorName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email?.split('@')[0] ?? 'You';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title + GPS badge
                    Row(
                      children: [
                        const Icon(Icons.add_location_alt, color: Colors.blue, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Add Sighting',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'GPS',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Fish selector
                    const Text(
                      'Fish species',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final fish = await _showFishPickerSheet(context);
                        if (fish != null) setStateSheet(() => selectedFish = fish);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedFish != null ? Colors.blue : Colors.grey.shade400,
                            width: selectedFish != null ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: selectedFish != null ? Colors.blue.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedFish != null ? Icons.check_circle : Icons.search,
                              size: 18,
                              color: selectedFish != null ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedFish?.commonName ?? 'Search and select a fish…',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: selectedFish != null ? Colors.blue.shade800 : Colors.grey.shade500,
                                  fontWeight: selectedFish != null ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (selectedFish != null)
                              GestureDetector(
                                onTap: () => setStateSheet(() => selectedFish = null),
                                child: Icon(Icons.close, size: 16, color: Colors.blue.shade400),
                              )
                            else
                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                    if (selectedFish != null &&
                        selectedFish!.scientificName.isNotEmpty &&
                        selectedFish!.scientificName != 'N/A')
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 2),
                        child: Text(
                          selectedFish!.scientificName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Notes field
                    const Text(
                      'Notes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Describe what you saw (optional)',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Anonymous toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isAnonymous ? Colors.orange.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAnonymous ? Colors.orange.shade200 : Colors.grey.shade200,
                        ),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 14, right: 8),
                        title: Text(
                          'Post anonymously',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isAnonymous ? Colors.orange.shade800 : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          isAnonymous ? 'Your name will be hidden' : 'Shown as: $authorName',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAnonymous ? Colors.orange.shade600 : Colors.grey[500],
                          ),
                        ),
                        secondary: Icon(
                          isAnonymous ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: isAnonymous ? Colors.orange.shade600 : Colors.grey,
                          size: 20,
                        ),
                        value: isAnonymous,
                        activeColor: Colors.orange.shade600,
                        onChanged: (val) => setStateSheet(() => isAnonymous = val),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: selectedFish == null
                                ? null
                                : () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              disabledBackgroundColor: Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Submit Sighting',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true || selectedFish == null) return;

    final fish = selectedFish!;

    final String displayName = isAnonymous ? 'Anonymous' : authorName;

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


  /// Searchable fish picker sheet. Returns the selected [Fish] or null if dismissed.
  Future<Fish?> _showFishPickerSheet(BuildContext parentContext) async {
    final searchController = TextEditingController();
    List<Fish> filtered = List.from(_fishList);

    return showModalBottomSheet<Fish>(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStatepicker) {
          void onSearch(String query) {
            final q = query.toLowerCase().trim();
            setStatepicker(() {
              filtered = q.isEmpty
                  ? List.from(_fishList)
                  : _fishList.where((f) =>
                      f.commonName.toLowerCase().contains(q) ||
                      f.scientificName.toLowerCase().contains(q) ||
                      f.localName.toLowerCase().contains(q),
                    ).toList();
            });
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                // Handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Select Fish',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search bar
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: onSearch,
                        decoration: InputDecoration(
                          hintText: 'Search by name…',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    onSearch('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Results list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                'No fish found',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final fish = filtered[index];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              title: Text(
                                fish.commonName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              subtitle: fish.scientificName.isNotEmpty && fish.scientificName != 'N/A'
                                  ? Text(
                                      fish.scientificName,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                    )
                                  : null,
                              trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                              onTap: () => Navigator.pop(context, fish),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
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