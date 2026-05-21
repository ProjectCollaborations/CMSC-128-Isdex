import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/sighting_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/sighting.dart';
import '../../repositories/sighting_repository.dart';
import '../../repositories/fish_repository.dart';
import '../../services/geo_validation_service.dart';

enum _SightingLocationMode { currentLocation, mapSelection }

class UserSightingsMapScreen extends StatefulWidget {
  const UserSightingsMapScreen({super.key});

  @override
  State<UserSightingsMapScreen> createState() => _UserSightingsMapScreenState();
}

class _UserSightingsMapScreenState extends State<UserSightingsMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  LatLng? _selectedSightingLocation;
  bool _isLocating = false;
  bool _isSelectingSightingLocation = false;
  SightingViewModel? _sightingVm;

  @override
  void initState() {
    super.initState();
    _getUserLocationOnStartup();
  }

  @override
  void dispose() {
    _sightingVm?.removeListener(_onVmChanged);
    _sightingVm?.dispose();
    super.dispose();
  }

  SightingViewModel _getSightingVm(BuildContext context) {
    if (_sightingVm != null) return _sightingVm!;
    final sightingRepo = context.read<SightingRepository>();
    final fishRepo = context.read<FishRepository>();
    final authVm = context.read<AuthViewModel>();
    _sightingVm = SightingViewModel(
      watchAllSightings: () => sightingRepo.watchAll(),
      pushSighting: (s) => sightingRepo.push(s),
      deleteSighting: (id) => sightingRepo.delete(id),
      reportSighting: (id) => sightingRepo.reportSighting(id),
      watchAllFish: () => fishRepo.watchAll(),
      currentUserId: () => authVm.user?.uid,
      currentUserDisplay: () => authVm.user?.email.split('@')[0] ?? 'Anonymous',
    );
    _sightingVm!.addListener(_onVmChanged);
    return _sightingVm!;
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
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
      setState(() => _userLocation = latLng);
      _mapController.move(latLng, 14);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _startAddSighting() async {
    final authVm = context.read<AuthViewModel>();
    final user = authVm.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to add a sighting.'),
        ),
      );
      return;
    }

    final sightingVm = _getSightingVm(context);
    if (sightingVm.fishList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading fish list, please wait...')),
      );
      return;
    }

    await _showLocationChoiceSheet(user.email);
  }

  Future<void> _showLocationChoiceSheet(String userEmail) async {
    final mode = await showModalBottomSheet<_SightingLocationMode>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Use current location'),
              subtitle: const Text('Add the sighting at your GPS position'),
              onTap: () =>
                  Navigator.pop(ctx, _SightingLocationMode.currentLocation),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt, color: Colors.green),
              title: const Text('Choose on map'),
              subtitle: const Text('Tap anywhere on the map to place the pin'),
              onTap: () =>
                  Navigator.pop(ctx, _SightingLocationMode.mapSelection),
            ),
          ],
        ),
      ),
    );

    if (!mounted || mode == null) return;

    if (mode == _SightingLocationMode.currentLocation) {
      await _addSightingAtCurrentLocation(userEmail);
    } else {
      _startMapLocationSelection();
    }
  }

  Future<void> _addSightingAtCurrentLocation(String userEmail) async {
    setState(() => _isLocating = true);

    try {
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

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final LatLng latLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() => _userLocation = latLng);
        _mapController.move(latLng, 14.0);
        await _showAddSightingDialog(
          latLng,
          userEmail,
          _SightingLocationMode.currentLocation,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _startMapLocationSelection() {
    setState(() {
      _isSelectingSightingLocation = true;
      _selectedSightingLocation = null;
    });
  }

  void _cancelMapLocationSelection() {
    setState(() {
      _isSelectingSightingLocation = false;
      _selectedSightingLocation = null;
    });
  }

  Future<void> _confirmSelectedSightingLocation() async {
    final selected = _selectedSightingLocation;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap the map to choose a location first.'),
        ),
      );
      return;
    }

    final user = context.read<AuthViewModel>().user;
    if (user == null) {
      _cancelMapLocationSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to add a sighting.'),
        ),
      );
      return;
    }

    setState(() {
      _isSelectingSightingLocation = false;
      _selectedSightingLocation = null;
    });

    await _showAddSightingDialog(
      selected,
      user.email,
      _SightingLocationMode.mapSelection,
    );
  }

  Future<void> _showAddSightingDialog(
    LatLng latLng,
    String userEmail,
    _SightingLocationMode locationMode,
  ) async {
    final sightingVm = _getSightingVm(context);
    String? selectedFishId;
    String? selectedFishName;
    final notesController = TextEditingController();
    bool isAnonymous = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Sighting'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      locationMode == _SightingLocationMode.currentLocation
                          ? Icons.my_location
                          : Icons.add_location_alt,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        locationMode == _SightingLocationMode.currentLocation
                            ? 'Using your current GPS location'
                            : 'Using selected map location',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fish (common name)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedFishId,
                  items: sightingVm.fishList
                      .map(
                        (f) => DropdownMenuItem<String>(
                          value: f.id,
                          child: Text(f.commonName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedFishId = value;
                      selectedFishName = sightingVm.fishList
                          .firstWhere((f) => f.id == value)
                          .commonName;
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
                    title: const Text(
                      'Post anonymously',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      isAnonymous
                          ? 'Your name will not be shown'
                          : 'Shown as: ${userEmail.split('@')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAnonymous
                            ? Colors.orange[700]
                            : Colors.grey[600],
                      ),
                    ),
                    secondary: Icon(
                      isAnonymous ? Icons.visibility_off : Icons.visibility,
                      color: isAnonymous ? Colors.orange[700] : Colors.blue,
                    ),
                    value: isAnonymous,
                    activeThumbColor: Colors.orange[700],
                    onChanged: (val) => setDialogState(() => isAnonymous = val),
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
                    const SnackBar(
                      content: Text('Please select a fish first.'),
                    ),
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

    final displayName = isAnonymous ? 'Anonymous' : userEmail.split('@')[0];

    try {
      key = await sightingVm.addSighting(
        fishId: selectedFishId!,
        fishName: selectedFishName ?? 'Sighting',
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        notes: notesController.text.trim(),
        isAnonymous: isAnonymous,
      );

      // Async geo-validation after save
      GeoValidationService.validate(latLng.latitude, latLng.longitude).then((
        result,
      ) {
        context.read<SightingRepository>().updateGeoValidation(
          key,
          result.status,
          result.message,
        );
      });

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit sighting: $e')),
        );
      }
    }
  }

  late String key;

  List<Marker> _buildMarkers(List<Sighting> visible, String? currentUid) {
    return visible.map((sighting) {
      final isOwner = sighting.userId == currentUid;
      final pinColor = sighting.status == SightingStatus.pending
          ? Colors.orange
          : Colors.red;

      return Marker(
        point: LatLng(sighting.latitude, sighting.longitude),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            if (!mounted) return;
            if (_isSelectingSightingLocation) return;
            _onMarkerTapped(sighting, isOwner, currentUid);
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
                  sighting.fishName,
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
      );
    }).toList();
  }

  void _onMarkerTapped(
    Sighting sighting,
    bool isOwner,
    String? currentUid,
  ) async {
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sighting.fishName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
                fontWeight: sighting.status == SightingStatus.pending
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'viewInfo'),
            child: const Text(
              'View sighting details',
              style: TextStyle(fontSize: 16),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'viewFish'),
            child: const Text(
              'View fish information page',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );

    if (action == 'viewFish') {
      if (sighting.fishId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This sighting is not linked to a fish.'),
          ),
        );
        return;
      }
      if (mounted) context.push('/fish/${sighting.fishId}');
      return;
    }

    if (action == 'viewInfo' && mounted) {
      _showSightingDetails(sighting, isOwner, currentUid);
    }
  }

  void _showSightingDetails(
    Sighting sighting,
    bool isOwner,
    String? currentUid,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sighting.fishName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOwner
                        ? 'Submitted by you'
                        : 'Submitted by ${sighting.displayName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Near ${sighting.latitude.toStringAsFixed(2)}°, ${sighting.longitude.toStringAsFixed(2)}°',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              if (sighting.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(sighting.notes, style: const TextStyle(fontSize: 15)),
              ],
              const SizedBox(height: 12),
              if (isOwner)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _getSightingVm(context).deleteSighting(sighting.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sighting deleted')),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    label: const Text(
                      'Delete this pin',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                )
              else if (sighting.status == SightingStatus.approved)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _getSightingVm(context).reportSighting(sighting.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sighting reported to moderators.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.flag,
                      color: Colors.orange,
                      size: 22,
                    ),
                    label: const Text(
                      'Report inaccurate pin',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final sightingVm = _getSightingVm(context);
    final currentUid = authVm.user?.uid;
    final visible = sightingVm.getVisibleSightings(currentUid);
    final markers = _buildMarkers(visible, currentUid);

    final initialCenter = markers.isNotEmpty
        ? markers.first.point
        : const LatLng(12.8797, 121.7740);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Sightings Map'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 6.0,
              onTap: (_, latLng) {
                if (!_isSelectingSightingLocation) return;
                setState(() => _selectedSightingLocation = latLng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
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
              MarkerLayer(markers: markers),
              if (_selectedSightingLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedSightingLocation!,
                      width: 70,
                      height: 70,
                      child: const Icon(
                        Icons.add_location_alt,
                        color: Colors.green,
                        size: 46,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_isSelectingSightingLocation)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tap the map to choose sighting location',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isSelectingSightingLocation)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cancelMapLocationSelection,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedSightingLocation == null
                            ? null
                            : _confirmSelectedSightingLocation,
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectingSightingLocation
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLocating ? null : _startAddSighting,
              backgroundColor: Colors.blue,
              icon: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
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
