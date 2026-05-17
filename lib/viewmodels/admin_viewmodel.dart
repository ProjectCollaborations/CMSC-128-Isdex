import 'package:flutter/material.dart';
import '../data/models/sighting.dart';
import '../data/models/community_post.dart';
import '../data/models/fish.dart';
import '../data/repositories/sighting_repository.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/fish_repository.dart';
import '../data/repositories/auth_repository.dart';

class AdminViewModel extends ChangeNotifier {
  final SightingRepository _sightingRepository;
  final CommunityRepository _communityRepository;
  final FishRepository _fishRepository;
  final AuthRepository _authRepository;
  
  AdminViewModel(
    this._sightingRepository,
    this._communityRepository,
    this._fishRepository,
    this._authRepository,
  ) {
    _init();
  }
  
  // ==========================================
  // STATE
  // ==========================================
  
  // Sightings
  List<Sighting> _allSightings = [];
  List<Sighting> _filteredSightings = [];
  int _selectedSightingsTab = 0; // 0=Pending, 1=Verified, 2=Rejected, 3=All
  final Set<String> _selectedSightingIds = {};
  
  // Reports
  List<CommunityPost> _reportedPosts = [];
  
  // Fish catalog
  List<Fish> _fishCatalog = [];
  List<Map<String, dynamic>> _archivedFish = [];
  bool _showArchivedFish = false;
  String _fishSearchQuery = '';
  String _fishHabitatFilter = 'All';
  String _fishSortMode = 'Name (A-Z)';
  
  // Users
  List<Map<String, dynamic>> _users = [];
  
  // UI state
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  
  // ==========================================
  // GETTERS
  // ==========================================
  
  // Sightings
  List<Sighting> get allSightings => _allSightings;
  List<Sighting> get filteredSightings => _filteredSightings;
  int get selectedSightingsTab => _selectedSightingsTab;
  Set<String> get selectedSightingIds => _selectedSightingIds;
  int get pendingCount => _allSightings.where((s) => s.status == SightingStatus.pending).length;
  int get verifiedCount => _allSightings.where((s) => s.status == SightingStatus.verified).length;
  int get rejectedCount => _allSightings.where((s) => s.status == SightingStatus.rejected).length;
  
  // Reports
  List<CommunityPost> get reportedPosts => _reportedPosts;
  
  // Fish catalog
  List<Fish> get fishCatalog => _fishCatalog;
  List<Map<String, dynamic>> get archivedFish => _archivedFish;
  bool get showArchivedFish => _showArchivedFish;
  String get fishSearchQuery => _fishSearchQuery;
  String get fishHabitatFilter => _fishHabitatFilter;
  String get fishSortMode => _fishSortMode;
  
  // Users
  List<Map<String, dynamic>> get users => _users;
  
  // UI state
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  
  // Available habitats (from actual fish data)
  List<String> get habitats {
    final Set<String> habitats = {'All'};
    for (final fish in _fishCatalog) {
      if (fish.habitat.isNotEmpty) habitats.add(fish.habitat);
    }
    final result = habitats.toList();
    result.sort();
    if (result.first != 'All') {
      result.remove('All');
      result.insert(0, 'All');
    }
    return result;
  }
  
  List<String> get sortOptions => const ['Name (A-Z)', 'Fish ID'];
  
  // ==========================================
  // INITIALIZATION
  // ==========================================
  
