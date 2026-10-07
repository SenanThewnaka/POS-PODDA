import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/subscription/subscription_provider.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

void main() {
  group('UserModel Security & Credential Protection', () {
    test('toCacheMap strips storedPassword to prevent plaintext credential caching in SharedPreferences', () {
      final user = UserModel(
        uid: 'emp-101',
        email: 'cashier@shop1.sme',
        name: 'Sunil Perera',
        mobile: '0712345678',
        role: 'cashier',
        shopId: 'owner-shop-1',
        storedPassword: 'superSecretPassword123',
        expiryDate: DateTime(2027, 1, 1),
        lastSessionClaimedAt: DateTime(2026, 10, 1),
      );

      final cacheMap = user.toCacheMap();

      // storedPassword MUST be stripped from local cache representation
      expect(cacheMap.containsKey('storedPassword'), isFalse);
      expect(cacheMap['storedPassword'], isNull);

      // Safe identity and configuration fields must be preserved
      expect(cacheMap['uid'], 'emp-101');
      expect(cacheMap['name'], 'Sunil Perera');
      expect(cacheMap['role'], 'cashier');
      expect(cacheMap['shopId'], 'owner-shop-1');
      expect(cacheMap['expiryDate'], isNotNull);
      expect(cacheMap['lastSessionClaimedAt'], isNotNull);
    });

    test('fromMap restores user model properties faithfully', () {
      final map = {
        'uid': 'emp-102',
        'email': 'emp@shop.sme',
        'name': 'Nimal',
        'mobile': '0771234567',
        'role': 'cashier',
        'shopId': 'shop-1',
        'plan': 'pro',
      };

      final user = UserModel.fromMap(map);
      expect(user.uid, 'emp-102');
      expect(user.role, 'cashier');
      expect(user.plan, 'pro');
      expect(user.storedPassword, isNull);
    });
  });

  group('Shop Owner Subscription Inheritance for Team Members', () {
    test('Employee inherits Pro plan privileges from the shop owner profile', () async {
      final ownerUser = UserModel(
        uid: 'owner-uid-1',
        email: 'owner@shop.com',
        name: 'Shop Owner',
        mobile: '0779999999',
        role: 'owner',
        shopId: 'owner-uid-1',
        plan: 'pro',
        subscriptionStatus: 'active',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      final employeeUser = UserModel(
        uid: 'emp-uid-1',
        email: 'cashier@shop.sme',
        name: 'Cashier 1',
        mobile: '0771111111',
        role: 'cashier',
        shopId: 'owner-uid-1',
        plan: 'free', // Default unassigned employee plan
      );

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(employeeUser)),
          shopOwnerProfileProvider.overrideWith((ref) => Stream.value(ownerUser)),
        ],
      );

      await container.read(userProfileProvider.future);
      await container.read(shopOwnerProfileProvider.future);
      final subState = container.read(subscriptionProvider);

      expect(subState.plan, 'pro');
      expect(subState.isExpired, isFalse);
      expect(subState.isReadOnly, isFalse);
      expect(subState.canManageTeam, isTrue);
      expect(subState.canUseCredit, isTrue);
      expect(subState.canViewAdvancedStats, isTrue);
      expect(subState.canUseGRN, isTrue);
    });

    test('Employee inherits expired status when shop owner subscription has expired', () async {
      final ownerUser = UserModel(
        uid: 'owner-uid-2',
        email: 'owner2@shop.com',
        name: 'Shop Owner 2',
        mobile: '0779999999',
        role: 'owner',
        shopId: 'owner-uid-2',
        plan: 'pro',
        subscriptionStatus: 'expired',
        expiryDate: DateTime.now().subtract(const Duration(days: 5)),
      );

      final employeeUser = UserModel(
        uid: 'emp-uid-2',
        email: 'cashier2@shop.sme',
        name: 'Cashier 2',
        mobile: '0772222222',
        role: 'cashier',
        shopId: 'owner-uid-2',
        plan: 'free',
      );

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(employeeUser)),
          shopOwnerProfileProvider.overrideWith((ref) => Stream.value(ownerUser)),
        ],
      );

      await container.read(userProfileProvider.future);
      await container.read(shopOwnerProfileProvider.future);
      final subState = container.read(subscriptionProvider);

      expect(subState.isExpired, isTrue);
      expect(subState.isReadOnly, isTrue);
      expect(subState.canAddItems, isFalse);
      expect(subState.expirationReason, contains('expired'));
    });

    test('Owner user uses their own profile directly without needing shopOwnerProfileProvider override', () async {
      final ownerUser = UserModel(
        uid: 'owner-uid-3',
        email: 'owner3@shop.com',
        name: 'Shop Owner 3',
        mobile: '0773333333',
        role: 'owner',
        shopId: 'owner-uid-3',
        plan: 'plus',
        subscriptionStatus: 'active',
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      );

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(ownerUser)),
        ],
      );

      await container.read(userProfileProvider.future);
      final subState = container.read(subscriptionProvider);

      expect(subState.plan, 'plus');
      expect(subState.isExpired, isFalse);
      expect(subState.canManageTeam, isFalse); // Plus does not include team management
      expect(subState.canUseGRN, isTrue);
    });
  });

  group('UserModel Deletion and Trial History Serialization Tests', () {
    test('isDeleted and deletedAt serialize and deserialize accurately', () {
      final deleteTime = DateTime(2026, 10, 3, 14, 30);
      final user = UserModel(
        uid: 'user-del-1',
        email: 'deleted@test.com',
        name: 'Deleted Owner',
        mobile: '0771234567',
        role: 'owner',
        shopId: 'shop-del-1',
        isDeleted: true,
        deletedAt: deleteTime,
      );

      final map = user.toMap();
      expect(map['isDeleted'], isTrue);
      expect(map['deletedAt'], isNotNull);

      final fromMapUser = UserModel.fromMap(map);
      expect(fromMapUser.isDeleted, isTrue);
      expect(fromMapUser.deletedAt, isNotNull);

      final cacheMap = user.toCacheMap();
      expect(cacheMap['isDeleted'], isTrue);
      expect(cacheMap['deletedAt'], deleteTime.toIso8601String());

      final restored = UserModel.fromMap(cacheMap);
      expect(restored.isDeleted, isTrue);
      expect(restored.deletedAt, equals(deleteTime));
    });

    test('default UserModel specifies trial plan and trial billingCycle', () {
      final newUser = UserModel(
        uid: 'new-user-1',
        email: 'trial@test.com',
        name: 'New Trial Owner',
        mobile: '0771234568',
        role: 'owner',
        shopId: 'shop-trial-1',
      );

      expect(newUser.plan, 'trial');
      expect(newUser.billingCycle, 'trial');
      expect(newUser.subscriptionStatus, 'active');
      expect(newUser.isDeleted, isFalse);
      expect(newUser.deletedAt, isNull);
    });

    test('copyWith updates isDeleted and deletedAt properly', () {
      final user = UserModel(
        uid: 'user-cw',
        email: 'cw@test.com',
        name: 'Copy User',
        mobile: '0771234569',
        role: 'owner',
        shopId: 'shop-cw-1',
      );

      final now = DateTime.now();
      final deletedUser = user.copyWith(
        isDeleted: true,
        deletedAt: now,
        subscriptionStatus: 'inactive',
      );

      expect(deletedUser.isDeleted, isTrue);
      expect(deletedUser.deletedAt, equals(now));
      expect(deletedUser.subscriptionStatus, 'inactive');
    });
  });
}
