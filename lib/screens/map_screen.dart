import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../viewmodels/map_viewmodel.dart';
import '../data/models/fish.dart';
import 'fish_detail_page.dart';

class MapScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? fishName;
  final String? fishId;

  const MapScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.fishName,
    this.fishId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  late MapViewModel _mapViewModel;
  
  List<Marker> _markers = [];
  Marker? _myLocationMarker;
  bool _isLocating = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _mapViewModel = context.read<MapViewModel>();
      _setupListeners();
      _isInitialized = true;
    }
  }

  void _setupListeners() {
    if (widget.fishId != null) {
      // Show only locations for a specific fish
      _mapViewModel.watchLocationsForFish(widget.fishId!).listen((locations) {
        _rebuildMarkersForLocations(locations);
      });
    } else if (widget.latitude != null && widget.longitude != null) {
      // Show a single location pin
      _showSingleLocationMarker();
    } else {
      // Show all fish locations
      _mapViewModel.addListener(_rebuildAllMarkers);
      _rebuildAllMarkers();
    }
  }

  void _rebuildAllMarkers() {
    final fishLocations = _mapViewModel.fishLocations;
    final userSightingLocations = _mapViewModel.userSightingLocations;
    
    final List<Marker> markers = [];
    
    // Add fish reference locations
    for (final location in fishLocations) {
      markers.add(_buildMarker(
        coordinates: location.coordinates,
        fishId: location.fishId,
        fishName: location.fishName,
        region: location.region,
        isUserSighting: false,
      ));
    }
    
    // Add user sighting locations (approved only)
    for (final location in userSightingLocations) {
      markers.add(_buildMarker(
        coordinates: location.coordinates,
        fishId: location.fishId,
        fishName: location.fishName,
        region: location.region,
        isUserSighting: true,
      ));
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _rebuildMarkersForLocations(List<MapLocation> locations) {
    final markers = locations.map((location) => _buildMarker(
      coordinates: location.coordinates,
      fishId: location.fishId,
      fishName: location.fishName.isNotEmpty ? location.fishName : widget.fishName ?? 'Fish',
      region: location.region,
      isUserSighting: false,
    )).toList();
    
    setState(() {
      _markers = markers;
    });
  }

  void _showSingleLocationMarker() {
    final marker = Marker(
      point: LatLng(widget.latitude!, widget.longitude!),
      width: 80,
      height: 80,
      child: Column(
        children: [
          const Icon(Icons.location_on, color: Colors.red, size: 50),
          if (widget.fishName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                widget.fishName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    
    setState(() {
      _markers = [marker];
    });
  }

  Marker _buildMarker({
    required LatLng coordinates,
    required String fishId,
    required String fishName,
    required String region,
    required bool isUserSighting,
  }) {
    return Marker(
      point: coordinates,
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () async {
          // Fetch full fish details
          final fish = await _mapViewModel.getFishById(fishId);
          if (fish != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FishDetailPage(fish: fish),
              ),
            );
          } else if (mounted) {
            // Fallback: show region info
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  region.isNotEmpty 
                      ? 'Reference location in $region' 
                      : 'Reference location',
                ),
              ),
            );
          }
        },
        child: Column(
          children: [
            Icon(
              Icons.location_on,
              color: isUserSighting ? Colors.red : Colors.blue,
              size: 40,
            ),
            if (fishName.isNotEmpty)
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
            if (region.isNotEmpty && fishName.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  region,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enable it in settings.'),
            ),
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

      final LatLng myLatLng = LatLng(position.latitude, position.longitude);

      final Marker locationMarker = Marker(
        point: myLatLng,
        width: 80,
        height: 80,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
            const Text(
              'You',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
      );

      setState(() => _myLocationMarker = locationMarker);
      _mapController.move(myLatLng, 14.0);
      
      // Also update ViewModel
      _mapViewModel.setUserLocation(myLatLng);
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

  @override
  void dispose() {
    if (widget.fishId == null && widget.latitude == null) {
      _mapViewModel.removeListener(_rebuildAllMarkers);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial center
    LatLng initialCenter;
    double initialZoom;

    if (_markers.isNotEmpty) {
      initialCenter = _markers.first.point;
      initialZoom = 8.0;
    } else if (widget.latitude != null && widget.longitude != null) {
      initialCenter = LatLng(widget.latitude!, widget.longitude!);
      initialZoom = 12.0;
    } else {
      initialCenter = const LatLng(12.8797, 121.7740); // Center of Philippines
      initialZoom = 6.0;
    }

    // Combine all markers
    final allMarkers = [
      ..._markers,
      if (_myLocationMarker != null) _myLocationMarker!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fishName ?? 'Fish Species Map'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _mapViewModel.isLoadingLocations && _markers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _mapViewModel.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_mapViewModel.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _mapViewModel.clearError(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: initialZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.isdex',
                    ),
                    MarkerLayer(markers: allMarkers),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLocating ? null : _goToMyLocation,
        backgroundColor: Colors.blue,
        tooltip: 'Go to my location',
        child: _isLocating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}