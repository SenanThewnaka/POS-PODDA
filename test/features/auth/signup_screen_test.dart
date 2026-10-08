import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/signup_screen.dart';
import 'package:sme_buddy/features/auth/widgets/google_sign_in_button.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

class FakeAuthRepository implements AuthRepository {
  bool signUpCalled = false;
  bool signInWithGoogleCalled = false;
  String? lastEmail;
  String? lastPassword;
  Object? googleErrorToThrow;

  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    signUpCalled = true;
    lastEmail = email;
    lastPassword = password;
    return null;
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInWithGoogleCalled = true;
    if (googleErrorToThrow != null) {
      throw googleErrorToThrow!;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserProfileRepository implements UserProfileRepository {
  UserModel? savedProfile;

  @override
  Future<void> saveUserProfile(UserModel user) async {
    savedProfile = user;
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async => savedProfile;

  @override
  Future<UserModel> ensureUserProfileForGoogle(User user) async {
    final profile = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'Shop Owner',
      mobile: '',
      role: 'owner',
      shopId: user.uid,
      shopName: "Owner's Shop",
    );
    savedProfile = profile;
    return profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _createSignupTestWidget({
  required FakeAuthRepository fakeAuth,
  FakeUserProfileRepository? fakeProfileRepo,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuth),
      if (fakeProfileRepo != null)
        userProfileRepositoryProvider.overrideWithValue(fakeProfileRepo),
    ],
    child: const MaterialApp(
      home: SignupScreen(),
    ),
  );
}

void main() {
  group('SignupScreen Widget Tests', () {
    late FakeAuthRepository fakeAuth;
    late FakeUserProfileRepository fakeProfileRepo;

    setUp(() {
      fakeAuth = FakeAuthRepository();
      fakeProfileRepo = FakeUserProfileRepository();
    });

    testWidgets('Renders all fields, CREATE ACCOUNT button, and Google Sign-Up button', (tester) async {
      await tester.pumpWidget(_createSignupTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      expect(find.text('Start your journey'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.byType(GoogleSignInButton), findsOneWidget);
    });

    testWidgets('Tapping Sign up with Google invokes signInWithGoogle()', (tester) async {
      await tester.pumpWidget(_createSignupTestWidget(fakeAuth: fakeAuth, fakeProfileRepo: fakeProfileRepo));
      await tester.pumpAndSettle();

      final googleBtn = find.text('Sign up with Google');
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(fakeAuth.signInWithGoogleCalled, isTrue);
    });

    testWidgets('Google Sign-Up error displays user-friendly SnackBar', (tester) async {
      fakeAuth.googleErrorToThrow = Exception('network error');

      await tester.pumpWidget(_createSignupTestWidget(fakeAuth: fakeAuth, fakeProfileRepo: fakeProfileRepo));
      await tester.pumpAndSettle();

      final googleBtn = find.text('Sign up with Google');
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Network error. Please check your internet connection.'), findsOneWidget);
    });
  });
}
