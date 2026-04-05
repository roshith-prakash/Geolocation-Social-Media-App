import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => AuthWrapperState();
}
class AuthWrapperState extends State<AuthWrapper> {
  final authService = AuthService();
  StreamSubscription<User?>? authSubscription;

  bool isLoading = true;
  String? errorMessage;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    authSubscription = authService.authStateChanges.listen(handleAuthChange);
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  Future<void> handleAuthChange(User? user) async {
    if (!mounted) return;

    if (user == null) {
      setState(() {
        currentUser = null;
        isLoading = false;
        errorMessage = null;
      });
      return;
    }

    setState(() {
      currentUser = user;
      isLoading = true;
      errorMessage = null;
    });

    try {
      await authService.ensureSupabaseProfile();
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingScreen();

    if (errorMessage != null) {
      return ErrorScreen(
        error: errorMessage!,
        onRetry: () => handleAuthChange(currentUser),
        onSignOut: () => authService.signOut(),
      );
    }

    if (currentUser != null) return const HomeScreen();

    return const LoginScreen();
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load profile', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(onPressed: onSignOut, child: const Text('Sign Out')),
          ],
        ),
      ),
    );
  }
}
