import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository(this._firebaseAuth);

  Stream<User?> get authStateChanges async* {
    if (_firebaseAuth.currentUser != null) {
      yield _firebaseAuth.currentUser;
    }
    yield* _firebaseAuth.authStateChanges();
  }

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        return await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        final googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled the sign-in flow
          return null;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _firebaseAuth.signInWithCredential(credential);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}
    await _firebaseAuth.signOut();
  }

  Future<void> deleteCurrentUserAccount({String? currentPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception("No user logged in");

    try {
      if (currentPassword != null && currentPassword.isNotEmpty && user.email != null) {
        try {
          final cred = EmailAuthProvider.credential(
            email: user.email!,
            password: currentPassword,
          );
          await user.reauthenticateWithCredential(cred);
        } catch (e) {
          final err = e.toString().toLowerCase();
          if (err.contains('wrong-password') || err.contains('invalid-credential')) {
            throw Exception("Incorrect password. Please verify your current password.");
          }
        }
      }
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception("Security notice: This operation is sensitive. Please log out, log back in, and try deleting your account.");
      }
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
  
  Future<void> resetPassword(String email) async {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception("No user logged in");

    final cred = EmailAuthProvider.credential(
      email: user.email!, 
      password: currentPassword
    );

    // 1. Re-authenticate
    await user.reauthenticateWithCredential(cred);
    
    // 2. Update Password
    await user.updatePassword(newPassword);
  }

  // Create secondary account without signing out current user
  Future<String?> createEmployeeAccount(String email, String password) async {
    FirebaseApp app = await Firebase.initializeApp(
      name: 'Secondary',
      options: Firebase.app().options,
    );
    
    try {
      UserCredential cred = await FirebaseAuth.instanceFor(app: app)
          .createUserWithEmailAndPassword(email: email, password: password);
      
      // Auto-verify email for convenience (optional)
      // await cred.user?.sendEmailVerification();
      
      return cred.user?.uid;
    } catch (e) {
      rethrow;
    } finally {
      await app.delete(); 
    }
  }

  // Admin Reset Password (Client-side workaround using stored credential)
  Future<void> updateEmployeePassword(String email, String oldPassword, String newPassword) async {
    FirebaseApp app = await Firebase.initializeApp(
      name: 'SecondaryUpdate',
      options: Firebase.app().options,
    );

    try {
      // 1. Sign In
      UserCredential cred = await FirebaseAuth.instanceFor(app: app)
          .signInWithEmailAndPassword(email: email, password: oldPassword);
      
      // 2. Update Password
      await cred.user?.updatePassword(newPassword);
      
    } catch (e) {
      // Improve error message
      if (e.toString().contains("wrong-password")) {
         throw Exception("System Mismatch: The stored password does not match the cloud account. Cannot reset.");
      }
      rethrow;
    } finally {
      await app.delete();
    }
  }
}