  void _init() {
    // Listen to all sightings
    _sightingRepository.watchAllSightings().listen((sightings) {
      _allSightings = sightings;
      _applySightingFilter();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
    
    // Listen to reported posts
    _communityRepository.watchReportedPosts().listen((posts) {
      _reportedPosts = posts;
      notifyListeners();
    });
    
    // Listen to fish catalog
    _fishRepository.watchAllFish().listen((fish) {
      _fishCatalog = fish;
      _applyFishFilter();
      notifyListeners();
    });
    
    // Listen to archived fish
    _fishRepository.watchArchivedFish().listen((fish) {
      _archivedFish = fish;
      notifyListeners();
    });
    
    // Load users
    _loadUsers();
  }
  
  Future<void> _loadUsers() async {
    // This would need a proper user repository method
    // For now, placeholder - actual implementation would fetch from Firebase
    _users = [];
  }
  
  // ==========================================
  // SIGHTINGS FILTERING
  // ==========================================
  
  void setSightingsTab(int index) {
    _selectedSightingsTab = index;
    _applySightingFilter();
    notifyListeners();
  }
  
  void _applySightingFilter() {
    switch (_selectedSightingsTab) {
      case 0: // Pending
        _filteredSightings = _allSightings.where((s) => s.status == SightingStatus.pending).toList();
        break;
      case 1: // Verified
        _filteredSightings = _allSightings.where((s) => s.status == SightingStatus.verified).toList();
        break;
      case 2: // Rejected
        _filteredSightings = _allSightings.where((s) => s.status == SightingStatus.rejected).toList();
        break;
      default: // All
        _filteredSightings = List.from(_allSightings);
        break;
    }
  }
  
  // ==========================================
  // SIGHTINGS SELECTION
  // ==========================================
  
  void toggleSelectSighting(String id) {
    if (_selectedSightingIds.contains(id)) {
      _selectedSightingIds.remove(id);
    } else {
      _selectedSightingIds.add(id);
    }
    notifyListeners();
  }
  
  void selectAllFilteredSightings() {
    _selectedSightingIds.clear();
    _selectedSightingIds.addAll(_filteredSightings.map((s) => s.id));
    notifyListeners();
  }
  
  void clearSelectedSightings() {
    _selectedSightingIds.clear();
    notifyListeners();
  }
  
  // ==========================================
  // SIGHTINGS ACTIONS
  // ==========================================
  
  Future<int> approveSelectedSightings() async {
    return await _bulkUpdateSightingStatus(SightingStatus.verified);
  }
  
  Future<int> rejectSelectedSightings() async {
    return await _bulkUpdateSightingStatus(SightingStatus.rejected);
  }
  
  Future<int> _bulkUpdateSightingStatus(SightingStatus status) async {
    if (_selectedSightingIds.isEmpty) return 0;
    
    _isProcessing = true;
    notifyListeners();
    
    final (successCount, failures) = await _sightingRepository.bulkUpdateStatus(
      _selectedSightingIds.toList(),
      status,
    );
    
    if (failures.isNotEmpty && _error == null) {
      _error = '${failures.length} sighting(s) failed validation: ${failures.values.take(2).join('; ')}';
    }
    
    _selectedSightingIds.clear();
    _isProcessing = false;
    notifyListeners();
    
    return successCount;
  }
  
  Future<void> deleteSighting(String id) async {
    await _sightingRepository.deleteSighting(id);
  }
  
  // ==========================================
  // REPORTED POSTS ACTIONS
  // ==========================================
  
  Future<void> archiveReportedPost(String postId) async {
    await _communityRepository.archivePost(postId);
  }
  
  Future<void> dismissReport(String postId) async {
    await _communityRepository.dismissReport(postId);
  }
  
  // ==========================================
  // FISH MANAGEMENT
  // ==========================================
  
  void setShowArchivedFish(bool show) {
    _showArchivedFish = show;
    notifyListeners();
  }
  
  void setFishSearchQuery(String query) {
    _fishSearchQuery = query;
    _applyFishFilter();
    notifyListeners();
  }
  
  void setFishHabitatFilter(String habitat) {
    _fishHabitatFilter = habitat;
    _applyFishFilter();
    notifyListeners();
  }
  
  void setFishSortMode(String mode) {
    _fishSortMode = mode;
    _applyFishFilter();
    notifyListeners();
  }
  
  void _applyFishFilter() {
    // Filtering is done in UI for now since it's client-side
    // The UI will call getFilteredFishList()
    notifyListeners();
  }
  
  List<Fish> getFilteredFishList() {
    List<Fish> source = _showArchivedFish ? [] : _fishCatalog;
    
    // Apply search
    if (_fishSearchQuery.isNotEmpty) {
      source = _fishRepository.searchFish(source, _fishSearchQuery);
    }
    
    // Apply habitat filter
    if (_fishHabitatFilter != 'All') {
      source = _fishRepository.filterByHabitat(source, _fishHabitatFilter);
    }
    
    // Apply sort
    if (_fishSortMode == 'Fish ID') {
      source.sort((a, b) {
        final aNum = _extractFishNumber(a.fishId);
        final bNum = _extractFishNumber(b.fishId);
        return aNum.compareTo(bNum);
      });
    } else {
      source.sort((a, b) => a.commonName.compareTo(b.commonName));
    }
    
    return source;
  }
  
  int _extractFishNumber(String fishId) {
    final match = RegExp(r'^fish_(\d+)$').firstMatch(fishId);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }
  
  String getNextFishId() {
    final Set<int> used = {};
    for (final fish in _fishCatalog) {
      final num = _extractFishNumber(fish.fishId);
      if (num > 0) used.add(num);
    }
    int next = 1;
    while (used.contains(next)) next++;
    return 'fish_$next';
  }
  
  Future<String?> addFish(Fish fish) async {
    try {
      await _fishRepository.addFish(fish);
      return fish.fishId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  Future<bool> updateFish(String key, Fish fish) async {
    try {
      await _fishRepository.updateFish(key, fish);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> archiveFish(String key) async {
    _isProcessing = true;
    notifyListeners();
    
    final success = await _fishRepository.archiveFish(key, _authRepository.currentUser?.uid ?? '');
    
    _isProcessing = false;
    if (!success && _error == null) {
      _error = 'Cannot archive: fish is referenced in sightings or map pins.';
    }
    notifyListeners();
    
    return success;
  }
  
  Future<bool> restoreFish(String key) async {
    _isProcessing = true;
    notifyListeners();
    
    final success = await _fishRepository.restoreFish(key);
    
    _isProcessing = false;
    notifyListeners();
    
    return success;
  }
  
  Future<bool> deleteFish(String key) async {
    _isProcessing = true;
    notifyListeners();
    
    final success = await _fishRepository.deleteFish(key);
    
    _isProcessing = false;
    if (!success && _error == null) {
      _error = 'Cannot delete: fish is referenced in sightings or map pins.';
    }
    notifyListeners();
    
    return success;
  }
  
  Future<Fish?> getFishByKey(String key) async {
    return await _fishRepository.getFishByKey(key);
  }
  
  // ==========================================
  // USER MANAGEMENT
  // ==========================================
  
  Future<void> refreshUsers() async {
    await _loadUsers();
    notifyListeners();
  }
  
  Future<void> updateUserRole(String uid, String newRole) async {
    await _authRepository.updateUserRole(uid, newRole);
    await _loadUsers();
    notifyListeners();
  }
  
  // ==========================================
  // UTILITIES
  // ==========================================
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  String formatArchiveDate(dynamic raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw).toLocal().toString().split('.').first;
    }
    return 'N/A';
  }
}