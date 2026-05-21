import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_theme.dart';
import '../../viewmodels/map_viewmodel.dart';
import '../../models/map_location.dart';
import '../../repositories/map_repository.dart';
import '../../repositories/fish_repository.dart';

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
  late final MapViewModel _vm;
  final List<Marker> _markers = [];
  Marker? _myLocationMarker;
  bool _isLocating = false;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _vm = MapViewModel(
      watchAll: () => context.read<MapRepository>().watchAll(),
      fishById: (id) => context.read<FishRepository>().getById(id),
      watchAllFish: () => context.read<FishRepository>().watchAll(),
      fishId: widget.fishId,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (!mounted) return;
    _rebuildMarkers();
  }

  void _rebuildMarkers() {
    _markers.clear();
    if (!_vm.specificFishActive) return;

    if (widget.latitude != null && widget.longitude != null) {
      _markers.add(_buildCoordinateMarker());
    } else if (widget.fishId != null) {
      for (final loc in _vm.locations) {
        _markers.add(_buildRegionMarker(loc));
      }
    } else {
      for (final loc in _vm.locations) {
        _markers.add(_buildFishMarker(loc));
      }
    }
    setState(() {});
  }

  Marker _buildRegionMarker(MapLocation loc) {
    return Marker(
      point: LatLng(loc.latitude, loc.longitude),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc.region.isNotEmpty
                    ? 'Sightings in ${loc.region}'
                    : 'Sightings location',
              ),
            ),
          );
        },
        child: Column(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 40),
            if (loc.region.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  loc.region,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _buildCoordinateMarker() {
    return Marker(
      point: LatLng(widget.latitude!, widget.longitude!),
      width: 80,
      height: 80,
      child: Column(
        children: [
          const Icon(Icons.location_on, color: Colors.red, size: 50),
          if (widget.fishName != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                widget.fishName!,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildFishMarker(MapLocation loc) {
    final label = _vm.fishNameFor(loc.fishId);
    return Marker(
      point: LatLng(loc.latitude, loc.longitude),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () {
          if (loc.fishId.isNotEmpty) {
            context.push('/fish/${loc.fishId}');
          }
        },
        child: Column(
          children: [
            const Icon(Icons.location_on, color: AppTheme.teal400, size: 40),
            if (label.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission denied. Please enable it in settings.'),
            ),
          );
        }
        return;
      }

      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please enable location services.')),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng myLatLng =
          LatLng(position.latitude, position.longitude);

      setState(() {
        _myLocationMarker = Marker(
          point: myLatLng,
          width: 80,
          height: 80,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.teal400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.my_location,
                    color: Colors.white, size: 20),
              ),
              const Text(
                'You',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.teal400,
                ),
              ),
            ],
          ),
        );
      });

      _mapController.move(myLatLng, 14.0);
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
  Widget build(BuildContext context) {
    final initialCenter = _markers.isNotEmpty
        ? _markers.first.point
        : (widget.latitude != null && widget.longitude != null
            ? LatLng(widget.latitude!, widget.longitude!)
            : const LatLng(12.8797, 121.7740));

    final initialZoom =
        widget.fishId != null ? 8.0 : (widget.latitude != null ? 12.0 : 6.0);

    final allMarkers = [
      ..._markers,
      if (_myLocationMarker != null) _myLocationMarker!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fishName ?? 'Fish Species Map'),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: initialZoom,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.isdex',
          ),
          MarkerLayer(markers: allMarkers),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLocating ? null : _goToMyLocation,
        tooltip: 'Go to my location',
        child: _isLocating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
