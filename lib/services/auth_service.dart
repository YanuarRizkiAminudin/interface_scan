import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Google Sign-In and Firebase Auth.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  /// Current signed-in user. Null if not signed in.
  static User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in with Google. Returns the [User] on success, null on cancel.
  static Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (_) {
      return null;
    }
  }

  /// Signs out from both Firebase and Google.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
