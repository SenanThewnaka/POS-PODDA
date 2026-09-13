import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sme_buddy/features/settings/printer_settings_service.dart';
import 'package:sme_buddy/features/shifts/cash_drawer_action_dialog.dart';
import 'package:sme_buddy/features/shifts/close_shift_dialog.dart';
import 'package:sme_buddy/features/shifts/open_shift_dialog.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/features/shifts/z_report_screen.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

// ---------------------------------------------------------------------------
// Test Fakes & Mock Repositories
// ---------------------------------------------------------------------------

class FakeShiftRepository implements ShiftRepository {
  ShiftModel? activeShift;
  final List<ShiftModel> closedShifts = [];
  final List<CashDrawerTransaction> addedTransactions = [];

  FakeShiftRepository({this.activeShift});

  @override
  UserModel get currentUser => _testUser;

  @override
  Stream<ShiftModel?> get currentShiftStream => Stream.value(activeShift);

  @override
  Stream<List<ShiftModel>> get shiftHistoryStream => Stream.value(closedShifts);

  @override
  Future<ShiftModel> openShift({
    required double openingFloat,
    String? notes,
  }) async {
    final shift = ShiftModel(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
      shopId: _testUser.shopId,
      cashierId: _testUser.uid,
      cashierName: _testUser.name ?? 'Cashier',
      openedAt: DateTime.now(),
      isOpen: true,
      openingFloat: openingFloat,
      notes: notes,
    );
    activeShift = shift;
    return shift;
  }

  @override
  Future<void> addCashTransaction({
    required String type,
    required double amount,
    required String reason,
  }) async {
    final tx = CashDrawerTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      amount: amount,
      reason: reason,
      timestamp: DateTime.now(),
      cashierName: _testUser.name,
    );
    addedTransactions.add(tx);

