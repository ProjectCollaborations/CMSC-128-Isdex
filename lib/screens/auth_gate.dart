import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'landing_page.dart';
import 'login_page.dart';
import 'admin_dashboard_page.dart';
import '../viewmodels/auth_viewmodel.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    // Still loading
    if (authVm.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // User is NOT logged in
    if (user == null) {
      return const LoginPage();
    }

    // User IS logged in. Check their role
    return FutureBuilder<String?>(
      future: authVm.getUserRole(user.uid),
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = roleSnapshot.data ?? 'user';

        // Route Admins and Mods to the Admin Dashboard
        if (role == 'admin' || role == 'mod') {
          return const AdminDashboardPage();
        }

        // Standard users go to the main app
        return const LandingPage();
      },
    );
  }
}