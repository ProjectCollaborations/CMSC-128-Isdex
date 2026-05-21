import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../viewmodels/admin_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/fish_catalog_viewmodel.dart';
import '../repositories/community_repository.dart';
import '../repositories/fish_repository.dart';
import '../repositories/sighting_repository.dart';
import '../repositories/user_repository.dart';
import '../views/catalog/landing_screen.dart';
import '../views/catalog/fish_detail_screen.dart';
import '../views/catalog/fish_image_search_screen.dart';
import '../views/map/map_screen.dart';
import '../views/sighting/user_sightings_map_screen.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/signup_screen.dart';
import '../views/auth/splash_screen.dart';
import '../views/community/community_screen.dart';
import '../views/community/comments_screen.dart';
import '../views/admin/admin_screen.dart';
import '../views/chat/chat_screen.dart';

GoRouter createRouter(AuthViewModel authVm) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authVm,
    redirect: (context, state) {
      final vm = context.read<AuthViewModel>();
      final isInitializing = !vm.isInitialized;
      final loggedIn = vm.isLoggedIn;
      final onLogin = state.matchedLocation == '/login';
      final onSignup = state.matchedLocation == '/signup';
      final onAuthRoute = onLogin || onSignup;

      if (isInitializing) return '/splash';

      if (!loggedIn && !onAuthRoute) return '/login';
      if (loggedIn && onAuthRoute) return '/';

      final onAdmin = state.matchedLocation == '/admin';
      if (onAdmin) {
        final role = context.read<AuthViewModel>().userRole;
        if (role != 'admin' && role != 'mod') return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/fish/:id',
        builder: (context, state) {
          final fishId = state.pathParameters['id']!;
          return FishDetailScreen(fishId: fishId);
        },
      ),
      GoRoute(
        path: '/fish-search',
        builder: (context, state) {
          final allFish = context.read<FishCatalogViewModel>().allFish;
          return FishImageSearchScreen(allSpecies: allFish);
        },
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MapScreen(
            fishId: extra?['fishId'] as String?,
            fishName: extra?['fishName'] as String?,
            latitude: extra?['latitude'] as double?,
            longitude: extra?['longitude'] as double?,
          );
        },
      ),
      GoRoute(
        path: '/sighting',
        builder: (context, state) => const UserSightingsMapScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/comments/:postId',
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return CommentsScreen(postId: postId);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => ChangeNotifierProvider(
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
          child: const AdminScreen(),
        ),
      ),
    ],
  );
}
