import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  final authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder(
            future: authService.ensureSupabaseProfile(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (profileSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Failed to load profile', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(profileSnapshot.error.toString(), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () => authService.signOut(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const HomeScreen();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
