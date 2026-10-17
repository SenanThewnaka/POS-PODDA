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
    if (_firebaseAuth.currentUser != null) yield _firebaseAuth.currentUser;
    yield* _firebaseAuth.userChanges();
  }

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    await user.reload();
    return _firebaseAuth.currentUser;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return _firebaseAuth.signInWithPopup(googleProvider);
    }

    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
    await _firebaseAuth.signOut();
  }

  Future<void> reauthenticateCurrentUser({String? currentPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      if (currentPassword != null && currentPassword.isNotEmpty && user.email != null) {
        final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
        await user.reauthenticateWithCredential(credential);
        await user.getIdToken(true);
        return;
      }

      final providerIds = user.providerData.map((provider) => provider.providerId).toSet();
      if (providerIds.contains(GoogleAuthProvider.PROVIDER_ID)) {
        if (kIsWeb) {
          await user.reauthenticateWithPopup(GoogleAuthProvider());
          await user.getIdToken(true);
          return;
        }
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) throw Exception('Google reauthentication was cancelled.');
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        await user.getIdToken(true);
        return;
      }

      throw Exception('This sign-in method needs a fresh sign-in before account deletion.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password. Please verify your current password.');
      }
      rethrow;
    }
  }

  Future<void> deleteCurrentUserAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No user logged in');
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Security notice: Please sign in again, then retry account deletion.');
      }
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) await user.sendEmailVerification();
  }

  Future<void> resetPassword(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) throw Exception('No email account is logged in.');
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Creates a synthetic-email employee account without signing out the owner.
  Future<String?> createEmployeeAccount(String email, String password) async {
    final app = await Firebase.initializeApp(name: 'Secondary', options: Firebase.app().options);
    try {
      final credential = await FirebaseAuth.instanceFor(app: app)
          .createUserWithEmailAndPassword(email: email, password: password);
      return credential.user?.uid;
    } finally {
      await app.delete();
    }
  }
}
