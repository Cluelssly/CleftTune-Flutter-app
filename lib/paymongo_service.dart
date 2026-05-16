// lib/services/paymongo_service.dart
//
// ⚠️  Only your PUBLIC key goes here (pk_test_... or pk_live_...).
//     Never put your secret key in Flutter code.

import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymongoService {
  // ── REPLACE with your real PayMongo public key ──────────────────────────────
  static const _publicKey = 'pk_live_iVpx5yFRt94HcxJPmx1EsQ9z';
  // ────────────────────────────────────────────────────────────────────────────

  static String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('$_publicKey:'))}';

  static const _baseUrl = 'https://api.paymongo.com/v1';

  /// Creates a PayMongo Source for GCash or Maya.
  /// Returns the full source object (contains checkout_url inside attributes.redirect).
  ///
  /// [type]             → 'gcash' | 'paymaya'
  /// [amountCentavos]   → amount in centavos  e.g. 9900 = ₱99
  /// [successUrl]       → where PayMongo redirects after successful payment
  /// [failedUrl]        → where PayMongo redirects after failed / cancelled payment
  static Future<Map<String, dynamic>> createSource({
    required String type,
    required int amountCentavos,
    required String successUrl,
    required String failedUrl,
    required String name,
    required String email,
    String phone = '09000000000',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sources'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
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
              'phone': phone,
            },
          },
        },
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['data'] as Map<String, dynamic>;
    } else {
      final errors = body['errors'] as List?;
      final detail = errors?.isNotEmpty == true
          ? errors![0]['detail']
          : 'Unknown PayMongo error';
      throw Exception(detail);
    }
  }

  /// Extracts the checkout URL from a source object returned by [createSource].
  static String checkoutUrlFrom(Map<String, dynamic> source) {
    return source['attributes']['redirect']['checkout_url'] as String;
  }

  /// Extracts the source ID (needed for webhook / server-side payment capture).
  static String idFrom(Map<String, dynamic> source) {
    return source['id'] as String;
  }
}