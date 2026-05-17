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
import '../viewmodels/auth_viewmodel.dart';
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
    _authRepo = AuthRepository(AuthService(), _db);
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
      ],
      child: MaterialApp.router(
        title: 'IsDex',
        routerConfig: createRouter(_authVm),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