    if (activeShift != null) {
      final updatedIn = activeShift!.cashInTotal + (type == 'IN' ? amount : 0);
      final updatedOut = activeShift!.cashOutTotal + (type == 'OUT' ? amount : 0);
      activeShift = activeShift!.copyWith(
        cashTransactions: [...activeShift!.cashTransactions, tx],
        cashInTotal: updatedIn,
        cashOutTotal: updatedOut,
      );
    }
  }

  @override
  Future<ShiftModel> closeShift({
    required String shiftId,
    required double actualCash,
    String? notes,
  }) async {
    final base = activeShift ?? _createSampleShift();
    final closed = base.copyWith(
      isOpen: false,
      closedAt: DateTime.now(),
      actualCash: actualCash,
      notes: notes ?? base.notes,
    );
    activeShift = null;
    closedShifts.add(closed);
    return closed;
  }

  @override
  Future<void> recordSaleInActiveShift({
    required double amount,
    required String paymentMethod,
  }) async {
    if (activeShift == null) return;
    final isCash = paymentMethod == 'CASH';
    final isCard = paymentMethod == 'CARD';
    final isCredit = paymentMethod == 'CREDIT';

    activeShift = activeShift!.copyWith(
      cashSales: activeShift!.cashSales + (isCash ? amount : 0),
      cardSales: activeShift!.cardSales + (isCard ? amount : 0),
      creditSales: activeShift!.creditSales + (isCredit ? amount : 0),
      totalSales: activeShift!.totalSales + amount,
      transactionCount: activeShift!.transactionCount + 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Test Data Fixtures
// ---------------------------------------------------------------------------

final _testUser = UserModel(
  uid: 'user_1',
  email: 'cashier@pos.lk',
  name: 'Senan Cashier',
  mobile: '0771234567',
  role: 'cashier',
  shopId: 'shop_123',
  shopName: 'Podda Supermart',
  isActive: true,
);

ShiftModel _createSampleShift({
  double openingFloat = 5000.0,
  double cashSales = 15000.0,
  double cardSales = 8000.0,
  double creditSales = 2000.0,
  double cashInTotal = 1000.0,
  double cashOutTotal = 2500.0,
  double? actualCash,
  bool isOpen = true,
}) {
  return ShiftModel(
    id: 'shift_sample_001',
    shopId: 'shop_123',
    cashierId: 'user_1',
    cashierName: 'Senan Cashier',
    openedAt: DateTime(2026, 9, 14, 8, 0),
    closedAt: isOpen ? null : DateTime(2026, 9, 14, 20, 0),
    isOpen: isOpen,
    openingFloat: openingFloat,
    cashSales: cashSales,
    cardSales: cardSales,
    creditSales: creditSales,
    totalSales: cashSales + cardSales + creditSales,
    transactionCount: 24,
    cashInTotal: cashInTotal,
    cashOutTotal: cashOutTotal,
    cashTransactions: [
      CashDrawerTransaction(
        id: 'tx_1',
        type: 'IN',
        amount: 1000.0,
        reason: 'Change Top-up',
        timestamp: DateTime(2026, 9, 14, 10, 0),
        cashierName: 'Senan Cashier',
      ),
      CashDrawerTransaction(
        id: 'tx_2',
        type: 'OUT',
        amount: 2500.0,
        reason: 'Supplier Payout',
        timestamp: DateTime(2026, 9, 14, 14, 0),
        cashierName: 'Senan Cashier',
      ),
    ],
    actualCash: actualCash,
    notes: 'Standard weekday shift',
  );
}

Widget _wrapWithProviders({
  required Widget child,
  FakeShiftRepository? shiftRepo,
}) {
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
      shiftRepositoryProvider.overrideWithValue(shiftRepo ?? FakeShiftRepository()),
      printerSettingsProvider.overrideWith((ref) => PrinterSettingsNotifier()),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test Suite Execution
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category A: Shift Accounting & Model Formulas (Domain)', () {
    test('TC-SFT-01: Expected cash calculation: Float + CashSales + CashIn - CashOut', () {
      // Float: 5000, CashSales: 15000, In: 1000, Out: 2500 -> 5000 + 15000 + 1000 - 2500 = 18500
      final shift = _createSampleShift();
      expect(shift.expectedCash, 18500.0);
    });

    test('TC-SFT-02: Drawer balancing exact match (diff == 0) produces isBalanced', () {
      final shift = _createSampleShift(actualCash: 18500.0);
      expect(shift.difference, 0.0);
      expect(shift.isBalanced, isTrue);
      expect(shift.isOver, isFalse);
      expect(shift.isShort, isFalse);
    });

    test('TC-SFT-03: Drawer surplus (actualCash > expected) produces isOver and positive diff', () {
      final shift = _createSampleShift(actualCash: 19000.0); // +500 over
      expect(shift.difference, 500.0);
      expect(shift.isOver, isTrue);
      expect(shift.isBalanced, isFalse);
      expect(shift.isShort, isFalse);
    });

    test('TC-SFT-04: Drawer deficit (actualCash < expected) produces isShort and negative diff', () {
      final shift = _createSampleShift(actualCash: 18200.0); // -300 short
      expect(shift.difference, -300.0);
      expect(shift.isShort, isTrue);
      expect(shift.isBalanced, isFalse);
      expect(shift.isOver, isFalse);
    });
  });

  group('Category B: Opening Shift Flow (OpenShiftDialog)', () {
    testWidgets('TC-SFT-05: Dialog renders preset opening float chips', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const OpenShiftDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Open Register Shift'), findsOneWidget);
      expect(find.text('Rs. 0'), findsOneWidget);
      expect(find.text('Rs. 2000'), findsOneWidget);
      expect(find.text('Rs. 5000'), findsWidgets);
      expect(find.text('Rs. 10000'), findsOneWidget);
      expect(find.text('Rs. 20000'), findsOneWidget);
    });

    testWidgets('TC-SFT-06: Tapping preset chip updates opening float input field', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const OpenShiftDialog()));
      await tester.pumpAndSettle();

      // Tap preset chip 'Rs. 10000'
      await tester.tap(find.text('Rs. 10000'));
      await tester.pumpAndSettle();

      // Text field should reflect 10000
      final textField = find.byType(TextField).first;
      expect((tester.widget(textField) as TextField).controller?.text, '10000');
    });

    testWidgets('TC-SFT-07: Negative float input triggers validation error SnackBar', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const OpenShiftDialog()));
      await tester.pumpAndSettle();

      // Enter -500
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '-500');
      await tester.pumpAndSettle();

      // Tap START SHIFT & OPEN DRAWER
      await tester.tap(find.text('START SHIFT & OPEN DRAWER'));
      await tester.pumpAndSettle();

      expect(find.text('Float cannot be negative'), findsOneWidget);
    });

    testWidgets('TC-SFT-08: Confirming open shift invokes shiftRepo.openShift and closes dialog', (tester) async {
      final shiftRepo = FakeShiftRepository();

      await tester.pumpWidget(_wrapWithProviders(
        child: const OpenShiftDialog(),
        shiftRepo: shiftRepo,
      ));
      await tester.pumpAndSettle();

      // Tap START SHIFT & OPEN DRAWER with default 5000
      await tester.tap(find.text('START SHIFT & OPEN DRAWER'));
      await tester.pumpAndSettle();

      expect(shiftRepo.activeShift, isNotNull);
      expect(shiftRepo.activeShift!.openingFloat, 5000.0);
      expect(shiftRepo.activeShift!.isOpen, isTrue);
    });
  });

  group('Category C: Mid-Shift Cash Drawer Actions (CashDrawerActionDialog)', () {
    testWidgets('TC-SFT-09: Toggle between OUT (Cash Payout) and IN (Cash In)', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const CashDrawerActionDialog(initialType: 'OUT')));
      await tester.pumpAndSettle();

      expect(find.text('CASH OUT (PAYOUT)'), findsOneWidget);
      expect(find.text('CASH IN (ADD)'), findsOneWidget);

      // Tap Cash In
      await tester.tap(find.text('CASH IN (ADD)'));
      await tester.pumpAndSettle();

      expect(find.text('CONFIRM CASH IN'), findsOneWidget);
    });

    testWidgets('TC-SFT-10: Reason suggestions update based on type selection', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const CashDrawerActionDialog(initialType: 'OUT')));
      await tester.pumpAndSettle();

      // In OUT mode: Supplier Payout chip is available
      expect(find.text('Supplier Payout'), findsWidgets);

      // Switch to IN mode: Change Top-up chip is available
      await tester.tap(find.text('CASH IN (ADD)'));
      await tester.pumpAndSettle();

      expect(find.text('Change Top-up'), findsWidgets);
    });

    testWidgets('TC-SFT-11: Empty or zero amount validation triggers error SnackBar', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const CashDrawerActionDialog(initialType: 'OUT')));
      await tester.pumpAndSettle();

      final button = find.text('CONFIRM CASH OUT');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // Submit with empty amount
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid amount'), findsOneWidget);
    });

    testWidgets('TC-SFT-12: Valid cash transaction invokes shiftRepo.addCashTransaction', (tester) async {
      final active = _createSampleShift();
      final shiftRepo = FakeShiftRepository(activeShift: active);

      await tester.pumpWidget(_wrapWithProviders(
        child: const CashDrawerActionDialog(initialType: 'IN'),
        shiftRepo: shiftRepo,
      ));
      await tester.pumpAndSettle();

      // Enter amount 2000
      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '2000');
      await tester.pumpAndSettle();

      final button = find.text('CONFIRM CASH IN');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // Tap CONFIRM CASH IN
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(shiftRepo.addedTransactions.length, 1);
      final tx = shiftRepo.addedTransactions.first;
      expect(tx.type, 'IN');
      expect(tx.amount, 2000.0);
    });
  });

  group('Category D: Closing Shift & Cash Count Verification (CloseShiftDialog)', () {
    testWidgets('TC-SFT-13: Dialog initializes counted cash to expected cash (Exact Match)', (tester) async {
      final shift = _createSampleShift(); // Expected: 18500.00
      await tester.pumpWidget(_wrapWithProviders(child: CloseShiftDialog(shift: shift)));
      await tester.pumpAndSettle();

      expect(find.text('Close Shift & Balance Drawer'), findsOneWidget);
      expect(find.text('Rs. 18500.00'), findsWidgets);
      expect(find.text('Exact Match (Rs. 0.00)'), findsOneWidget);
    });

    testWidgets('TC-SFT-14: Adjusting counted cash live-updates difference status to Over or Short', (tester) async {
      final shift = _createSampleShift(); // Expected: 18500.00
      await tester.pumpWidget(_wrapWithProviders(child: CloseShiftDialog(shift: shift)));
      await tester.pumpAndSettle();

      final countedField = find.byType(TextField).first;

      // Enter 19000 (+500 over)
      await tester.enterText(countedField, '19000');
      await tester.pumpAndSettle();
      expect(find.text('Over by +Rs. 500.00'), findsOneWidget);

      // Enter 18000 (-500 short)
      await tester.enterText(countedField, '18000');
      await tester.pumpAndSettle();
      expect(find.text('Short by -Rs. 500.00'), findsOneWidget);
    });

    testWidgets('TC-SFT-15: Closing notes can be entered and persisted', (tester) async {
      final shift = _createSampleShift(); // Expected: 18500.00
      final shiftRepo = FakeShiftRepository(activeShift: shift);

      await tester.pumpWidget(_wrapWithProviders(
        child: CloseShiftDialog(shift: shift),
        shiftRepo: shiftRepo,
      ));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // counted cash + notes
      final notesField = textFields.at(1);
      await tester.ensureVisible(notesField);
      await tester.pumpAndSettle();
      await tester.enterText(notesField, 'Discrepancy due to bank fee voucher');
      await tester.pumpAndSettle();

      final button = find.text('CLOSE SHIFT & GENERATE Z-REPORT');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(shiftRepo.closedShifts.length, 1);
      expect(shiftRepo.closedShifts.first.notes, 'Discrepancy due to bank fee voucher');
    });

    testWidgets('TC-SFT-16: Submitting close shift calls shiftRepo.closeShift', (tester) async {
      final shift = _createSampleShift();
      final shiftRepo = FakeShiftRepository(activeShift: shift);

      await tester.pumpWidget(_wrapWithProviders(
        child: CloseShiftDialog(shift: shift),
        shiftRepo: shiftRepo,
      ));
      await tester.pumpAndSettle();

      final button = find.text('CLOSE SHIFT & GENERATE Z-REPORT');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // Tap CLOSE SHIFT & GENERATE Z-REPORT
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(shiftRepo.closedShifts.length, 1);
      final closed = shiftRepo.closedShifts.first;
      expect(closed.isOpen, isFalse);
      expect(closed.actualCash, 18500.0);
    });
  });

  group('Category E: Day-End Z-Report & Responsive Layout (ZReportScreen)', () {
    testWidgets('TC-SFT-17: Displays complete financial sales summary', (tester) async {
      final closedShift = _createSampleShift(isOpen: false, actualCash: 18500.0);

      tester.view.physicalSize = const Size(800 * 2.0, 1600 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: ZReportScreen(shift: closedShift)));
      await tester.pumpAndSettle();

      expect(find.text('Day-End Z-Report'), findsOneWidget);
      expect(find.text('BALANCED (Rs. 0.00)'), findsOneWidget);
      expect(find.text('Rs. 5000.00'), findsWidgets); // Float
      expect(find.text('Rs. 15000.00'), findsWidgets); // Cash sales
      expect(find.text('Rs. 8000.00'), findsWidgets); // Card sales
      expect(find.text('Rs. 2000.00'), findsWidgets); // Credit sales
      expect(find.text('Rs. 25000.00'), findsWidgets); // Total gross sales
    });

    testWidgets('TC-SFT-18: Displays cash drawer transaction breakdown (In & Out)', (tester) async {
      final closedShift = _createSampleShift(isOpen: false, actualCash: 18500.0);

      tester.view.physicalSize = const Size(800 * 2.0, 1600 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: ZReportScreen(shift: closedShift)));
      await tester.pumpAndSettle();

      expect(find.text('Change Top-up'), findsOneWidget);
      expect(find.text('Supplier Payout'), findsOneWidget);
    });

    testWidgets('TC-SFT-19: [Esc] key pops back from ZReportScreen', (tester) async {
      final closedShift = _createSampleShift(isOpen: false, actualCash: 18500.0);
      bool popped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
            printerSettingsProvider.overrideWith((ref) => PrinterSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Navigator(
              onPopPage: (route, result) {
                popped = true;
                return route.didPop(result);
              },
              pages: [
                const MaterialPage(child: Scaffold(body: Text('Parent Screen'))),
                MaterialPage(child: ZReportScreen(shift: closedShift)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('TC-SFT-20: Responsive layouts (Mobile 412x915, Small 330x700, Desktop 1200x800) render with 0 overflow', (tester) async {
      final closedShift = _createSampleShift(isOpen: false, actualCash: 18500.0);

      // 1. Mobile Portrait
      tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrapWithProviders(child: ZReportScreen(shift: closedShift)));
      await tester.pumpAndSettle();
      expect(find.text('Day-End Z-Report'), findsOneWidget);

      // 2. Compact Screen
      tester.view.physicalSize = const Size(330 * 2.0, 700 * 2.0);
      await tester.pumpWidget(_wrapWithProviders(child: ZReportScreen(shift: closedShift)));
      await tester.pumpAndSettle();
      expect(find.text('Day-End Z-Report'), findsOneWidget);

      // 3. Desktop
      tester.view.physicalSize = const Size(1200 * 1.0, 800 * 1.0);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(_wrapWithProviders(child: ZReportScreen(shift: closedShift)));
      await tester.pumpAndSettle();
      expect(find.text('Day-End Z-Report'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
