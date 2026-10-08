import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/roles/role_model.dart';
import 'package:sme_buddy/features/roles/role_repository.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/employee_management_screen.dart';
import 'package:sme_buddy/features/home/add_to_cart_sheet.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/product_dashboard_screen.dart';

// ---------------------------------------------------------------------------
// Fakes & Mocks
// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepository {
  String? lastCreatedEmail;
  String? lastCreatedPass;

  @override
  Future<String?> createEmployeeAccount(String email, String password) async {
    lastCreatedEmail = email;
    lastCreatedPass = password;
    return "mock-employee-uid-123";
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserProfileRepository implements UserProfileRepository {
  UserModel? savedUser;

  @override
  Future<void> saveUserProfile(UserModel user) async {
    savedUser = user;
  }

  @override
  Stream<List<UserModel>> getShopEmployees(String shopId) {
    return Stream.value([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProductRepository implements ProductRepository {
  final List<StockBatch> batches;
  final Product? product;

  FakeProductRepository({this.batches = const [], this.product});

  @override
  Stream<Product> getProductStream(String productId) {
    if (product != null) {
      return Stream.value(product!);
    }
    return const Stream.empty();
  }

  @override
  Future<List<StockBatch>> getActiveBatches(String productId) async {
    return batches;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppPermissions & Role Presets', () {
    test('allValues contains new retail POS permissions', () {
      expect(AppPermissions.allValues, contains(AppPermissions.canViewCostPrice));
      expect(AppPermissions.allValues, contains(AppPermissions.canGiveDiscount));
      expect(AppPermissions.allValues, contains(AppPermissions.canManageGRN));
      expect(AppPermissions.allValues, contains(AppPermissions.canManageShifts));
      expect(AppPermissions.allValues, contains(AppPermissions.canViewSalesReports));
    });

    test('getLabel returns descriptive names for all permissions', () {
      for (final perm in AppPermissions.allValues) {
        final label = AppPermissions.getLabel(perm);
        expect(label, isNotEmpty);
        expect(label, isNot(equals(perm)));
      }
    });

    test('defaultCashierPermissions enforces cashier restrictions', () {
      final p = AppPermissions.defaultCashierPermissions;
      expect(p[AppPermissions.canCheckout], isTrue);
      expect(p[AppPermissions.canManageShifts], isTrue);
      // Critical retail guards must be FALSE
      expect(p[AppPermissions.canViewCostPrice], isFalse);
      expect(p[AppPermissions.canGiveDiscount], isFalse);
      expect(p[AppPermissions.canManageGRN], isFalse);
      expect(p[AppPermissions.canViewSalesReports], isFalse);
      expect(p[AppPermissions.canAddEmployees], isFalse);
    });

    test('defaultStockKeeperPermissions enables GRN and Cost visibility, restricts checkout', () {
      final p = AppPermissions.defaultStockKeeperPermissions;
      expect(p[AppPermissions.canManageGRN], isTrue);
      expect(p[AppPermissions.canViewCostPrice], isTrue);
      expect(p[AppPermissions.canAddProducts], isTrue);
      // Checkout & sales reporting must be FALSE
      expect(p[AppPermissions.canCheckout], isFalse);
      expect(p[AppPermissions.canGiveDiscount], isFalse);
      expect(p[AppPermissions.canViewSalesReports], isFalse);
    });

    test('defaultManagerPermissions provides full operational access', () {
      final p = AppPermissions.defaultManagerPermissions;
      expect(p[AppPermissions.canViewCostPrice], isTrue);
      expect(p[AppPermissions.canGiveDiscount], isTrue);
      expect(p[AppPermissions.canManageGRN], isTrue);
      expect(p[AppPermissions.canManageShifts], isTrue);
      expect(p[AppPermissions.canViewSalesReports], isTrue);
      expect(p[AppPermissions.canAddEmployees], isTrue);
    });
  });

  group('UserModel permission evaluation', () {
    test('Shop owner / admin has all permissions regardless of map', () {
      final owner = UserModel(
        uid: 'owner-1',
        email: 'owner@shop.com',
        name: 'Shop Owner',
        mobile: '0771234567',
        role: 'owner',
        shopId: 'shop-1',
        permissions: {}, // empty permissions map
      );

      expect(owner.isAdmin, isTrue);
      expect(owner.hasPermission(AppPermissions.canViewCostPrice), isTrue);
      expect(owner.hasPermission(AppPermissions.canGiveDiscount), isTrue);
      expect(owner.hasPermission(AppPermissions.canManageGRN), isTrue);
      expect(owner.hasPermission('ANY_UNKNOWN_PERMISSION'), isTrue);
    });

    test('Manager has admin privileges', () {
      final manager = UserModel(
        uid: 'mgr-1',
        email: 'mgr@shop.com',
        name: 'Manager',
        mobile: '0771234568',
        role: 'manager',
        shopId: 'shop-1',
        permissions: {},
      );

      expect(manager.isAdmin, isTrue);
      expect(manager.hasPermission(AppPermissions.canViewCostPrice), isTrue);
    });

    test('Cashier is strictly evaluated against permissions map', () {
      final cashier = UserModel(
        uid: 'cashier-1',
        email: 'cashier@shop.sme',
        name: 'Cashier Staff',
        mobile: '0771234569',
        role: 'cashier',
        shopId: 'shop-1',
        permissions: AppPermissions.defaultCashierPermissions,
      );

      expect(cashier.isAdmin, isFalse);
      expect(cashier.hasPermission(AppPermissions.canCheckout), isTrue);
      expect(cashier.hasPermission(AppPermissions.canViewCostPrice), isFalse);
      expect(cashier.hasPermission(AppPermissions.canGiveDiscount), isFalse);
      expect(cashier.hasPermission(AppPermissions.canManageGRN), isFalse);
    });
  });

  group('AddEmployeeDialog role template selection & creation', () {
    testWidgets('Assigns role template and saves user with role and permissions', (tester) async {
      final fakeAuth = FakeAuthRepository();
      final fakeUserRepo = FakeUserProfileRepository();

      final customRole = RoleModel(
        id: 'role-senior-cashier',
        shopId: 'test-shop',
        name: 'Senior Cashier',
        permissions: {
          ...AppPermissions.defaultCashierPermissions,
          AppPermissions.canGiveDiscount: true,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            userProfileRepositoryProvider.overrideWithValue(fakeUserRepo),
            shopRolesStreamProvider('test-shop').overrideWith(
              (ref) => Stream.value([customRole]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddEmployeeDialog(
                shopId: 'test-shop',
                shopName: 'Super Mart',
                shopCode: 'MART01',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify role dropdown is present
      expect(find.text("ASSIGN ROLE TEMPLATE"), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      // Enter employee details
      await tester.enterText(find.widgetWithText(TextFormField, "Full Name *"), "Kamal Perera");
      await tester.enterText(find.widgetWithText(TextFormField, "Mobile Number"), "0770001122");
      await tester.enterText(find.widgetWithText(TextFormField, "Username (Staff ID / Name) *"), "kamal01");
      await tester.enterText(find.widgetWithText(TextFormField, "Initial Password *"), "secret123");

      // Select "Stock Keeper" role template
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Stock Keeper (Inventory & GRN)").last);
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text("ADD EMPLOYEE"));
      await tester.pumpAndSettle();

      // Verify Account Creation
      expect(fakeAuth.lastCreatedEmail, "kamal01@mart01.sme");
      expect(fakeAuth.lastCreatedPass, "secret123");

      // Verify User Saved in Repo
      expect(fakeUserRepo.savedUser, isNotNull);
      final saved = fakeUserRepo.savedUser!;
      expect(saved.name, "Kamal Perera");
      expect(saved.username, "kamal01");
      expect(saved.role, "stock keeper");
      expect(saved.permissions[AppPermissions.canManageGRN], isTrue);
      expect(saved.permissions[AppPermissions.canViewCostPrice], isTrue);
      expect(saved.permissions[AppPermissions.canCheckout], isFalse);
    });
  });

  group('UI Guards for Cost Price & Margin Privacy', () {
    testWidgets('AddToCartSheet hides wholesale cost and margin when user lacks canViewCostPrice', (tester) async {
      final cashierUser = UserModel(
        uid: 'emp-1',
        email: 'emp@test.sme',
        name: 'Cashier',
        mobile: '0770000000',
        role: 'cashier',
        shopId: 'test-shop',
        permissions: {
          AppPermissions.canCheckout: true,
          AppPermissions.canViewCostPrice: false,
          AppPermissions.canGiveDiscount: false,
        },
      );

      final product = Product(
        id: 'prod-1',
        name: 'Dhal (Mysore)',
        sellingPrice: 320.0,
        costPrice: 240.0,
        stockType: 'unit',
        baseUnit: 'kg',
        currentStock: 100,
        createdAt: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(cashierUser)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddToCartSheet(product: product),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Since canViewCostPrice is false, "Cost:" or "Margin:" should NOT appear
      expect(find.textContaining("Margin:"), findsNothing);
      expect(find.textContaining("Profit"), findsNothing);

      // Discount toggle should also NOT appear since canGiveDiscount is false
      expect(find.text("Percentage (%)"), findsNothing);
      expect(find.text("Fixed Amount (Rs)"), findsNothing);
    });

    testWidgets('AddToCartSheet shows wholesale cost and discount toggle when authorized', (tester) async {
      final managerUser = UserModel(
        uid: 'mgr-1',
        email: 'mgr@test.sme',
        name: 'Manager',
        mobile: '0770000000',
        role: 'manager',
        shopId: 'test-shop',
        permissions: {
          AppPermissions.canCheckout: true,
          AppPermissions.canViewCostPrice: true,
          AppPermissions.canGiveDiscount: true,
        },
      );

      final product = Product(
        id: 'prod-1',
        name: 'Dhal (Mysore)',
        sellingPrice: 320.0,
        costPrice: 240.0,
        stockType: 'unit',
        baseUnit: 'kg',
        currentStock: 100,
        createdAt: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(managerUser)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddToCartSheet(product: product),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Manager has canViewCostPrice, so cost/margin should be visible
      expect(find.textContaining("Cost:"), findsOneWidget);
      expect(find.textContaining("Margin:"), findsOneWidget);

      // Manager has canGiveDiscount, so discount toggles should be present
      expect(find.text("Percentage (%)"), findsOneWidget);
      expect(find.text("Fixed Amount (Rs)"), findsOneWidget);
    });

    testWidgets('ProductDashboardScreen masks cost price as Rs. •••• for unauthorized staff', (tester) async {
      final cashierUser = UserModel(
        uid: 'emp-1',
        email: 'emp@test.sme',
        name: 'Cashier',
        mobile: '0770000000',
        role: 'cashier',
        shopId: 'test-shop',
        permissions: {
          AppPermissions.canViewCostPrice: false,
        },
      );

      final testBatch = StockBatch(
        id: 'b-1',
        productId: 'prod-1',
        sellingPrice: 320.0,
        costPrice: 240.0,
        currentStock: 50.0,
        createdAt: DateTime(2026, 9, 1),
      );

      final product = Product(
        id: 'prod-1',
        name: 'Dhal (Mysore)',
        sellingPrice: 320.0,
        costPrice: 240.0,
        stockType: 'unit',
        baseUnit: 'kg',
        currentStock: 50,
        createdAt: DateTime(2026, 9, 1),
      );

      final fakeProdRepo = FakeProductRepository(batches: [testBatch], product: product);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(cashierUser)),
            productRepositoryProvider.overrideWithValue(fakeProdRepo),
          ],
          child: MaterialApp(
            home: ProductDashboardScreen(product: product),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Selling price is visible
      expect(find.text("Rs. 320.00"), findsOneWidget);
      // Cost price must be masked with bullets
      expect(find.text("Rs. ••••"), findsOneWidget);
      // Actual cost price must NOT be visible
      expect(find.text("Rs. 240.00"), findsNothing);
    });
  });
}
