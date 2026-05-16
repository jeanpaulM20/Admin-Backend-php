import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Service for Saferpay online payment integration.
class PaymentService {
  /// Check if online payment is available (Saferpay configured on backend).
  Future<bool> isAvailable() async {
    try {
      final data = await apiClient.get('api/client/payment/available');
      return data is Map && data['available'] == true;
    } catch (e) {
      debugPrint('PaymentService.isAvailable error: $e');
      return false;
    }
  }

  /// Initialize a Saferpay payment for a package purchase.
  /// Returns the redirect URL to open in WebView/browser, or throws on error.
  Future<PaymentInitResult> initialize({
    required String clientId,
    required int packageId,
  }) async {
    final data = await apiClient.post(
      'api/client/payment/initialize/$clientId',
      body: {'packageId': packageId},
    );

    if (data is Map<String, dynamic>) {
      if (data['success'] == true && data['redirectUrl'] != null) {
        return PaymentInitResult(
          redirectUrl: data['redirectUrl'],
          invoiceNumber: data['invoiceNumber'] ?? '',
        );
      }
      throw Exception(data['error'] ?? 'Zahlung konnte nicht gestartet werden');
    }
    throw Exception('Unbekannter Fehler');
  }

  /// Poll payment status after WebView/browser returns.
  Future<String> checkStatus(String invoiceNumber) async {
    try {
      final data = await apiClient.get(
        'api/client/payment/status/$invoiceNumber',
      );
      if (data is Map && data['success'] == true) {
        return data['status'] ?? 'pending';
      }
      return 'error';
    } catch (e) {
      debugPrint('PaymentService.checkStatus error: $e');
      return 'error';
    }
  }
}

class PaymentInitResult {
  final String redirectUrl;
  final String invoiceNumber;

  PaymentInitResult({
    required this.redirectUrl,
    required this.invoiceNumber,
  });
}
