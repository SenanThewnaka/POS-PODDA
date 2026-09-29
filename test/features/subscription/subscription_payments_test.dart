import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sme_buddy/features/subscription/subscription_plan_model.dart';
import 'package:sme_buddy/features/subscription/payments_lk_service.dart';
import 'package:sme_buddy/features/subscription/plans_screen.dart';
import 'package:sme_buddy/features/subscription/subscription_info_card.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

void main() {
  group('SubscriptionBillingOption Model Tests', () {
    test('contains exactly 4 billing durations for Pro: 1M, 3M, 6M, 1Y', () {
      final options = SubscriptionBillingOption.proOptions;
      expect(options.length, 4);

      final opt1m = options[0];
      expect(opt1m.months, 1);
      expect(opt1m.durationDays, 30);
      expect(opt1m.priceLkr, 2900);
      expect(opt1m.amountCents, 290000);
      expect(opt1m.cycleKey, 'monthly');

      final opt3m = options[1];
      expect(opt3m.months, 3);
      expect(opt3m.durationDays, 90);
      expect(opt3m.priceLkr, 7900);
      expect(opt3m.amountCents, 790000);
      expect(opt3m.cycleKey, 'quarterly');
      expect(opt3m.savingsBadge, contains('800'));

      final opt6m = options[2];
      expect(opt6m.months, 6);
      expect(opt6m.durationDays, 180);
      expect(opt6m.priceLkr, 14900);
      expect(opt6m.amountCents, 1490000);
      expect(opt6m.cycleKey, 'semi_annual');
      expect(opt6m.savingsBadge, contains('2,500'));

      final opt1y = options[3];
      expect(opt1y.months, 12);
      expect(opt1y.durationDays, 365);
      expect(opt1y.priceLkr, 27900);
      expect(opt1y.amountCents, 2790000);
      expect(opt1y.cycleKey, 'yearly');
      expect(opt1y.isPopular, isTrue);
      expect(opt1y.savingsBadge, contains('6,900'));
    });

    test('contains exactly 4 billing durations for Plus: 1M, 3M, 6M, 1Y', () {
      final options = SubscriptionBillingOption.plusOptions;
      expect(options.length, 4);

      expect(options[0].priceLkr, 1500);
      expect(options[0].months, 1);

      expect(options[1].priceLkr, 4200);
      expect(options[1].months, 3);
      expect(options[1].savingsBadge, contains('300'));

      expect(options[2].priceLkr, 7900);
      expect(options[2].months, 6);
      expect(options[2].savingsBadge, contains('1,100'));

      expect(options[3].priceLkr, 14900);
      expect(options[3].months, 12);
      expect(options[3].savingsBadge, contains('3,100'));
      expect(options[3].isPopular, isTrue);
    });

    test('monthlyEffectivePrice calculates correct averages', () {
      final pro = SubscriptionBillingOption.proOptions;
      expect(pro[0].monthlyEffectivePrice, 2900.0);
      expect(pro[1].monthlyEffectivePrice, closeTo(2633.33, 0.1));
      expect(pro[2].monthlyEffectivePrice, closeTo(2483.33, 0.1));
      expect(pro[3].monthlyEffectivePrice, 2325.0);

      final plus = SubscriptionBillingOption.plusOptions;
      expect(plus[0].monthlyEffectivePrice, 1500.0);
      expect(plus[1].monthlyEffectivePrice, 1400.0);
      expect(plus[2].monthlyEffectivePrice, closeTo(1316.66, 0.1));
      expect(plus[3].monthlyEffectivePrice, closeTo(1241.66, 0.1));
    });
  });

  group('PaymentsLkService Client Tests', () {
    test('createCheckout sends proper request and parses checkout result', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/checkouts');
        expect(request.headers['Authorization'], 'Bearer sk_test_mock_key');
        expect(request.headers['Content-Type'], 'application/json');

        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['amountCents'], 790000);
        expect(payload['description'], 'POS Podda Pro - 3 Months Subscription');
        expect(payload['reference'], 'test-ref-001');
        expect(payload['customer']['email'], 'owner@shop.sme');

        return http.Response(
          jsonEncode({
            'object': 'checkout',
            'id': 'chk_test_123',
            'mode': 'test',
            'status': 'open',
            'url': 'https://payments.lk/checkout/chk_test_123',
            'payment': {
              'id': 'pay_test_456',
              'amountCents': 790000,
              'status': 'requires_payment_method',
            }
          }),
          200,
        );
      });

      final service = PaymentsLkService(
        apiKey: 'sk_test_mock_key',
        client: mockClient,
      );

      final result = await service.createCheckout(
        amountCents: 790000,
        description: 'POS Podda Pro - 3 Months Subscription',
        reference: 'test-ref-001',
        customerEmail: 'owner@shop.sme',
        customerName: 'Sunil Shop',
      );

      expect(result.checkoutId, 'chk_test_123');
      expect(result.paymentId, 'pay_test_456');
      expect(result.url, 'https://payments.lk/checkout/chk_test_123');
      expect(result.status, 'open');
      expect(result.amountCents, 790000);
    });

    test('getPayment verifies succeeded status', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/payments/pay_test_456');

        return http.Response(
          jsonEncode({
            'object': 'payment',
            'id': 'pay_test_456',
            'status': 'succeeded',
            'amountCents': 790000,
            'reference': 'test-ref-001',
            'succeededAt': '2026-09-28T12:00:00.000Z',
          }),
          200,
        );
      });

      final service = PaymentsLkService(
        apiKey: 'sk_test_mock_key',
        client: mockClient,
      );

      final result = await service.getPayment('pay_test_456');
      expect(result.id, 'pay_test_456');
      expect(result.status, 'succeeded');
      expect(result.isSucceeded, isTrue);
      expect(result.amountCents, 790000);
      expect(result.succeededAt, isNotNull);
    });
  });

  group('PlansScreen Widget Tests', () {
    testWidgets('renders both Plus and Pro tiers with 4 billing options each and allows switching', (tester) async {
      final testUser = UserModel(
        uid: 'owner-1',
        email: 'owner@test.sme',
        name: 'Sunil Perera',
        mobile: '0771234567',
        role: 'owner',
        shopId: 'shop-001',
        plan: 'trial',
        subscriptionStatus: 'active',
        billingCycle: 'trial',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: const MaterialApp(
            home: PlansScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and status
      expect(find.text("Subscription & Pricing"), findsOneWidget);
      expect(find.text("Choose Your Tier"), findsOneWidget);
      expect(find.text("Select Billing Cycle"), findsOneWidget);

      // Verify Tier tabs exist
      expect(find.text("Plus (+)"), findsOneWidget);
      expect(find.text("Pro"), findsOneWidget);

      // Verify all 4 billing cycle tabs exist
      expect(find.text("1 Month"), findsOneWidget);
      expect(find.text("3 Months"), findsOneWidget);
      expect(find.text("6 Months"), findsOneWidget);
      expect(find.text("1 Year"), findsOneWidget);
      expect(find.text("POPULAR"), findsOneWidget); // Badge on Pro tier tab
      expect(find.text("BEST"), findsOneWidget); // Popular badge on 1 Year option

      // Default selected tier is Pro, default cycle is 3 Months (Rs. 7,900)
      expect(find.text("Rs. 7,900"), findsOneWidget);
      expect(find.text("Save Rs. 800"), findsOneWidget);
      expect(find.text("PAY RS. 7,900 • 3 MONTHS PRO"), findsOneWidget);
      expect(find.text("INCLUDED PRO FEATURES"), findsOneWidget);

      // Tap 1 Year tab in Pro
      await tester.tap(find.text("1 Year"));
      await tester.pumpAndSettle();

      // Price and button should update to 1 Year Pro (Rs. 27,900)
      expect(find.text("Rs. 27,900"), findsOneWidget);
      expect(find.text("Best Value • Save Rs. 6,900"), findsOneWidget);
      expect(find.text("PAY RS. 27,900 • 1 YEAR PRO"), findsOneWidget);

      // Switch to Plus (+) tier
      await tester.tap(find.text("Plus (+)"));
      await tester.pumpAndSettle();

      // Should maintain 1 Year duration, but with Plus pricing (Rs. 14,900)
      expect(find.text("Rs. 14,900"), findsOneWidget);
      expect(find.text("Best Value • Save Rs. 3,100"), findsOneWidget);
      expect(find.text("PAY RS. 14,900 • 1 YEAR PLUS"), findsOneWidget);
      expect(find.text("INCLUDED PLUS (+) FEATURES"), findsOneWidget);

      // Switch to 1 Month in Plus (+)
      await tester.tap(find.text("1 Month"));
      await tester.pumpAndSettle();

      expect(find.text("Rs. 1,500"), findsOneWidget);
      expect(find.text("PAY RS. 1,500 • 1 MONTH PLUS"), findsOneWidget);

      // Switch to 3 Months in Plus (+)
      await tester.tap(find.text("3 Months"));
      await tester.pumpAndSettle();

      expect(find.text("Rs. 4,200"), findsOneWidget);
      expect(find.text("Save Rs. 300"), findsOneWidget);
      expect(find.text("PAY RS. 4,200 • 3 MONTHS PLUS"), findsOneWidget);

      // Gateway trust assurance
      expect(find.textContaining("Secured by Payments.lk"), findsOneWidget);
    });

    testWidgets('renders status banner when expiryDate is null', (tester) async {
      final testUser = UserModel(
        uid: 'owner-2',
        email: 'owner2@test.sme',
        name: 'Kasun Silva',
        mobile: '0779998888',
        role: 'owner',
        shopId: 'shop-002',
        plan: 'trial',
        subscriptionStatus: 'expired',
        billingCycle: 'trial',
        expiryDate: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: const MaterialApp(
            home: PlansScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Current Plan: TRIAL"), findsOneWidget);
      expect(find.text("No active subscription / Inactive"), findsOneWidget);
    });
  });

  group('SubscriptionInfoCard Widget Tests', () {
    testWidgets('renders active plan with EXTEND / MANAGE PLAN button', (tester) async {
      final activeUser = UserModel(
        uid: 'owner-3',
        email: 'active@test.sme',
        name: 'Amal',
        mobile: '0771112233',
        role: 'owner',
        shopId: 'shop-003',
        plan: 'pro',
        subscriptionStatus: 'active',
        billingCycle: 'yearly',
        expiryDate: DateTime.now().add(const Duration(days: 45)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(activeUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SubscriptionInfoCard()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("PRO"), findsOneWidget);
      expect(find.text("ACTIVE"), findsOneWidget);
      expect(find.textContaining("Days Remaining"), findsOneWidget);
      expect(find.text("EXTEND / MANAGE PLAN"), findsOneWidget);
    });

    testWidgets('renders expired plan with RENEW / EXTEND PLAN button', (tester) async {
      final expiredUser = UserModel(
        uid: 'owner-4',
        email: 'expired@test.sme',
        name: 'Kamal',
        mobile: '0774445566',
        role: 'owner',
        shopId: 'shop-004',
        plan: 'trial',
        subscriptionStatus: 'expired',
        billingCycle: 'monthly',
        expiryDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(expiredUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SubscriptionInfoCard()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("TRIAL"), findsOneWidget);
      expect(find.text("EXPIRED"), findsOneWidget);
      expect(find.text("RENEW / EXTEND PLAN"), findsOneWidget);
    });

    testWidgets('handles null expiryDate gracefully without throwing', (tester) async {
      final nullExpiryUser = UserModel(
        uid: 'owner-5',
        email: 'nullexpiry@test.sme',
        name: 'Nimal',
        mobile: '0777778888',
        role: 'owner',
        shopId: 'shop-005',
        plan: 'trial',
        subscriptionStatus: 'expired',
        billingCycle: 'monthly',
        expiryDate: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(nullExpiryUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SubscriptionInfoCard()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("TRIAL"), findsOneWidget);
      expect(find.text("EXPIRED"), findsOneWidget);
      expect(find.text("Your subscription is inactive."), findsOneWidget);
      expect(find.text("RENEW / EXTEND PLAN"), findsOneWidget);
    });
  });
}
