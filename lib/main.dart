import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/theme.dart';
import 'utils/constants.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const FlashMapApp());
}

class FlashMapApp extends StatelessWidget {
  const FlashMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashMap Social',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

/// Decides whether to show login or home based on Firebase auth state.
/// Also ensures a Supabase user profile exists before showing HomeScreen.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // User is logged in — ensure Supabase profile exists
        if (snapshot.hasData) {
          return FutureBuilder(
            future: _authService.ensureSupabaseProfile(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              if (profileSnapshot.hasError) {
                return _buildErrorScreen(profileSnapshot.error.toString());
              }

              return const HomeScreen();
            },
          );
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: const Icon(
                Icons.explore,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppTheme.accentCyan),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppTheme.accentOrange),
              const SizedBox(height: 16),
              const Text(
                'Failed to load profile',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _authService.signOut(),
                child: const Text('Sign Out',
                    style: TextStyle(color: AppTheme.accentPink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
