// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'landing_page.dart';
import 'login_page.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. Still checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. User is NOT logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage(); 
        }

        // 3. User IS logged in. Let's check their role!
        return FutureBuilder<String?>(
          future: _authService.getUserRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            
            // Waiting for the database to return the role
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final role = roleSnapshot.data ?? 'user';

            // 4. Route Admins and Mods to the Web Dashboard
            if (role == 'admin' || role == 'mod') {
              return const AdminDashboardPage();
            } // <-- THIS WAS THE MISSING BRACE!

            // 5. Route standard users to the normal app
            return const LandingPage();
          },
        );
      },
    );
  }
}