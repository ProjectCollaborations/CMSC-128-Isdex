import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_theme.dart';
import '../repositories/auth_repository.dart';
import '../repositories/fish_repository.dart';
import '../repositories/sighting_repository.dart';
import '../repositories/community_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/map_repository.dart';
import '../services/auth_service.dart';
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
          create: (ctx) =>
              FishCatalogViewModel(() => ctx.read<FishRepository>().watchAll()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => FishDetailViewModel(
            (id) => ctx.read<FishRepository>().getById(id),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChatViewModel(
            watchMessages: (uid) =>
                ctx.read<ChatRepository>().watchMessages(uid),
            addMessage: (uid, {required role, required content}) => ctx
                .read<ChatRepository>()
                .addMessage(uid, role: role, content: content),
            addModelMessage: (uid, {required content}) => ctx
                .read<ChatRepository>()
                .addModelMessage(uid, content: content),
            clearHistory: (uid) => ctx.read<ChatRepository>().clearHistory(uid),
            currentUserId: () => ctx.read<AuthViewModel>().user?.uid,
          ),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, CommunityViewModel>(
          create: (ctx) => CommunityViewModel(
            watchPosts: () => ctx.read<CommunityRepository>().watchPosts(),
            watchComments: (postId) =>
                ctx.read<CommunityRepository>().watchComments(postId),
            addPost:
                ({
                  required uid,
                  required username,
                  required caption,
                  required imageBase64,
                }) => ctx.read<CommunityRepository>().addPost(
                  uid: uid,
                  username: username,
                  caption: caption,
                  imageBase64: imageBase64,
                ),
            toggleLike: (postId, uid) =>
                ctx.read<CommunityRepository>().toggleLike(postId, uid),
            isLikedBy: (postId, uid) =>
                ctx.read<CommunityRepository>().isLikedBy(postId, uid),
            reportPost: (postId) =>
                ctx.read<CommunityRepository>().reportPost(postId),
            deletePost: (postId) =>
                ctx.read<CommunityRepository>().deletePost(postId),
            currentUserId: () => ctx.read<AuthViewModel>().user?.uid,
            currentUserDisplay: () =>
                ctx.read<AuthViewModel>().user?.username ??
                ctx.read<AuthViewModel>().user?.email ??
                '',
          ),
          update: (_, auth, vm) {
            vm!.handleCurrentUserChanged(auth.user?.uid);
            return vm;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'IsDex',
        theme: AppTheme.light,
        routerConfig: createRouter(_authVm),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
