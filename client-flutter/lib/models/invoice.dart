class Invoice {
  final String invoiceNumber;
  final String status;
  final DateTime? transactionDate;
  final DateTime? dueDate;
  final String currency;
  final double amount;

  Invoice({
    required this.invoiceNumber,
    required this.status,
    this.transactionDate,
    this.dueDate,
    required this.currency,
    required this.amount,
  });

  bool get isPaid =>
      status.toLowerCase() == 'bezahlt' || status.toLowerCase() == 'paid';

  factory Invoice.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return Invoice(
      invoiceNumber: json['invoiceNumber']?.toString() ??
          json['invoice_number']?.toString() ??
          json['number']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      transactionDate: parseDate(json['transactionDate'] ?? json['transaction_date'] ?? json['date']),
      dueDate: parseDate(json['dueDate'] ?? json['due_date']),
      currency: json['currency']?.toString() ?? 'CHF',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
    );
  }
}
