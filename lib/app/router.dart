import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../screens/landing_page.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/signup_screen.dart';
import '../views/auth/splash_screen.dart';

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
        builder: (context, state) => const LandingPage(),
      ),
    ],
  );
}
