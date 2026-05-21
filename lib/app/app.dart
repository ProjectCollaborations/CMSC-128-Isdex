import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/fish_repository.dart';
import '../repositories/sighting_repository.dart';
import '../repositories/community_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/map_repository.dart';
import '../services/auth_service.dart';
import '../viewmodels/admin_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/community_viewmodel.dart';
import '../viewmodels/fish_catalog_viewmodel.dart';
import '../viewmodels/fish_detail_viewmodel.dart';
import 'router.dart';

class IsDexApp extends StatefulWidget {
  const IsDexApp({super.key});

  @override
  State<IsDexApp> createState() => _IsDexAppState();
}

class _IsDexAppState extends State<IsDexApp> {
  late final DatabaseReference _db;
  late final AuthRepository _authRepo;
  late final AuthViewModel _authVm;

  @override
  void initState() {
    super.initState();
    _db = FirebaseDatabase.instance.ref();
    _authRepo = AuthRepository(AuthService(_db), _db);
    _authVm = AuthViewModel(_authRepo);
  }

  @override
  void dispose() {
    _authVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: _authRepo),
        Provider(create: (_) => FishRepository(_db)),
        Provider(create: (_) => SightingRepository(_db)),
        Provider(create: (_) => CommunityRepository(_db)),
        Provider(create: (_) => ChatRepository(_db)),
        Provider(create: (_) => UserRepository(_db)),
        Provider(create: (_) => MapRepository(_db)),
        ChangeNotifierProvider<AuthViewModel>.value(value: _authVm),
        ChangeNotifierProvider(
          create: (ctx) => FishCatalogViewModel(
            () => ctx.read<FishRepository>().watchAll(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => FishDetailViewModel(
            (id) => ctx.read<FishRepository>().getById(id),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChatViewModel(
            watchMessages: (uid) => ctx.read<ChatRepository>().watchMessages(uid),
            addMessage: (uid, {required role, required content}) =>
                ctx.read<ChatRepository>().addMessage(uid, role: role, content: content),
            addModelMessage: (uid, {required content}) =>
                ctx.read<ChatRepository>().addModelMessage(uid, content: content),
            clearHistory: (uid) => ctx.read<ChatRepository>().clearHistory(uid),
            currentUserId: () => ctx.read<AuthViewModel>().user?.uid,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => CommunityViewModel(
            watchPosts: () => ctx.read<CommunityRepository>().watchPosts(),
            watchComments: (postId) => ctx.read<CommunityRepository>().watchComments(postId),
            addPost: ({required uid, required username, required caption, required imageBase64}) =>
                ctx.read<CommunityRepository>().addPost(uid: uid, username: username, caption: caption, imageBase64: imageBase64),
            toggleLike: (postId, uid) => ctx.read<CommunityRepository>().toggleLike(postId, uid),
            isLikedBy: (postId, uid) => ctx.read<CommunityRepository>().isLikedBy(postId, uid),
            reportPost: (postId) => ctx.read<CommunityRepository>().reportPost(postId),
            deletePost: (postId) => ctx.read<CommunityRepository>().deletePost(postId),
            currentUserId: () => ctx.read<AuthViewModel>().user?.uid,
            currentUserDisplay: () => ctx.read<AuthViewModel>().user?.username ?? ctx.read<AuthViewModel>().user?.email ?? '',
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final vm = AdminViewModel(
              authViewModel: ctx.read<AuthViewModel>(),
              watchAllSightings: () => ctx.read<SightingRepository>().watchAll(),
              updateSightingStatus: (id, status) =>
                  ctx.read<SightingRepository>().updateStatus(id, status),
              deleteSighting: (id) =>
                  ctx.read<SightingRepository>().delete(id),
              watchReportedPosts: () =>
                  ctx.read<CommunityRepository>().watchReportedPosts(),
              dismissReport: (postId) =>
                  ctx.read<CommunityRepository>().dismissReport(postId),
              archivePost: (postId) =>
                  ctx.read<CommunityRepository>().archivePost(postId),
              watchFishCatalog: () =>
                  ctx.read<FishRepository>().watchAll(),
              watchArchivedFish: () =>
                  ctx.read<FishRepository>().watchArchive(),
              addFish: (fish) =>
                  ctx.read<FishRepository>().add(fish),
              updateFish: (fish) =>
                  ctx.read<FishRepository>().update(fish),
              archiveFish: (id) =>
                  ctx.read<FishRepository>().archive(id),
              restoreFish: (id) =>
                  ctx.read<FishRepository>().restore(id),
              hardDeleteFish: (id, {fromArchive = false}) =>
                  ctx.read<FishRepository>().hardDelete(id, fromArchive: fromArchive),
              watchUsers: () =>
                  ctx.read<UserRepository>().watchAll(),
              updateUserRole: (uid, role) =>
                  ctx.read<UserRepository>().updateRole(uid, role),
              allFishSnapshot: () =>
                  ctx.read<FishRepository>().watchAll().first,
            );
            vm.init();
            return vm;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'IsDex',
        routerConfig: createRouter(_authVm),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
