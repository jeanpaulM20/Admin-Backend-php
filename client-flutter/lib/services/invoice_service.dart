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
}
