import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/single_child_widget.dart';
import '../../data/datasources/firebase_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/fish_repository_impl.dart';
import '../../data/repositories/sighting_repository_impl.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/fish_catalog_viewmodel.dart';
import '../../viewmodels/sighting_viewmodel.dart';
import '../../viewmodels/community_viewmodel.dart';
import '../../viewmodels/map_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'package:provider/provider.dart';

/// Global provider setup for the entire app.
class AppProviders {
  AppProviders._();

  /// List of all providers to be used in MultiProvider.
  static List<SingleChildWidget> get all {
    // Singleton instances
    final database = FirebaseDatabase.instance;
    final dataSource = FirebaseDataSource(database);
    
    // Repositories
    final authRepository = AuthRepositoryImpl(dataSource);
    final fishRepository = FishRepositoryImpl(dataSource);
    final sightingRepository = SightingRepositoryImpl(dataSource, fishRepository);
    final communityRepository = CommunityRepositoryImpl(dataSource);
    
    // ViewModels
    final authViewModel = AuthViewModel(authRepository);
    final fishCatalogViewModel = FishCatalogViewModel(fishRepository);
    final sightingViewModel = SightingViewModel(sightingRepository);
    final communityViewModel = CommunityViewModel(communityRepository);
    final mapViewModel = MapViewModel(sightingRepository, fishRepository);
    final adminViewModel = AdminViewModel(
      sightingRepository,
      communityRepository,
      fishRepository,
      authRepository,
    );
    
    return [
      ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
      ChangeNotifierProvider<FishCatalogViewModel>.value(value: fishCatalogViewModel),
      ChangeNotifierProvider<SightingViewModel>.value(value: sightingViewModel),
      ChangeNotifierProvider<CommunityViewModel>.value(value: communityViewModel),
      ChangeNotifierProvider<MapViewModel>.value(value: mapViewModel),
      ChangeNotifierProvider<AdminViewModel>.value(value: adminViewModel),
    ];
  }
}