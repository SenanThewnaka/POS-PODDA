import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class PaymentsLkCheckoutResult {
  final String checkoutId;
  final String? paymentId;
  final String url;
  final String status;
  final int amountCents;

  PaymentsLkCheckoutResult({
    required this.checkoutId,
    this.paymentId,
    required this.url,
    required this.status,
    required this.amountCents,
  });

  factory PaymentsLkCheckoutResult.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>?;
    return PaymentsLkCheckoutResult(
      checkoutId: json['id'] ?? '',
      paymentId: payment?['id'] as String?,
      url: json['url'] ?? '',
      status: json['status'] ?? 'open',
      amountCents: (payment?['amountCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaymentsLkPaymentResult {
  final String id;
  final String status;
  final int amountCents;
  final String? reference;
  final DateTime? succeededAt;

  PaymentsLkPaymentResult({
    required this.id,
    required this.status,
    required this.amountCents,
    this.reference,
    this.succeededAt,
  });

  bool get isSucceeded => status == 'succeeded';

  factory PaymentsLkPaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentsLkPaymentResult(
      id: json['id'] ?? '',
      status: json['status'] ?? 'unknown',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      reference: json['reference'] as String?,
      succeededAt: json['succeededAt'] != null
          ? DateTime.tryParse(json['succeededAt'])
          : null,
    );
  }
}

class PaymentsLkService {
  final String apiKey;
  final http.Client _client;
  final String baseUrl;
  final FirebaseFunctions? _functions;

  PaymentsLkService({
    this.apiKey = 'sk_test_6mCLo77J9PgL6TFt0HX2ddCVSChgDFNW',
    http.Client? client,
    this.baseUrl = 'https://api.payments.lk/v1',
    FirebaseFunctions? functions,
  })  : _client = client ?? http.Client(),
        _functions = functions;

  FirebaseFunctions get functionsInstance =>
      _functions ?? FirebaseFunctions.instance;

  /// Secure Cloud Function: Creates checkout session server-to-server.
  /// Eliminates CORS issues on Web, PWA, Android, and iOS while protecting secret keys.
  Future<PaymentsLkCheckoutResult> createCheckoutViaCloudFunction({
    required String tier,
    required String cycleKey,
  }) async {
    final callable = functionsInstance.httpsCallable('createCheckoutSession');
    final response = await callable.call({
      'tier': tier,
      'cycleKey': cycleKey,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    return PaymentsLkCheckoutResult(
      checkoutId: data['checkoutId'] as String? ?? '',
      paymentId: data['paymentId'] as String?,
      url: data['checkoutUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
    );
  }

  /// Secure Cloud Function: Verifies payment on server and updates Firestore.
  Future<Map<String, dynamic>> verifyPaymentViaCloudFunction({
    String? paymentId,
    String? checkoutId,
  }) async {
    final callable = functionsInstance.httpsCallable('verifyPaymentSession');
    final response = await callable.call({
      if (paymentId != null) 'paymentId': paymentId,
      if (checkoutId != null) 'checkoutId': checkoutId,
    });

    return Map<String, dynamic>.from(response.data as Map);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  /// Create a checkout session on Payments.lk
  Future<PaymentsLkCheckoutResult> createCheckout({
    required int amountCents,
    required String description,
    required String reference,
    String? customerEmail,
    String? customerName,
    String? customerPhone,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final url = Uri.parse('$baseUrl/checkouts');

    final body = {
      'amountCents': amountCents,
      'description': description,
      'reference': reference,
      if (successUrl != null) 'successUrl': successUrl,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
      if (customerEmail != null || customerName != null || customerPhone != null)
        'customer': {
          if (customerEmail != null && customerEmail.isNotEmpty)
            'email': customerEmail,
          if (customerName != null && customerName.isNotEmpty)
            'name': customerName,
          if (customerPhone != null && customerPhone.isNotEmpty)
            'phone': customerPhone,
        },
    };

    final response = await _client.post(
      url,
      headers: {
        ..._headers,
        'Idempotency-Key': 'chk_${reference}_${DateTime.now().millisecondsSinceEpoch}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PaymentsLkCheckoutResult.fromJson(json);
    } else {
      throw Exception('Payments.lk checkout creation failed (${response.statusCode}): ${response.body}');
    }
  }

  /// Check payment status by Payment ID
  Future<PaymentsLkPaymentResult> getPayment(String paymentId) async {
    final url = Uri.parse('$baseUrl/payments/$paymentId');

    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PaymentsLkPaymentResult.fromJson(json);
    } else {
      throw Exception('Payments.lk get payment failed (${response.statusCode}): ${response.body}');
    }
  }

  void dispose() {
    _client.close();
  }
}

final paymentsLkServiceProvider = Provider<PaymentsLkService>((ref) {
  final service = PaymentsLkService();
  ref.onDispose(() => service.dispose());
  return service;
});
