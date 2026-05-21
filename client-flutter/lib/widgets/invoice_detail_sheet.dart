import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';

/// Shared invoice detail bottom sheet with QR-Rechnung support.
///
/// Usage:
/// ```dart
/// InvoiceDetailSheet.show(context, invoice: myInvoice);
/// ```
class InvoiceDetailSheet extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailSheet({
    super.key,
    required this.invoice,
  });

  /// Convenience: opens the sheet as a modal bottom sheet.
  static void show(BuildContext context, {
    required Invoice invoice,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InvoiceDetailSheet(
        invoice: invoice,
      ),
    );
  }

  @override
  State<InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<InvoiceDetailSheet> {
  final InvoiceService _service = InvoiceService();
  bool _qrLoading = false;
  Uint8List? _qrImage;
  String? _qrError;

  Invoice get inv => widget.invoice;

  String _fmt(DateTime? dt) =>
      dt == null ? '-' : DateFormat('dd.MM.yyyy').format(dt);

  Future<void> _loadQr() async {
    setState(() { _qrLoading = true; _qrError = null; });
    final bytes = await _service.fetchQrBill(
      invoiceNumber: inv.invoiceNumber,
    );
    if (!mounted) return;
    setState(() {
      _qrLoading = false;
      if (bytes != null) {
        _qrImage = bytes;
      } else {
        _qrError = 'QR-Rechnung konnte nicht geladen werden.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = inv.isPaid;
    final statusColor = isPaid ? AppColors.green : AppColors.primary;
    final statusBg = isPaid
        ? AppColors.green.withOpacity(0.12)
        : AppColors.primary.withOpacity(0.12);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ── Header row ──
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rechnung ${inv.invoiceNumber}',
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(isPaid ? 'Bezahlt' : 'Offen',
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Text(
                    '${inv.currency} ${inv.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),

            // ── Detail rows ──
            if (inv.packageName != null)
              _detailRow('Paket', inv.packageName!),
            if (inv.credits != null)
              _detailRow('Lektionen',
                  '${inv.credits} × 60 Min. Personal Training'),
            if (inv.durationMonths != null)
              _detailRow('Gültigkeit',
                  '${inv.durationMonths} ${inv.durationMonths == 1 ? "Monat" : "Monate"}'),
            _detailRow('Rechnungsdatum', _fmt(inv.transactionDate)),
            _detailRow('Fällig am', _fmt(inv.dueDate)),
            const SizedBox(height: 16),

            // ── Payment info box ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zahlungsinformationen',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      'SIHLHEALTH GmbH\nVerwendungszweck: ${inv.invoiceNumber}',
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.5)),
                ],
              ),
            ),

            // ── QR-Rechnung section ──
            if (!isPaid) ...[
              const SizedBox(height: 16),
              if (_qrImage == null && !_qrLoading && _qrError == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadQr,
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('QR-Rechnung anzeigen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                          color: AppColors.primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (_qrLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (_qrError != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_qrError!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loadQr,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Erneut versuchen'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
              if (_qrImage != null) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    _qrImage!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
