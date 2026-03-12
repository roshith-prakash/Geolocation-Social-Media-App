import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';


  // Default radius for nearby posts (in meters)
  static const double defaultRadiusMeters = 1000.0;

  // Supabase table names
  static const String usersTable = 'users';
  static const String postsTable = 'posts';
  static const String followersTable = 'followers';

  // Supabase storage bucket
  static const String postImagesBucket = 'post-images';
}
