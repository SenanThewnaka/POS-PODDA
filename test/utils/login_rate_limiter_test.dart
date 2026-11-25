import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sme_buddy/utils/login_rate_limiter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginRateLimiter Brute-Force Protection Tests', () {
    test('Initial state has 0 failed attempts and is not locked', () async {
      final state = await LoginRateLimiter.getLockoutState('owner@pos.lk');
      expect(state.isLocked, isFalse);
      expect(state.failedAttempts, equals(0));
      expect(state.remainingSeconds, equals(0));
    });

    test('1 and 2 failed attempts increment count without locking', () async {
      final state1 = await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');
      expect(state1.isLocked, isFalse);
      expect(state1.failedAttempts, equals(1));
      expect(state1.remainingSeconds, equals(0));

      final state2 = await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');
      expect(state2.isLocked, isFalse);
      expect(state2.failedAttempts, equals(2));
      expect(state2.remainingSeconds, equals(0));
    });

    test('3 failed attempts triggers 30-second lockout', () async {
      await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');
      await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');
      final state3 = await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');

      expect(state3.isLocked, isTrue);
      expect(state3.failedAttempts, equals(3));
      expect(state3.remainingSeconds, greaterThanOrEqualTo(29));
      expect(state3.remainingSeconds, lessThanOrEqualTo(30));

      final check = await LoginRateLimiter.getLockoutState('owner@pos.lk');
      expect(check.isLocked, isTrue);
      expect(check.remainingSeconds, greaterThan(0));
    });

    test('5 failed attempts triggers 5-minute (300-second) lockout', () async {
      for (int i = 0; i < 4; i++) {
        await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');
      }
      final state5 = await LoginRateLimiter.recordFailedAttempt('owner@pos.lk');

      expect(state5.isLocked, isTrue);
      expect(state5.failedAttempts, equals(5));
      expect(state5.remainingSeconds, greaterThanOrEqualTo(299));
      expect(state5.remainingSeconds, lessThanOrEqualTo(300));
    });

    test('isFirebaseBlocked immediately triggers 5-minute lockout', () async {
      final state = await LoginRateLimiter.recordFailedAttempt(
        'owner@pos.lk',
        isFirebaseBlocked: true,
      );

      expect(state.isLocked, isTrue);
      expect(state.remainingSeconds, greaterThanOrEqualTo(299));
      expect(state.failedAttempts, greaterThanOrEqualTo(5));
    });

    test('clearAttempts resets lockout and failed counter completely', () async {
      await LoginRateLimiter.recordFailedAttempt('owner@pos.lk', isFirebaseBlocked: true);
      var state = await LoginRateLimiter.getLockoutState('owner@pos.lk');
      expect(state.isLocked, isTrue);

      await LoginRateLimiter.clearAttempts('owner@pos.lk');
      state = await LoginRateLimiter.getLockoutState('owner@pos.lk');
      expect(state.isLocked, isFalse);
      expect(state.failedAttempts, equals(0));
      expect(state.remainingSeconds, equals(0));
    });

    test('formattedRemainingTime prints readable time format', () {
      const state1 = LoginLockoutState(
        isLocked: true,
        remainingSeconds: 45,
        failedAttempts: 3,
      );
      expect(state1.formattedRemainingTime, equals('45 sec'));

      const state2 = LoginLockoutState(
        isLocked: true,
        remainingSeconds: 125,
        failedAttempts: 5,
      );
      expect(state2.formattedRemainingTime, equals('2 min 05 sec'));
    });
  });
}
