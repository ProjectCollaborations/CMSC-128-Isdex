import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sighting.dart';
import '../models/community_post.dart';
import '../models/fish.dart';
import '../models/app_user.dart';
import 'auth_viewmodel.dart';

typedef WatchSightingsByStatusFn = Stream<List<Sighting>> Function(SightingStatus status);
typedef BatchUpdateSightingStatusFn = Future<void> Function(Set<String> ids, SightingStatus status);
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
  final WatchSightingsByStatusFn _watchSightingsByStatus;
  final BatchUpdateSightingStatusFn _batchUpdateSightingStatus;
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
  // ignore: unused_field — available for snapshot-based validation when needed
  final AllFishSnapshotFn _allFishSnapshot;

  // ── Gate state ──
  bool _initialized = false;
  bool _disposed = false;
  bool _accessGranted = false;
  int _currentTabIndex = 0;

  // ── Tab 0: Sightings ──
  int _sightingsSubTabIndex = 0; // 0=pending, 1=approved, 2=archived
  List<Sighting> _pendingSightings = [];
  List<Sighting> _approvedSightings = [];
  List<Sighting> _archivedSightings = [];
  bool _pendingLoading = true;
  bool _approvedLoading = false;
  bool _archivedLoading = false;
  bool _subTabInitialized = false;
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  // ── Tab 1: Reports ──
  List<CommunityPost> _reportedPosts = [];
  bool _reportsLoading = true;

  // ── Tab 2: Fish ──
  List<Fish> _fishCatalog = [];
  bool _fishCatalogLoading = true;
  List<Fish> _archivedFish = [];
  String _searchQuery = '';
  String _habitatFilter = 'All';
  String _sortMode = 'Name (A-Z)';
  bool _showArchivedFish = false;
  bool _fishProcessing = false;

  // ── Tab 3: Users ──
  List<AppUser> _users = [];
  bool _usersLoading = true;
  bool _usersProcessing = false;

  // ── Subscriptions ──
  final List<StreamSubscription> _subs = [];

  // ── Getters ──
  bool get isInitialized => _initialized;
  bool get isAdmin => _authVm.userRole == 'admin';
  bool get isModerator => _accessGranted || _authVm.userRole == 'admin' || _authVm.userRole == 'mod';
  String get currentUserRole => _authVm.userRole;
  int get currentTabIndex => _currentTabIndex;

  int get sightingsSubTabIndex => _sightingsSubTabIndex;
  List<Sighting> get pendingSightings => _pendingSightings;
  List<Sighting> get approvedSightings => _approvedSightings;
  List<Sighting> get archivedSightings => _archivedSightings;
  bool get pendingLoading => _pendingLoading;
  bool get approvedLoading => _approvedLoading;
  bool get archivedLoading => _archivedLoading;
  Set<String> get selectedIds => _selectedIds;
  bool get reportsLoading => _reportsLoading;
  bool get fishCatalogLoading => _fishCatalogLoading;
  bool get usersLoading => _usersLoading;
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
    required WatchSightingsByStatusFn watchSightingsByStatus,
    required BatchUpdateSightingStatusFn batchUpdateSightingStatus,
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
        _watchSightingsByStatus = watchSightingsByStatus,
        _batchUpdateSightingStatus = batchUpdateSightingStatus,
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
        _allFishSnapshot = allFishSnapshot {
    _authVm.addListener(_recheckAccess);
  }

  void _recheckAccess() {
    if (_disposed) return;
    final role = _authVm.userRole;
    _accessGranted = role == 'admin' || role == 'mod';
    if (!isAdmin && _currentTabIndex >= 3) {
      _currentTabIndex = 0;
    }
    if (_accessGranted && !_initialized) {
      init();
    } else {
      notifyListeners();
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    final role = _authVm.userRole;
    _accessGranted = role == 'admin' || role == 'mod';
    if (!_accessGranted) {
      _initialized = true;
      notifyListeners();
      return;
    }
    _startListening();
    _initialized = true;
    notifyListeners();
  }

  void _startListening() {
    _subscribeWithRetry(
      () => _watchSightingsByStatus(SightingStatus.pending),
      _onSightingsChanged,
    );
    _subscribeWithRetry(_watchReportedPosts, _onReportedPostsChanged);
    _subscribeWithRetry(_watchFishCatalog, _onFishCatalogChanged);
    _subscribeWithRetry(_watchArchivedFish, _onArchivedFishChanged);
    _subscribeWithRetry(_watchUsers, _onUsersChanged);
  }

  void _subscribeWithRetry<T>(
    Stream<T> Function() createStream,
    void Function(T) onData, {
    int attempt = 0,
    int maxRetries = 3,
  }) {
    if (_disposed) return;
    _subs.add(createStream().listen(onData, onError: (e) {
      debugPrint('Admin stream error (attempt ${attempt + 1}/$maxRetries): $e');
      if (attempt < maxRetries && !_disposed) {
        Future.delayed(Duration(seconds: 1 << attempt), () {
          _subscribeWithRetry(createStream, onData,
              attempt: attempt + 1, maxRetries: maxRetries);
        });
      }
    }));
  }

  void _onSightingsChanged(List<Sighting> sightings) {
    if (_disposed) return;
    _pendingSightings = sightings;
    _pendingLoading = false;
    _selectedIds.retainWhere((id) => sightings.any((s) => s.id == id));
    notifyListeners();
  }

  void _onApprovedSightingsChanged(List<Sighting> sightings) {
    if (_disposed) return;
    _approvedSightings = sightings;
    _approvedLoading = false;
    notifyListeners();
  }

  void _onArchivedSightingsChanged(List<Sighting> sightings) {
    if (_disposed) return;
    _archivedSightings = sightings;
    _archivedLoading = false;
    notifyListeners();
  }

  void _onReportedPostsChanged(List<CommunityPost> posts) {
    if (_disposed) return;
    _reportedPosts = posts;
    _reportsLoading = false;
    notifyListeners();
  }

  void _onFishCatalogChanged(List<Fish> fish) {
    if (_disposed) return;
    _fishCatalog = fish;
    _fishCatalogLoading = false;
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
    _usersLoading = false;
    notifyListeners();
  }

  // ── Tab Navigation ──
  void setTab(int index) {
    if (index < 0 || index >= visibleTabs) return;
    _currentTabIndex = index;
    notifyListeners();
  }

  // ── Sightings ──
  void setSightingsSubTab(int index) {
    _sightingsSubTabIndex = index;
    if (!_subTabInitialized) {
      _subTabInitialized = true;
      _subscribeWithRetry(
        () => _watchSightingsByStatus(SightingStatus.approved),
        _onApprovedSightingsChanged,
      );
      _subscribeWithRetry(
        () => _watchSightingsByStatus(SightingStatus.rejected),
        _onArchivedSightingsChanged,
      );
    }
    notifyListeners();
  }

  void toggleSelected(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.addAll(_pendingSightings.map((s) => s.id));
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
    return errors;
  }

  Future<void> approveSelected() async {
    if (_selectedIds.isEmpty || _fishCatalog.isEmpty) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final knownFishIds = _fishCatalog.map((f) => f.id).toSet();
      final validIds = <String>{};

      for (final id in _selectedIds) {
        final sighting = _pendingSightings.where((s) => s.id == id).firstOrNull;
        if (sighting == null) continue;
        if (approvalValidationErrors(sighting, knownFishIds).isEmpty) {
          validIds.add(id);
        }
      }

      if (validIds.isNotEmpty) {
        await _batchUpdateSightingStatus(validIds, SightingStatus.approved);
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
      await _batchUpdateSightingStatus(_selectedIds, SightingStatus.rejected);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> approveSighting(String id) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _updateSightingStatus(id, SightingStatus.approved);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> archiveSighting(String id) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _updateSightingStatus(id, SightingStatus.rejected);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> restoreSighting(String id) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _updateSightingStatus(id, SightingStatus.pending);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> deleteSighting(String id) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _deleteSighting(id);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Reports ──
  Future<void> dismissReport(String postId) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _dismissReport(postId);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> archiveReportedPost(String postId) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _archivePost(postId);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
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
    for (final sighting in _pendingSightings) {
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
      if (!_disposed) notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setHabitatFilter(String filter) {
    if (filter == _habitatFilter) return;
    _habitatFilter = filter;
    notifyListeners();
  }

  void setSortMode(String mode) {
    if (mode == _sortMode) return;
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
