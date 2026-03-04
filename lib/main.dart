import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sme_buddy/features/auth/auth_gate.dart';
import 'package:sme_buddy/features/home/home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sme_buddy/firebase_options.dart';

import 'package:sme_buddy/features/settings/theme_provider.dart';
import 'package:sme_buddy/utils/analytics_service.dart';

import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Crashlytics (disable in debug for clean console output)
  const fatalError = true;
  if (!kDebugMode) {
    // Pass all Flutter framework errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all async Dart errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatalError);
      return true;
    };
  }

  // Initialize Shorebird OTA
  final shorebirdUpdater = ShorebirdUpdater();
  shorebirdUpdater.readCurrentPatch().then(
    (value) {
      if (kDebugMode) print('Shorebird patch: ${value?.number ?? "none"}');
    },
  );

  // OPTIMIZATION: Enable Firestore Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ProviderScope(child: SmeBuddyApp()));
}

class SmeBuddyApp extends ConsumerWidget {
  const SmeBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorObservers: AnalyticsService.observers,
      title: 'POS Podda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      home: const AuthGate(),
    );
  }
}
