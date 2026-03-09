import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
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
  List<Marker> markers = [];
  Marker? _myLocationMarker;
  bool _isLocating = false;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadFishLocations();
  }

  /// Requests permission, fetches GPS, adds a pin and flies to it.
  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);

    try {
      // 1. Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enable it in settings.'),
            ),
          );
        }
        return;
      }

      // 2. Check if location service is enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')),
          );
        }
        return;
      }

      // 3. Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng myLatLng = LatLng(position.latitude, position.longitude);

      // 4. Build a distinct "my location" marker
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
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
            const Text(
              'You',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );

      setState(() => _myLocationMarker = locationMarker);

      // 5. Animate map to the new location
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

  void _loadFishLocations() {
    if (widget.fishId != null) {
      _db
          .child('map')
          .orderByChild('fishId')
          .equalTo(widget.fishId)
          .onValue
          .listen((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          setState(() => markers = []);
          return;
        }

        final Map<dynamic, dynamic> locationsMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        final List<Marker> newMarkers = [];

        locationsMap.forEach((locationId, locationData) {
          final data = locationData as Map<dynamic, dynamic>;
          final double lat = (data['latitude'] as num?)?.toDouble() ?? 12.8797;
          final double lng = (data['longitude'] as num?)?.toDouble() ?? 121.7740;
          final String region = data['region'] ?? 'Unknown';

          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        region.isNotEmpty ? 'Sightings in $region' : 'Sightings location',
                      ),
                    ),
                  );
                },
                child: Column(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 40),
                    if (region.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          region,
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

        setState(() => markers = newMarkers);
      });
      return;
    }

    if (widget.latitude != null && widget.longitude != null) {
      setState(() {
        markers = [
          Marker(
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
          ),
        ];
      });
      return;
    }

    _db.child('map').onValue.listen((event) {
      final List<Marker> newMarkers = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> locationsMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        locationsMap.forEach((locationId, locationData) {
          final data = locationData as Map<dynamic, dynamic>;
          final double latitude = (data['latitude'] as num?)?.toDouble() ?? 12.8797;
          final double longitude = (data['longitude'] as num?)?.toDouble() ?? 121.7740;
          final String fishId = data['fishId'] ?? 'unknown';

          _db.child('fish').child(fishId).once().then((fishSnapshot) {
            if (fishSnapshot.snapshot.exists && fishSnapshot.snapshot.value != null) {
              final Map<dynamic, dynamic> fishData =
                  fishSnapshot.snapshot.value as Map<dynamic, dynamic>;

              final marker = Marker(
                point: LatLng(latitude, longitude),
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/fishDetail'),
                        builder: (context) => FishDetailPage(fish: fishData),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue, size: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          fishData['commonName']?.toString() ?? 'Fish',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              setState(() {
                newMarkers.add(marker);
                markers = List<Marker>.from(newMarkers);
              });
            }
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter = markers.isNotEmpty
        ? markers.first.point
        : (widget.latitude != null && widget.longitude != null
            ? LatLng(widget.latitude!, widget.longitude!)
            : const LatLng(12.8797, 121.7740));

    final double initialZoom =
        widget.fishId != null ? 8.0 : (widget.latitude != null ? 12.0 : 6.0);

    // Combine fish markers + optional "my location" marker
    final allMarkers = [
      ...markers,
      if (_myLocationMarker != null) _myLocationMarker!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fishName ?? 'Fish Species Map'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
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