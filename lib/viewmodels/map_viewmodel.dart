import 'dart:async';
import 'package:flutter/material.dart';
import '../models/map_location.dart';
import '../models/fish.dart';

typedef MapStreamFactory = Stream<List<MapLocation>> Function();
typedef FishByIdFactory = Future<Fish?> Function(String id);
typedef FishStreamFactory = Stream<List<Fish>> Function();

class MapViewModel extends ChangeNotifier {
  final MapStreamFactory _watchAll;
  final FishByIdFactory _fishById;
  final String? _fishId;
  final double? _latitude;
  final double? _longitude;

  List<MapLocation> _locations = [];
  bool _isLoading = true;
  bool _specificFishActive = true;
  Map<String, String> _fishNames = {};
  StreamSubscription? _sub;
  StreamSubscription<List<Fish>>? _fishSub;

  List<MapLocation> get locations => _locations;
  bool get isLoading => _isLoading;
  bool get specificFishActive => _specificFishActive;

  String fishNameFor(String fishId) => _fishNames[fishId] ?? fishId;

  MapViewModel({
    required MapStreamFactory watchAll,
    required FishByIdFactory fishById,
    required FishStreamFactory watchAllFish,
    String? fishId,
    double? latitude,
    double? longitude,
  })  : _watchAll = watchAll,
        _fishById = fishById,
        _fishId = fishId,
        _latitude = latitude,
        _longitude = longitude {
    _fishSub = watchAllFish().listen((fish) {
      _fishNames = {for (var f in fish) f.id: f.commonName};
      notifyListeners();
    });
    _init();
  }

  void _init() {
    if (_fishId != null) {
      _loadSpecificFish();
    } else if (_latitude != null && _longitude != null) {
      _loadSingleCoordinate();
    } else {
      _loadAll();
    }
  }

  void _loadSpecificFish() {
    _sub = _watchAll().listen((locs) {
      _locations = locs.where((l) => l.fishId == _fishId).toList();
      _isLoading = false;
      notifyListeners();
    });

    _fishById(_fishId!).then((fish) {
      _specificFishActive = fish != null;
      notifyListeners();
    });
  }

  void _loadSingleCoordinate() {
    _locations = [
      MapLocation(
        id: 'single',
        fishId: '',
        latitude: _latitude!,
        longitude: _longitude!,
        region: '',
      ),
    ];
    _isLoading = false;
    notifyListeners();
  }

  void _loadAll() {
    _sub = _watchAll().listen((locs) {
      _locations = locs;
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fishSub?.cancel();
    super.dispose();
  }
}
