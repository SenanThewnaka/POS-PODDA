import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/employee_login_screen.dart';
import 'package:sme_buddy/features/auth/login_screen.dart';
import 'package:sme_buddy/features/auth/signup_screen.dart';

/// Fake AuthRepository for testing without Firebase dependencies
class FakeAuthRepository implements AuthRepository {
  bool signInCalled = false;
  String? lastEmail;
  String? lastPassword;
  bool resetPasswordCalled = false;
  String? lastResetEmail;
  Object? errorToThrow;
  Completer<User?>? delayedSignIn;

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    signInCalled = true;
    lastEmail = email;
    lastPassword = password;
    if (delayedSignIn != null) {
      return delayedSignIn!.future;
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return null;
  }

  @override
  Future<void> resetPassword(String email) async {
    resetPasswordCalled = true;
    lastResetEmail = email;
  }

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<User?> signUpWithEmail(String email, String password) async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {}

  @override
  Future<String?> createEmployeeAccount(String email, String password) async => 'emp_123';

  @override
  Future<void> updateEmployeePassword(String email, String oldPassword, String newPassword) async {}
}

Widget _createTestWidget({
  required FakeAuthRepository fakeAuth,
  Brightness brightness = Brightness.dark,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuth),
    ],
    child: MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: brightness,
        ),
      ),
      home: const LoginScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeAuthRepository fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthRepository();
  });

  group('Category A: UI & Client-Side Form Validation', () {
    testWidgets('TC-AUTH-01: Empty form shows validation errors on submit', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      // Tap Login button with empty fields
      final loginBtn = find.widgetWithText(ElevatedButton, 'LOGIN');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Assert validation messages
      expect(find.text('Invalid Email'), findsOneWidget);
      expect(find.text('Password too short'), findsOneWidget);
      expect(fakeAuth.signInCalled, isFalse);
    });

    testWidgets('TC-AUTH-02: Invalid email format fails validation', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      // Enter invalid email and valid password
      await tester.enterText(find.byType(TextFormField).at(0), 'cashier-pos');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Email'), findsOneWidget);
      expect(find.text('Password too short'), findsNothing);
      expect(fakeAuth.signInCalled, isFalse);
    });

    testWidgets('TC-AUTH-03: Password shorter than 6 characters fails validation', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      // Enter valid email and short password (5 chars)
      await tester.enterText(find.byType(TextFormField).at(0), 'admin@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Email'), findsNothing);
      expect(find.text('Password too short'), findsOneWidget);
      expect(fakeAuth.signInCalled, isFalse);
    });

    testWidgets('TC-AUTH-04: Valid credentials pass validation and trigger sign-in', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'securePass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Email'), findsNothing);
      expect(find.text('Password too short'), findsNothing);
      expect(fakeAuth.signInCalled, isTrue);
      expect(fakeAuth.lastEmail, 'admin@pos.lk');
      expect(fakeAuth.lastPassword, 'securePass123');
    });

    testWidgets('TC-AUTH-05: Password visibility toggles obscureText and eye icon', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      // Initially password should be obscured (visibility_off icon visible)
      final passwordFieldInitial = tester.widget<TextField>(
        find.descendant(of: find.byType(TextFormField).at(1), matching: find.byType(TextField)),
      );
      expect(passwordFieldInitial.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // Tap toggle button
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Should now be un-obscured
      final passwordFieldVisible = tester.widget<TextField>(
        find.descendant(of: find.byType(TextFormField).at(1), matching: find.byType(TextField)),
      );
      expect(passwordFieldVisible.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Tap again to obscure
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('TC-AUTH-06: Forgot password with empty email displays prompt SnackBar', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Email first!'), findsOneWidget);
      expect(fakeAuth.resetPasswordCalled, isFalse);
    });

    testWidgets('TC-AUTH-07: Forgot password with valid email sends reset email', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'owner@shop.com');
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(fakeAuth.resetPasswordCalled, isTrue);
      expect(fakeAuth.lastResetEmail, 'owner@shop.com');
      expect(find.text('Password Reset Email Sent!'), findsOneWidget);
    });
  });

  group('Category B: Authentication States & Error Handling', () {
    testWidgets('TC-AUTH-08: Shows loading spinner while authentication is in-flight', (tester) async {
      fakeAuth.delayedSignIn = Completer<User?>();

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      // Pump once to advance state to loading without settling
      await tester.pump();

      // Verify CircularProgressIndicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete async sign-in
      fakeAuth.delayedSignIn!.complete(null);
      await tester.pumpAndSettle();

      // Spinner should be dismissed
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('TC-AUTH-09: Invalid credentials displays user-friendly error SnackBar', (tester) async {
      fakeAuth.errorToThrow = FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The supplied auth credential is incorrect or expired.',
      );

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'cashier@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('TC-AUTH-10: User not found displays invalid email or password SnackBar', (tester) async {
      fakeAuth.errorToThrow = FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'ghost@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'anypassword');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('TC-AUTH-11: Generic server or network exception handled without crash', (tester) async {
      fakeAuth.errorToThrow = Exception('Network connection timed out');

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Login Failed:'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('TC-AUTH-12: Button is disabled while loading to prevent duplicate submissions', (tester) async {
      fakeAuth.delayedSignIn = Completer<User?>();

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@pos.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
      await tester.pump();

      // While loading, ElevatedButton.onPressed should be null
      final loginButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(loginButton.onPressed, isNull);

      // Clean up
      fakeAuth.delayedSignIn!.complete(null);
      await tester.pumpAndSettle();
    });
  });

  group('Category C: Navigation Routing', () {
    testWidgets('TC-AUTH-13: Sign Up button navigates to SignupScreen', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      final signUpBtn = find.text('Sign Up');
      expect(signUpBtn, findsOneWidget);
      await tester.tap(signUpBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('TC-AUTH-14: Employee Login button navigates to EmployeeLoginScreen', (tester) async {
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      final empBtn = find.text('LOGIN AS EMPLOYEE');
      expect(empBtn, findsOneWidget);
      await tester.ensureVisible(empBtn);
      await tester.tap(empBtn);
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeLoginScreen), findsOneWidget);
    });
  });

  group('Category D: Environmental & Responsive Stress Testing', () {
    testWidgets('TC-AUTH-15: Renders with 0 overflow on standard Mobile Portrait (412x915)', (tester) async {
      tester.view.physicalSize = const Size(412 * 3.0, 915 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('POS Podda'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('TC-AUTH-16: Renders and scrolls smoothly under Mobile Landscape with Keyboard (915x412, 200px keyboard)', (tester) async {
      // 915 width, 250 height remaining with keyboard
      tester.view.physicalSize = const Size(915 * 2.5, 250 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);

      await tester.drag(scrollableFinder, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-AUTH-17: Renders cleanly on Tablet Touch POS Screen (800x1280)', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1280 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('POS Podda'), findsOneWidget);
      expect(find.text('Login to your shop'), findsOneWidget);
    });

    testWidgets('TC-AUTH-18: Theme contrast renders appropriately in Dark and Light mode', (tester) async {
      // Dark Mode
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth, brightness: Brightness.dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Light Mode
      await tester.pumpWidget(_createTestWidget(fakeAuth: fakeAuth, brightness: Brightness.light));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
