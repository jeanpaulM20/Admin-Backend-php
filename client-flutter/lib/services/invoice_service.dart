import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import 'api_client.dart';

class InvoiceService {
  Future<List<Invoice>> listInvoices(String clientId) async {
    final data = await apiClient.get('api/client/invoices/$clientId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Invoice.fromJson)
          .toList();
    }
    return [];
  }

  /// Fetches the Swiss QR payment slip (base64 PNG) for a given invoice.
  /// Amount is determined server-side from the invoice record (not client-supplied).
  /// Returns decoded image bytes or null if generation fails.
  Future<Uint8List?> fetchQrBill({
    required String invoiceNumber,
  }) async {
    try {
      final data = await apiClient.get(
        'api/client/invoice-qr/$invoiceNumber',
      );
      if (data is Map && data['success'] == true && data['base64'] != null) {
        return base64Decode(data['base64']);
      }
      return null;
    } catch (e) {
      debugPrint('fetchQrBill error: $e');
      return null;
    }
  }
}
