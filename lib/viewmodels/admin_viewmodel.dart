import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sighting.dart';
import '../models/community_post.dart';
import '../models/fish.dart';
import '../models/app_user.dart';
import 'auth_viewmodel.dart';

typedef WatchAllSightingsFn = Stream<List<Sighting>> Function();
typedef UpdateSightingStatusFn = Future<void> Function(String id, SightingStatus status);
typedef DeleteSightingFn = Future<void> Function(String id);
typedef WatchReportedPostsFn = Stream<List<CommunityPost>> Function();
typedef DismissReportFn = Future<void> Function(String postId);
typedef ArchivePostFn = Future<void> Function(String postId);
typedef WatchFishCatalogFn = Stream<List<Fish>> Function();
typedef WatchArchivedFishFn = Stream<List<Fish>> Function();
typedef AddFishFn = Future<void> Function(Fish fish);
typedef UpdateFishFn = Future<void> Function(Fish fish);
typedef ArchiveFishFn = Future<void> Function(String id);
typedef RestoreFishFn = Future<void> Function(String id);
typedef HardDeleteFishFn = Future<void> Function(String id, {bool fromArchive});
typedef WatchUsersFn = Stream<List<AppUser>> Function();
typedef UpdateUserRoleFn = Future<void> Function(String uid, String role);
typedef AllFishSnapshotFn = Future<List<Fish>> Function();

class AdminViewModel extends ChangeNotifier {
  final AuthViewModel _authVm;
  final WatchAllSightingsFn _watchAllSightings;
  final UpdateSightingStatusFn _updateSightingStatus;
  final DeleteSightingFn _deleteSighting;
  final WatchReportedPostsFn _watchReportedPosts;
  final DismissReportFn _dismissReport;
  final ArchivePostFn _archivePost;
  final WatchFishCatalogFn _watchFishCatalog;
  final WatchArchivedFishFn _watchArchivedFish;
  final AddFishFn _addFish;
  final UpdateFishFn _updateFish;
  final ArchiveFishFn _archiveFish;
  final RestoreFishFn _restoreFish;
  final HardDeleteFishFn _hardDeleteFish;
  final WatchUsersFn _watchUsers;
  final UpdateUserRoleFn _updateUserRole;
  // ignore: unused_field
  final AllFishSnapshotFn _allFishSnapshot;

  // ── Gate state ──
  bool _initialized = false;
  bool _disposed = false;
  String _currentUserRole = 'user';
  int _currentTabIndex = 0;

  // ── Tab 0: Sightings ──
  List<Sighting> _sightings = [];
  final Set<String> _selectedIds = {};
  bool _sightingsLoading = true;
  bool _isProcessing = false;

  // ── Tab 1: Reports ──
  List<CommunityPost> _reportedPosts = [];

  // ── Tab 2: Fish ──
  List<Fish> _fishCatalog = [];
  List<Fish> _archivedFish = [];
  String _searchQuery = '';
  String _habitatFilter = 'All';
  String _sortMode = 'Name (A-Z)';
  bool _showArchivedFish = false;
  bool _fishProcessing = false;

  // ── Tab 3: Users ──
  List<AppUser> _users = [];
  bool _usersProcessing = false;

  // ── Subscriptions ──
  final List<StreamSubscription> _subs = [];

  // ── Getters ──
  bool get isInitialized => _initialized;
  bool get isAdmin => _currentUserRole == 'admin';
  bool get isModerator => _currentUserRole == 'admin' || _currentUserRole == 'mod';
  String get currentUserRole => _currentUserRole;
  int get currentTabIndex => _currentTabIndex;

  List<Sighting> get sightings => _sightings;
  Set<String> get selectedIds => _selectedIds;
  bool get sightingsLoading => _sightingsLoading;
  bool get isProcessing => _isProcessing;

  List<CommunityPost> get reportedPosts => _reportedPosts;

  List<Fish> get fishCatalog => _fishCatalog;
  List<Fish> get archivedFish => _archivedFish;
  String get searchQuery => _searchQuery;
  String get habitatFilter => _habitatFilter;
  String get sortMode => _sortMode;
  bool get showArchivedFish => _showArchivedFish;
  bool get fishProcessing => _fishProcessing;

  List<AppUser> get users => _users;
  bool get usersProcessing => _usersProcessing;

