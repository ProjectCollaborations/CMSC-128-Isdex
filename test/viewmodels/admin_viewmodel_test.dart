import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/sighting.dart';
import 'package:isdex/models/community_post.dart';
import 'package:isdex/models/fish.dart';
import 'package:isdex/models/app_user.dart';
import 'package:isdex/viewmodels/auth_viewmodel.dart';
import 'package:isdex/viewmodels/admin_viewmodel.dart';

class MockAuthViewModel extends ChangeNotifier implements AuthViewModel {
  @override
  String userRole;
  @override
  AppUser? user;
  @override
  bool isLoggedIn = true;
  @override
  bool isInitialized = true;
  @override
  String? error;
  @override
  bool isLoading = false;

  MockAuthViewModel({this.userRole = 'admin', this.user});

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password, String username) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<bool> isEmailRegistered(String email) async => false;
}

void main() {
  late StreamController<List<Sighting>> sightingsController;
  late StreamController<List<CommunityPost>> reportedPostsController;
  late StreamController<List<Fish>> fishCatalogController;
  late StreamController<List<Fish>> archivedFishController;
  late StreamController<List<AppUser>> usersController;
  AdminViewModel? vm;

  // ── Test fixture constants ──
  final fish1 = Fish(
    id: 'fish1',
    commonName: 'Clownfish',
    scientificName: 'Amphiprion ocellaris',
    localName: 'Palay',
    habitat: 'Marine',
    sizeRange: '10-15 cm',
    identifyingFeatures: ['Orange with white stripes'],
    imageUrl: '',
    conservationStatus: 'Least Concern',
    conservationDetails: '',
    distribution: 'Indo-Pacific',
  );

  final fish2 = Fish(
    id: 'fish2',
    commonName: 'Bangus',
    scientificName: 'Chanos chanos',
    localName: 'Bangus',
    habitat: 'Freshwater',
    sizeRange: '30-60 cm',
    identifyingFeatures: ['Silver body'],
    imageUrl: '',
    conservationStatus: 'Least Concern',
    conservationDetails: '',
    distribution: 'Philippines',
  );

  final fish3 = Fish(
    id: 'fish3',
    commonName: 'Tilapia',
    scientificName: 'Oreochromis niloticus',
    localName: 'Tilapia',
    habitat: 'Freshwater',
    sizeRange: '20-40 cm',
    identifyingFeatures: ['Compressed body'],
    imageUrl: '',
    conservationStatus: 'Least Concern',
    conservationDetails: '',
    distribution: 'Africa, introduced globally',
  );

  final sightingPending = Sighting(
    id: 's1',
    fishName: 'Clownfish',
    fishId: 'fish1',
    displayName: 'User1',
    userId: 'u1',
    notes: 'Saw near reef',
    latitude: 14.5,
    longitude: 121.0,
    createdAt: '0',
    status: SightingStatus.pending,
    isAnonymous: false,
    geoValidationStatus: 'water',
    geoValidationMessage: '',
  );

  final sightingBadLat = Sighting(
    id: 's2',
    fishName: 'Clownfish',
    fishId: 'fish1',
    displayName: 'User2',
    userId: 'u2',
    notes: '',
    latitude: 91.0,
    longitude: 121.0,
    createdAt: '0',
    status: SightingStatus.pending,
    isAnonymous: false,
    geoValidationStatus: 'water',
    geoValidationMessage: '',
  );

  final sightingNonWater = Sighting(
    id: 's3',
    fishName: 'Bangus',
    fishId: 'fish3',
    displayName: 'User3',
    userId: 'u3',
    notes: '',
    latitude: 14.5,
    longitude: 121.0,
    createdAt: '0',
    status: SightingStatus.pending,
    isAnonymous: false,
    geoValidationStatus: 'land',
    geoValidationMessage: 'GPS coordinate maps to land area',
  );

  final post1 = CommunityPost(
    id: 'p1',
    uid: 'u1',
    username: 'User1',
    caption: 'Reported post 1',
    imageBase64: '',
    likes: 0,
    timePosted: 1000,
    isReported: true,
    status: 'active',
  );

  final post2 = CommunityPost(
    id: 'p2',
    uid: 'u2',
    username: 'User2',
    caption: 'Reported post 2',
    imageBase64: '',
    likes: 5,
    timePosted: 2000,
    isReported: true,
    status: 'active',
  );

  final adminUser = AppUser(
    uid: 'admin1',
    username: 'admin',
    email: '__TEST_EMAIL_admin_test__',
    role: 'admin',
    createdAt: '0',
  );

  final modUser = AppUser(
    uid: 'mod1',
    username: 'moderator',
    email: '__TEST_EMAIL_mod_test__',
    role: 'mod',
    createdAt: '0',
  );

  final regularUser = AppUser(
    uid: 'user1',
    username: 'user',
    email: '__TEST_EMAIL_user_test__',
    role: 'user',
    createdAt: '0',
  );

  AdminViewModel createVm({String role = 'admin', AppUser? authUser}) {
    return AdminViewModel(
      authViewModel: MockAuthViewModel(userRole: role, user: authUser),
      watchAllSightings: () => sightingsController.stream,
      updateSightingStatus: (id, status) async {},
      deleteSighting: (id) async {},
      watchReportedPosts: () => reportedPostsController.stream,
      dismissReport: (postId) async {},
      archivePost: (postId) async {},
      watchFishCatalog: () => fishCatalogController.stream,
      watchArchivedFish: () => archivedFishController.stream,
      addFish: (fish) async {},
      updateFish: (fish) async {},
      archiveFish: (id) async {},
      restoreFish: (id) async {},
      hardDeleteFish: (id, {fromArchive = false}) async {},
      watchUsers: () => usersController.stream,
      updateUserRole: (uid, role) async {},
      allFishSnapshot: () async => [fish1, fish2, fish3],
    );
  }

  setUp(() {
    sightingsController = StreamController<List<Sighting>>.broadcast();
    reportedPostsController = StreamController<List<CommunityPost>>.broadcast();
    fishCatalogController = StreamController<List<Fish>>.broadcast();
    archivedFishController = StreamController<List<Fish>>.broadcast();
    usersController = StreamController<List<AppUser>>.broadcast();
    vm = null;
  });

  tearDown(() async {
    vm?.dispose();
    await sightingsController.close();
    await reportedPostsController.close();
    await fishCatalogController.close();
    await archivedFishController.close();
    await usersController.close();
  });

  // ─────────────────────────────────────────────
  // Gate
  // ─────────────────────────────────────────────
  group('AdminViewModel - Gate', () {
    test('1. Loading state before init', () {
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      expect(vm!.isInitialized, false);
    });

    test('2. User role user', () async {
      vm = createVm(role: 'user');
      await vm!.init();
      expect(vm!.isInitialized, true);
      expect(vm!.isModerator, false);
      expect(vm!.showUsersTab, false);
      expect(vm!.visibleTabs, 3);
    });

    test('3. User role mod', () async {
      vm = createVm(role: 'mod');
      await vm!.init();
      expect(vm!.isInitialized, true);
      expect(vm!.isModerator, true);
      expect(vm!.showUsersTab, false);
      expect(vm!.visibleTabs, 3);
    });

    test('4. User role admin', () async {
      vm = createVm(role: 'admin');
      await vm!.init();
      expect(vm!.isInitialized, true);
      expect(vm!.isAdmin, true);
      expect(vm!.showUsersTab, true);
      expect(vm!.visibleTabs, 4);
    });

    test('5. Init idempotency', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      fishCatalogController.add([fish1]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm!.fishCatalog, [fish1]);

      await vm!.init();

      fishCatalogController.add([fish1, fish2]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm!.fishCatalog, [fish1, fish2]);
    });
  });

  // ─────────────────────────────────────────────
  // Sightings
  // ─────────────────────────────────────────────
  group('AdminViewModel - Sightings', () {
    test('6. Stream populates sightings', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      sightingsController.add([sightingPending, sightingBadLat]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm!.sightings.length, 2);
      expect(vm!.sightingsLoading, false);
    });

    test('7. Select/deselect individual', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      sightingsController.add([sightingPending, sightingBadLat]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.toggleSelected('s1');
      expect(vm!.selectedIds, {'s1'});

      vm!.toggleSelected('s1');
      expect(vm!.selectedIds, <String>{});
    });

    test('8. Select all and clear', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      sightingsController.add([sightingPending, sightingBadLat]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.selectAll();
      expect(vm!.selectedIds, {'s1', 's2'});

      vm!.clearSelection();
      expect(vm!.selectedIds, <String>{});
    });

    test('9. Approve selected', () async {
      String? approvedId;
      SightingStatus? approvedStatus;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {
          approvedId = id;
          approvedStatus = status;
        },
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      sightingsController.add([sightingPending]);
      fishCatalogController.add([fish1]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.selectAll();
      await vm!.approveSelected();

      expect(approvedId, 's1');
      expect(approvedStatus, SightingStatus.approved);
      expect(vm!.isProcessing, false);
    });

    test('10. Archive selected', () async {
      String? archivedId;
      SightingStatus? archivedStatus;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {
          archivedId = id;
          archivedStatus = status;
        },
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      sightingsController.add([sightingPending]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.selectAll();
      await vm!.archiveSelected();

      expect(archivedId, 's1');
      expect(archivedStatus, SightingStatus.rejected);
      expect(vm!.isProcessing, false);
    });

    test('11. Delete single sighting', () async {
      String? deletedId;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {
          deletedId = id;
        },
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();
      await vm!.deleteSighting('s1');
      expect(deletedId, 's1');
      expect(vm!.isProcessing, false);
    });

    test('12. Approval validation errors', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      final knownIds = <String>{'fish1', 'fish2'};

      final missingFishId = sightingPending.copyWith(fishId: '');
      final errorsEmpty = vm!.approvalValidationErrors(missingFishId, knownIds);
      expect(errorsEmpty, contains('Missing fish ID'));

      final unknownFish = sightingPending.copyWith(fishId: 'nonexistent');
      final errorsUnknown = vm!.approvalValidationErrors(unknownFish, knownIds);
      expect(errorsUnknown, contains('Fish ID does not exist in catalog'));

      final badLat = sightingPending.copyWith(latitude: 91.0);
      final errorsLat = vm!.approvalValidationErrors(badLat, knownIds);
      expect(errorsLat, contains('Invalid latitude'));

      final badLng = sightingPending.copyWith(longitude: 181.0);
      final errorsLng = vm!.approvalValidationErrors(badLng, knownIds);
      expect(errorsLng, contains('Invalid longitude'));

      final nonWater = sightingPending.copyWith(
        geoValidationStatus: 'land',
        geoValidationMessage: 'Not on water',
      );
      final errorsGeo = vm!.approvalValidationErrors(nonWater, knownIds);
      expect(errorsGeo, anyElement(contains('Location validation failed')));
    });
  });

  // ─────────────────────────────────────────────
  // Reports
  // ─────────────────────────────────────────────
  group('AdminViewModel - Reports', () {
    test('13. Stream populates reported posts', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      reportedPostsController.add([post1, post2]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm!.reportedPosts.length, 2);
    });

    test('14. Dismiss report', () async {
      String? dismissedId;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {
          dismissedId = postId;
        },
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.dismissReport('p1');
      expect(dismissedId, 'p1');
      expect(vm!.isProcessing, false);
    });

    test('15. Archive reported post', () async {
      String? archivedPostId;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {
          archivedPostId = postId;
        },
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.archiveReportedPost('p2');
      expect(archivedPostId, 'p2');
      expect(vm!.isProcessing, false);
    });
  });

  // ─────────────────────────────────────────────
  // Fish CRUD
  // ─────────────────────────────────────────────
  group('AdminViewModel - Fish CRUD', () {
    test('16. Add fish', () async {
      Fish? addedFish;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {
          addedFish = fish;
        },
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.addFish(fish1);
      expect(addedFish, fish1);
      expect(vm!.fishProcessing, false);
    });

    test('17. Update fish', () async {
      Fish? updatedFish;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {
          updatedFish = fish;
        },
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.updateFish(fish2);
      expect(updatedFish, fish2);
      expect(vm!.fishProcessing, false);
    });

    test('18. Archive fish', () async {
      String? archivedFishId;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {
          archivedFishId = id;
        },
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      sightingsController.add(<Sighting>[]);
      await Future.delayed(const Duration(milliseconds: 50));

      await vm!.archiveFish('fish1');
      expect(archivedFishId, 'fish1');
      expect(vm!.fishProcessing, false);
    });

    test('19. Restore fish', () async {
      String? restoredId;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {
          restoredId = id;
        },
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.restoreFish('fish1');
      expect(restoredId, 'fish1');
      expect(vm!.fishProcessing, false);
    });

    test('20. Hard delete', () async {
      String? deletedId;
      bool? fromArchiveResult;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {bool fromArchive = false}) async {
          deletedId = id;
          fromArchiveResult = fromArchive;
        },
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.hardDeleteFish('fish1', fromArchive: true);
      expect(deletedId, 'fish1');
      expect(fromArchiveResult, true);
      expect(vm!.fishProcessing, false);
    });

    test('21. Archive referenced fish throws', () async {
      bool archiveFishCalled = false;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin'),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {
          archiveFishCalled = true;
        },
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {},
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      sightingsController.add([sightingPending]);
      await Future.delayed(const Duration(milliseconds: 50));

      await expectLater(
        vm!.archiveFish('fish1'),
        throwsA(isA<Exception>()),
      );
      expect(archiveFishCalled, false);
      expect(vm!.fishProcessing, false);
    });

    test('22. Set search query', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      fishCatalogController.add([fish1, fish2, fish3]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.setSearchQuery('Clown');
      expect(vm!.searchQuery, 'Clown');
      expect(vm!.filteredFish.length, 1);
      expect(vm!.filteredFish.first.id, 'fish1');

      vm!.setSearchQuery('BANGUS');
      expect(vm!.filteredFish.length, 1);
      expect(vm!.filteredFish.first.id, 'fish2');
    });

    test('23. Set habitat filter', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      fishCatalogController.add([fish1, fish2, fish3]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.setHabitatFilter('Marine');
      expect(vm!.habitatFilter, 'Marine');
      expect(vm!.filteredFish.length, 1);
      expect(vm!.filteredFish.first.id, 'fish1');

      vm!.setHabitatFilter('Freshwater');
      expect(vm!.filteredFish.length, 2);
    });

    test('24. Set sort mode', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      fishCatalogController.add([fish1, fish2, fish3]);
      await Future.delayed(const Duration(milliseconds: 50));

      vm!.setSortMode('Name (Z-A)');
      expect(vm!.sortMode, 'Name (Z-A)');
      expect(vm!.filteredFish.first.commonName, 'Tilapia');

      vm!.setSortMode('Scientific Name');
      expect(vm!.filteredFish.first.scientificName, 'Amphiprion ocellaris');
    });

    test('25. Toggle showArchived', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      fishCatalogController.add([fish1, fish2]);
      archivedFishController.add([fish3]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm!.showArchivedFish, false);
      expect(vm!.filteredFish.length, 2);

      vm!.toggleShowArchived();
      expect(vm!.showArchivedFish, true);
      expect(vm!.filteredFish.length, 1);
      expect(vm!.filteredFish.first.id, 'fish3');

      vm!.toggleShowArchived();
      expect(vm!.showArchivedFish, false);
      expect(vm!.filteredFish.length, 2);
    });
  });

  // ─────────────────────────────────────────────
  // Users
  // ─────────────────────────────────────────────
  group('AdminViewModel - Users', () {
    test('26. Stream populates users', () async {
      vm = createVm(role: 'admin');
      await vm!.init();

      usersController.add([adminUser, modUser, regularUser]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm!.users.length, 3);
      expect(vm!.usersProcessing, false);
    });

    test('27. Update user role', () async {
      String? updatedUid;
      String? updatedRole;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin', user: adminUser),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {
          updatedUid = uid;
          updatedRole = role;
        },
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.updateUserRole('mod1', 'mod');
      expect(updatedUid, 'mod1');
      expect(updatedRole, 'mod');
      expect(vm!.usersProcessing, false);
    });

    test('28. Cannot update own role', () async {
      bool updateUserRoleCalled = false;
      vm = AdminViewModel(
        authViewModel: MockAuthViewModel(userRole: 'admin', user: adminUser),
        watchAllSightings: () => sightingsController.stream,
        updateSightingStatus: (id, status) async {},
        deleteSighting: (id) async {},
        watchReportedPosts: () => reportedPostsController.stream,
        dismissReport: (postId) async {},
        archivePost: (postId) async {},
        watchFishCatalog: () => fishCatalogController.stream,
        watchArchivedFish: () => archivedFishController.stream,
        addFish: (fish) async {},
        updateFish: (fish) async {},
        archiveFish: (id) async {},
        restoreFish: (id) async {},
        hardDeleteFish: (id, {fromArchive = false}) async {},
        watchUsers: () => usersController.stream,
        updateUserRole: (uid, role) async {
          updateUserRoleCalled = true;
        },
        allFishSnapshot: () async => [fish1, fish2, fish3],
      );
      await vm!.init();

      await vm!.updateUserRole('admin1', 'user');
      expect(updateUserRoleCalled, false);
    });
  });

  // ─────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────
  group('AdminViewModel - Dispose', () {
    test('29. Dispose cancels subscriptions', () async {
      vm = createVm(role: 'admin');
      await vm!.init();
      await Future.delayed(const Duration(milliseconds: 50));

      int notifyCount = 0;
      vm!.addListener(() {
        notifyCount++;
      });

      vm!.dispose();
      final disposedVm = vm;
      vm = null;
      notifyCount = 0;

      fishCatalogController.add([fish1]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(disposedVm!.fishCatalog, isEmpty);
    });
  });
}
