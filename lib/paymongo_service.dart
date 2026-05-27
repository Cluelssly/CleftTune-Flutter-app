import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymongoService {
  static const _publicKey = 'pk_test_D1CrzWbhj7DEJWT2Aez1g2GE';

  // SECRET KEY REMOVED
  static const _secretKey = '';

  static const _baseUrl = 'https://api.paymongo.com/v1';

  static String _basicAuth(String key) =>
      'Basic ${base64Encode(utf8.encode('$key:'))}';

  // ─── SOURCES API: GCash ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createSource({
    required String type,
    required int amountCentavos,
    required String successUrl,
    required String failedUrl,
    required String name,
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sources'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _basicAuth(_publicKey),
      },
      body: jsonEncode({
        'data': {
          'attributes': {
            'type': type,
            'amount': amountCentavos,
            'currency': 'PHP',
            'redirect': {
              'success': successUrl,
              'failed': failedUrl,
            },
            'billing': {
              'name': name,
              'email': email,
            },
          },
        },
      }),
    );

    final json = jsonDecode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        json['errors']?[0]?['detail'] ?? 'Source creation failed',
      );
    }

    return json['data'] as Map<String, dynamic>;
  }

  static String checkoutUrlFrom(Map<String, dynamic> source) {
    return source['attributes']['redirect']['checkout_url'] as String;
  }

  // ─── PAYMENT INTENT API: Maya ─────────────────────────────────────────────
  static Future<String> createPaymentIntentCheckoutUrl({
    required String paymentMethodType,
    required int amountCentavos,
    required String successUrl,
    required String failedUrl,
    required String name,
    required String email,
  }) async {
    // Step 1: Create Payment Intent
    final intentRes = await http.post(
      Uri.parse('$_baseUrl/payment_intents'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _basicAuth(_secretKey),
      },
      body: jsonEncode({
        'data': {
          'attributes': {
            'amount': amountCentavos,
            'currency': 'PHP',
            'payment_method_allowed': [paymentMethodType],
            'capture_type': 'automatic',
          },
        },
      }),
    );

    final intentJson = jsonDecode(intentRes.body);

    if (intentRes.statusCode != 200 && intentRes.statusCode != 201) {
      throw Exception(
        intentJson['errors']?[0]?['detail'] ??
            'Payment Intent creation failed',
      );
    }

    final intentId = intentJson['data']['id'] as String;

    final clientKey =
        intentJson['data']['attributes']['client_key'] as String;

    // Step 2: Build Payment Method attributes
    final Map<String, dynamic> methodAttributes = {
      'type': paymentMethodType,
      'billing': {
        'name': name,
        'email': email,
      },
    };

    if (paymentMethodType == 'dob') {
      methodAttributes['details'] = {
        'bank_code': 'bank_AQUZMXsZUXY4Wg1MRfFpPWTB',
      };
    }

    // Step 3: Create Payment Method
    final methodRes = await http.post(
      Uri.parse('$_baseUrl/payment_methods'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _basicAuth(_publicKey),
      },
      body: jsonEncode({
        'data': {
          'attributes': methodAttributes,
        },
      }),
    );

    final methodJson = jsonDecode(methodRes.body);

    if (methodRes.statusCode != 200 && methodRes.statusCode != 201) {
      throw Exception(
        methodJson['errors']?[0]?['detail'] ??
            'Payment Method creation failed',
      );
    }

    final paymentMethodId = methodJson['data']['id'] as String;

    // Step 4: Attach Payment Method to Intent
    final attachRes = await http.post(
      Uri.parse('$_baseUrl/payment_intents/$intentId/attach'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _basicAuth(_publicKey),
      },
      body: jsonEncode({
        'data': {
          'attributes': {
            'payment_method': paymentMethodId,
            'client_key': clientKey,
            'return_url': successUrl,
          },
        },
      }),
    );

    final attachJson = jsonDecode(attachRes.body);

    if (attachRes.statusCode != 200 && attachRes.statusCode != 201) {
      throw Exception(
        attachJson['errors']?[0]?['detail'] ?? 'Attach failed',
      );
    }

    final nextAction =
        attachJson['data']['attributes']['next_action'];

    final checkoutUrl =
        nextAction?['redirect']?['url'] as String?;

    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception(
        'No redirect URL returned. Make sure Maya is enabled in your PayMongo dashboard.',
      );
    }

    return checkoutUrl;
  }
}