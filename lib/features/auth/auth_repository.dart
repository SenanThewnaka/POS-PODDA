import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository(this._firebaseAuth);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

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

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
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
