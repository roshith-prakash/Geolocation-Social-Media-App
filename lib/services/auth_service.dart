import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SupabaseService _supabaseService = SupabaseService();

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Ensure a Supabase profile exists for the current Firebase user.
  /// Called by AuthWrapper after detecting a logged-in Firebase user.
  Future<void> ensureSupabaseProfile() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    final existing =
        await _supabaseService.getUserByFirebaseUid(firebaseUser.uid);

    if (existing == null) {
      // Create a new Supabase profile
      await _supabaseService.createUser(
        firebaseUid: firebaseUser.uid,
        username:
            firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
        email: firebaseUser.email!,
        profileImage: firebaseUser.photoURL,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
