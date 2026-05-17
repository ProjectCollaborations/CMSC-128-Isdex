import 'package:flutter/material.dart';
import '../models/sighting.dart';
import '../models/fish.dart';

typedef SightingStreamFactory = Stream<List<Sighting>> Function();
typedef PushSightingFn = Future<String> Function(Sighting);
typedef DeleteSightingFn = Future<void> Function(String);
typedef ReportSightingFn = Future<void> Function(String);
typedef FishStreamFactory = Stream<List<Fish>> Function();
typedef CurrentUserIdFn = String? Function();
typedef CurrentUserDisplayFn = String Function();

class SightingViewModel extends ChangeNotifier {
  final SightingStreamFactory _watchAllSightings;
  final PushSightingFn _pushSighting;
  final DeleteSightingFn _deleteSighting;
  final ReportSightingFn _reportSighting;
  final FishStreamFactory _watchAllFish;
  final CurrentUserIdFn _currentUserId;
  final CurrentUserDisplayFn _currentUserDisplay;

  List<Sighting> _sightings = [];
  List<Fish> _fishList = [];
  Set<String> _activeFishIds = {};
  bool _isLoading = true;
  bool _isAdding = false;

  List<Sighting> get sightings => _sightings;
  List<Fish> get fishList => _fishList;
  Set<String> get activeFishIds => _activeFishIds;
  bool get isLoading => _isLoading;
  bool get isAdding => _isAdding;

  SightingViewModel({
    required SightingStreamFactory watchAllSightings,
    required PushSightingFn pushSighting,
    required DeleteSightingFn deleteSighting,
    required ReportSightingFn reportSighting,
    required FishStreamFactory watchAllFish,
    required CurrentUserIdFn currentUserId,
    required CurrentUserDisplayFn currentUserDisplay,
  })  : _watchAllSightings = watchAllSightings,
        _pushSighting = pushSighting,
        _deleteSighting = deleteSighting,
        _reportSighting = reportSighting,
        _watchAllFish = watchAllFish,
        _currentUserId = currentUserId,
        _currentUserDisplay = currentUserDisplay {
    _init();
  }

  void _init() {
    _watchAllFish().listen((fish) {
      _fishList = fish;
      _activeFishIds = fish.map((f) => f.id).toSet();
      notifyListeners();
    });

    _watchAllSightings().listen((sightings) {
      _sightings = sightings;
      _isLoading = false;
      notifyListeners();
    });
  }

  List<Sighting> getVisibleSightings(String? currentUid) {
    return _sightings.where((s) {
      if (s.status != SightingStatus.approved && s.userId != currentUid) {
        return false;
      }
      if (_activeFishIds.isNotEmpty &&
          s.fishId.isNotEmpty &&
          !_activeFishIds.contains(s.fishId)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<String> addSighting({
    required String fishId,
    required String fishName,
    required double latitude,
    required double longitude,
    required String notes,
    required bool isAnonymous,
  }) async {
    final uid = _currentUserId();
    if (uid == null) throw Exception('Must be logged in to add sighting');

    final displayName =
        isAnonymous ? 'Anonymous' : _currentUserDisplay();

    _isAdding = true;
    notifyListeners();

    try {
      final sighting = Sighting(
        id: '',
        fishName: fishName,
        fishId: fishId,
        displayName: displayName,
        userId: uid,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
        status: SightingStatus.pending,
        isAnonymous: isAnonymous,
      );

      final key = await _pushSighting(sighting);
      _isAdding = false;
      notifyListeners();
      return key;
    } catch (e) {
      _isAdding = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSighting(String id) async {
    await _deleteSighting(id);
  }

  Future<void> reportSighting(String id) async {
    await _reportSighting(id);
  }
}
