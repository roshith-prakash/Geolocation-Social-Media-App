import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final SupabaseService supabaseService = SupabaseService();

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Current Firebase user
  User? get currentUser => auth.currentUser;

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await auth.signInWithCredential(credential);
  }

  /// Ensure a Supabase profile exists for the current Firebase user.
  /// Called by AuthWrapper after detecting a logged-in Firebase user.
  Future<void> ensureSupabaseProfile() async {
    final firebaseUser = auth.currentUser;
    if (firebaseUser == null) return;

    final existing =
        await supabaseService.getUserByFirebaseUid(firebaseUser.uid);

    if (existing == null) {
      // Create a new Supabase profile
      await supabaseService.createUser(
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
    await googleSignIn.signOut();
    await auth.signOut();
  }
}
