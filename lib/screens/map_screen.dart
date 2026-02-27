import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'fish_detail_page.dart'; // Import the fish detail page

class MapScreen extends StatefulWidget {
  final double? latitude;    // optional: single location mode
  final double? longitude;
  final String? fishName;
  final String? fishId;      // when provided, show all locations for this fish

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
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadFishLocations();
  }

  void _loadFishLocations() {
    // Case 1: specific fishId -> multiple locations
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
          final double lat =
              (data['latitude'] as num?)?.toDouble() ?? 12.8797;
          final double lng =
              (data['longitude'] as num?)?.toDouble() ?? 121.7740;
          final String region = data['region'] ?? 'Unknown';

          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
          child: GestureDetector(
            onTap: () {
              // Already in FishDetailPage context; just show a hint or do nothing.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    region.isNotEmpty
                        ? 'Sightings in $region'
                        : 'Sightings location',
                  ),
                ),
              );
            },
            child: Column(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
                if (region.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    // color: Colors.white,
                    child: Text(
                      region,
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

        setState(() => markers = newMarkers);
      });

      return;
    }

    // Case 2: single passed coordinate (old behaviour)
    if (widget.latitude != null && widget.longitude != null) {
      setState(() {
        markers = [
          Marker(
            point: LatLng(widget.latitude!, widget.longitude!),
            width: 80,
            height: 80,
            child: Column(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 50,
                ),
                if (widget.fishName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    // color: Colors.white,
                    child: Text(
                      widget.fishName!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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

    // Case 3: overview of all fish (your original logic)
    _db.child('map').onValue.listen((event) {
      final List<Marker> newMarkers = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> locationsMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        locationsMap.forEach((locationId, locationData) {
          final data = locationData as Map<dynamic, dynamic>;
          final double latitude =
              (data['latitude'] as num?)?.toDouble() ?? 12.8797;
          final double longitude =
              (data['longitude'] as num?)?.toDouble() ?? 121.7740;
          final String fishId = data['fishId'] ?? 'unknown';

          _db.child('fish').child(fishId).once().then((fishSnapshot) {
            if (fishSnapshot.snapshot.exists &&
                fishSnapshot.snapshot.value != null) {
              final Map<dynamic, dynamic> fishData =
                  fishSnapshot.snapshot.value as Map<dynamic, dynamic>;

              final marker = Marker(
                point: LatLng(latitude, longitude),
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () {
                    // Navigate to fish detail page instead of showing popup
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
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        //color: Colors.white,
                        child: Text(
                          fishData['commonName']?.toString() ?? 'Fish',
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

  // Helper method to navigate to fish detail page
  void _navigateToFishDetail(String fishId) async {
    final fishSnapshot = await _db.child('fish').child(fishId).once();
    
    if (fishSnapshot.snapshot.exists && fishSnapshot.snapshot.value != null) {
      final Map<dynamic, dynamic> fishData =
          fishSnapshot.snapshot.value as Map<dynamic, dynamic>;
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FishDetailPage(fish: fishData),
          ),
        );
      }
    }
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
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}