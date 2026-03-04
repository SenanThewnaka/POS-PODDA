import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

// All analytics tracking goes here - easy to find and update
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Use this in MaterialApp's navigatorObservers
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // Don't log in debug mode, keeps console clean
  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) return;
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  // Auth
  static Future<void> logLogin(String method) =>
      _log('login', {'method': method});

  static Future<void> logSignUp() => _log('sign_up');

  static Future<void> setUserProperties({
    required String userId,
    required String plan,
    required String role,
  }) async {
    if (kDebugMode) return;
    await _analytics.setUserId(id: userId);
    await _analytics.setUserProperty(name: 'plan', value: plan);
    await _analytics.setUserProperty(name: 'role', value: role);
  }

  // Sales
  static Future<void> logSaleCompleted({
    required double totalAmount,
    required String paymentMethod,
    required int itemCount,
  }) =>
      _log('sale_completed', {
        'total_amount': totalAmount.toInt(),
        'payment_method': paymentMethod,
        'item_count': itemCount,
      });

  static Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double price,
  }) =>
      _log('add_to_cart', {
        'item_id': productId,
        'item_name': productName,
        'price': price.toInt(),
      });

  // Inventory
  static Future<void> logProductAdded() => _log('product_added');

  static Future<void> logLowStockViewed(int count) =>
      _log('low_stock_viewed', {'count': count});

  // Credit
  static Future<void> logCreditSale({required double amount}) =>
      _log('credit_sale', {'amount': amount.toInt()});

  static Future<void> logPaymentSettled({required double amount}) =>
      _log('payment_settled', {'amount': amount.toInt()});

  static Future<void> logCustomerAdded() => _log('customer_added');

  // Subscription
  static Future<void> logUpgradePromptShown(String reason) =>
      _log('upgrade_prompt_shown', {'reason': reason});

  static Future<void> logSubscriptionUpgraded(String plan) =>
      _log('subscription_upgraded', {'plan': plan});

  // Reports
  static Future<void> logReportViewed(String filterType) =>
      _log('report_viewed', {'filter': filterType});
}