  // Only admins see the Users tab
  bool get showUsersTab => isAdmin;

  // Visible tabs based on role
  int get visibleTabs => showUsersTab ? 4 : 3;

  // Computed: filtered fish list
  List<Fish> get filteredFish {
    var result = _showArchivedFish ? _archivedFish : _fishCatalog;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((f) =>
        f.commonName.toLowerCase().contains(q) ||
        f.scientificName.toLowerCase().contains(q) ||
        f.localName.toLowerCase().contains(q)
      ).toList();
    }

    if (_habitatFilter != 'All') {
      result = result.where((f) =>
        f.habitat.toLowerCase() == _habitatFilter.toLowerCase()
      ).toList();
    }

    if (_sortMode == 'Name (A-Z)') {
      result = List.from(result)..sort((a, b) => a.commonName.compareTo(b.commonName));
    } else if (_sortMode == 'Name (Z-A)') {
      result = List.from(result)..sort((a, b) => b.commonName.compareTo(a.commonName));
    } else if (_sortMode == 'Scientific Name') {
      result = List.from(result)..sort((a, b) => a.scientificName.compareTo(b.scientificName));
    }

    return result;
  }

  AdminViewModel({
    required AuthViewModel authViewModel,
    required WatchAllSightingsFn watchAllSightings,
    required UpdateSightingStatusFn updateSightingStatus,
    required DeleteSightingFn deleteSighting,
    required WatchReportedPostsFn watchReportedPosts,
    required DismissReportFn dismissReport,
    required ArchivePostFn archivePost,
    required WatchFishCatalogFn watchFishCatalog,
    required WatchArchivedFishFn watchArchivedFish,
    required AddFishFn addFish,
    required UpdateFishFn updateFish,
    required ArchiveFishFn archiveFish,
    required RestoreFishFn restoreFish,
    required HardDeleteFishFn hardDeleteFish,
    required WatchUsersFn watchUsers,
    required UpdateUserRoleFn updateUserRole,
    required AllFishSnapshotFn allFishSnapshot,
  })  : _authVm = authViewModel,
        _watchAllSightings = watchAllSightings,
        _updateSightingStatus = updateSightingStatus,
        _deleteSighting = deleteSighting,
        _watchReportedPosts = watchReportedPosts,
        _dismissReport = dismissReport,
        _archivePost = archivePost,
        _watchFishCatalog = watchFishCatalog,
        _watchArchivedFish = watchArchivedFish,
        _addFish = addFish,
        _updateFish = updateFish,
        _archiveFish = archiveFish,
        _restoreFish = restoreFish,
        _hardDeleteFish = hardDeleteFish,
        _watchUsers = watchUsers,
        _updateUserRole = updateUserRole,
        _allFishSnapshot = allFishSnapshot;

  Future<void> init() async {
    _currentUserRole = _authVm.userRole;
    if (_currentUserRole == 'user') {
      _initialized = true;
      notifyListeners();
      return;
    }
    _startListening();
    _initialized = true;
    notifyListeners();
  }

  void _startListening() {
    _subs.add(_watchAllSightings().listen(_onSightingsChanged,
        onError: (_) {}));
    _subs.add(_watchReportedPosts().listen(_onReportedPostsChanged,
        onError: (_) {}));
    _subs.add(_watchFishCatalog().listen(_onFishCatalogChanged,
        onError: (_) {}));
    _subs.add(_watchArchivedFish().listen(_onArchivedFishChanged,
        onError: (_) {}));
    _subs.add(_watchUsers().listen(_onUsersChanged,
        onError: (_) {}));
  }

  void _onSightingsChanged(List<Sighting> sightings) {
    if (_disposed) return;
    _sightings = sightings;
    _sightingsLoading = false;
    // Retain only selections that still exist
    _selectedIds.retainWhere((id) => sightings.any((s) => s.id == id));
    notifyListeners();
  }

  void _onReportedPostsChanged(List<CommunityPost> posts) {
    if (_disposed) return;
    _reportedPosts = posts;
    notifyListeners();
  }

  void _onFishCatalogChanged(List<Fish> fish) {
    if (_disposed) return;
    _fishCatalog = fish;
    notifyListeners();
  }

  void _onArchivedFishChanged(List<Fish> fish) {
    if (_disposed) return;
    _archivedFish = fish;
    notifyListeners();
  }

  void _onUsersChanged(List<AppUser> users) {
    if (_disposed) return;
    _users = users;
    notifyListeners();
  }

  // ── Tab Navigation ──
  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  // ── Sightings ──
  void toggleSelected(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.addAll(_sightings.map((s) => s.id));
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  List<String> approvalValidationErrors(Sighting sighting, Set<String> knownFishIds) {
    final errors = <String>[];
    if (sighting.fishId.isEmpty) errors.add('Missing fish ID');
    if (sighting.fishId.isNotEmpty && !knownFishIds.contains(sighting.fishId)) {
      errors.add('Fish ID does not exist in catalog');
    }
    if (sighting.latitude < -90 || sighting.latitude > 90) errors.add('Invalid latitude');
    if (sighting.longitude < -180 || sighting.longitude > 180) errors.add('Invalid longitude');
    final geoStatus = sighting.geoValidationStatus.toLowerCase();
    if (geoStatus != 'water') {
      errors.add(
        sighting.geoValidationMessage.isNotEmpty
            ? 'Location validation failed: ${sighting.geoValidationMessage}'
            : 'Location is not confirmed as water',
      );
    }
    return errors;
  }

  Future<void> approveSelected() async {
    if (_selectedIds.isEmpty || _fishCatalog.isEmpty) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final knownFishIds = _fishCatalog.map((f) => f.id).toSet();

      for (final id in _selectedIds) {
        final sighting = _sightings.cast<Sighting?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
        if (sighting == null) continue;

        final errors = approvalValidationErrors(sighting, knownFishIds);
        if (errors.isNotEmpty) continue;

        await _updateSightingStatus(id, SightingStatus.approved);
      }
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> archiveSelected() async {
    if (_selectedIds.isEmpty) return;
    _isProcessing = true;
    notifyListeners();

    try {
      for (final id in _selectedIds) {
        await _updateSightingStatus(id, SightingStatus.rejected);
      }
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> approveSighting(String id) async {
    await _updateSightingStatus(id, SightingStatus.approved);
  }

  Future<void> archiveSighting(String id) async {
    await _updateSightingStatus(id, SightingStatus.rejected);
  }

  Future<void> deleteSighting(String id) async {
    await _deleteSighting(id);
  }

  // ── Reports ──
  Future<void> dismissReport(String postId) async {
    await _dismissReport(postId);
  }

  Future<void> archiveReportedPost(String postId) async {
    await _archivePost(postId);
  }

  // ── Fish ──
  Future<void> addFish(Fish fish) async {
    _fishProcessing = true;
    notifyListeners();
    try {
      await _addFish(fish);
    } finally {
      _fishProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> updateFish(Fish fish) async {
    _fishProcessing = true;
    notifyListeners();
    try {
      await _updateFish(fish);
    } finally {
      _fishProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool isFishReferenced(String fishId) {
    for (final sighting in _sightings) {
      if (sighting.fishId == fishId) return true;
    }
    return false;
  }

  Future<void> archiveFish(String id) async {
    final referenced = isFishReferenced(id);
    if (referenced) {
      throw Exception('Cannot archive: this fish is referenced by sightings.');
    }
    _fishProcessing = true;
    notifyListeners();
    try {
      await _archiveFish(id);
    } finally {
      _fishProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> restoreFish(String id) async {
    _fishProcessing = true;
    notifyListeners();
    try {
      await _restoreFish(id);
    } finally {
      _fishProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> hardDeleteFish(String id, {bool fromArchive = false}) async {
    _fishProcessing = true;
    notifyListeners();
    try {
      await _hardDeleteFish(id, fromArchive: fromArchive);
    } finally {
      _fishProcessing = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setHabitatFilter(String filter) {
    _habitatFilter = filter;
    notifyListeners();
  }

  void setSortMode(String mode) {
    _sortMode = mode;
    notifyListeners();
  }

  void toggleShowArchived() {
    _showArchivedFish = !_showArchivedFish;
    notifyListeners();
  }

  // ── Users ──
  Future<void> updateUserRole(String uid, String role) async {
    if (uid == _authVm.user?.uid) return; // Cannot edit own role
    _usersProcessing = true;
    notifyListeners();
    try {
      await _updateUserRole(uid, role);
    } finally {
      _usersProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}
