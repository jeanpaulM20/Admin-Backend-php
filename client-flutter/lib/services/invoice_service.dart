import 'dart:convert';
import 'dart:typed_data';
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
  /// Returns decoded image bytes or null if generation fails.
  Future<Uint8List?> fetchQrBill({
    required String invoiceNumber,
    required double amount,
    String? clientName,
  }) async {
    try {
      final query = StringBuffer(
        'api/client/invoice-qr/$invoiceNumber?amount=${amount.toStringAsFixed(2)}',
      );
      if (clientName != null && clientName.isNotEmpty) {
        query.write('&name=${Uri.encodeComponent(clientName)}');
      }
      final data = await apiClient.get(query.toString());
      if (data is Map && data['success'] == true && data['base64'] != null) {
        return base64Decode(data['base64']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
