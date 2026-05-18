import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/credits_provider.dart';
import '../models/buyable_credit.dart';
import '../services/credits_service.dart';
import '../services/payment_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<CreditsProvider>().fetch(auth.clientId!);
    }
  }

  final PaymentService _paymentService = PaymentService();

  // ── Purchase flow ──────────────────────────────────────────────────────────

  Future<void> _startPurchase(CreditPackage pkg) async {
    // Step 1: Show AGB
    final agbAccepted = await _showAgbSheet(pkg);
    if (agbAccepted != true || !mounted) return;

    // Step 2: Payment method choice
    final method = await _showPaymentMethodSheet(pkg);
    if (method == null || !mounted) return;

    if (method == 'online') {
      // Step 3a: Online payment (Saferpay)
      await _executeOnlinePayment(pkg);
    } else {
      // Step 3b: Bank transfer (existing flow)
      final confirmed = await _showConfirmDialog(pkg);
      if (confirmed != true || !mounted) return;
      await _executePurchase(pkg);
    }
  }

  /// Shows a bottom sheet to choose payment method.
  Future<String?> _showPaymentMethodSheet(CreditPackage pkg) {
    final priceFormatted = NumberFormat('#,##0.00', 'de_CH').format(pkg.price);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Zahlungsmethode wählen',
                style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${pkg.name} – CHF $priceFormatted',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 20),

            // Online payment option
            _PaymentMethodTile(
              icon: Icons.credit_card_rounded,
              title: 'Online bezahlen',
              subtitle: 'Kreditkarte, TWINT, PostFinance, Apple Pay',
              onTap: () => Navigator.pop(ctx, 'online'),
            ),
            const SizedBox(height: 10),

            // Bank transfer / QR-Rechnung option
            _PaymentMethodTile(
              icon: Icons.account_balance_rounded,
              title: 'Bankueberweisung',
              subtitle: 'Rechnung per E-Mail mit QR-Einzahlungsschein',
              onTap: () => Navigator.pop(ctx, 'bank'),
            ),
          ],
        ),
      ),
    );
  }

  /// Execute online payment via Saferpay.
  Future<void> _executeOnlinePayment(CreditPackage pkg) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Zahlung wird vorbereitet...'),
        ]),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 15),
      ),
    );

    try {
      final auth = context.read<AuthProvider>();
      final result = await _paymentService.initialize(
        clientId: auth.clientId!,
        packageId: int.parse(pkg.id),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Open Saferpay payment page in new browser tab
      html.window.open(result.redirectUrl, '_blank');

      // Show polling dialog
      if (mounted) {
        await _showPaymentPendingDialog(result.invoiceNumber);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  /// Shows a dialog while the user completes payment in the browser.
  /// Polls payment status until paid or user dismisses.
  Future<void> _showPaymentPendingDialog(String invoiceNumber) async {
    bool isPaid = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentPendingDialog(
        invoiceNumber: invoiceNumber,
        paymentService: _paymentService,
        onPaid: () {
          isPaid = true;
          Navigator.pop(ctx);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );

    if (isPaid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zahlung erfolgreich! Paket aktiviert.'),
          backgroundColor: AppColors.green,
          duration: Duration(seconds: 4),
        ),
      );
      await _loadData();
    }
  }

  Future<bool?> _showAgbSheet(CreditPackage pkg) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool accepted = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollCtrl) => Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(2)),
                    )),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Allgemeine Geschaeftsbedingungen',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  // AGB content
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: const [
                        _AgbItem(num: '1', title: 'Terminvereinbarung',
                            text: 'Fuer den Bezug saemtlicher Leistungen ist eine Terminvereinbarung (online oder telefonisch) erforderlich.'),
                        _AgbItem(num: '2', title: 'Absagefrist',
                            text: 'Verhindert der Klient die Wahrnehmung eines Termins, ist die SIHLHEALTH GmbH spaetestens 24 Stunden im Voraus zu informieren. Bei verspaeteter Absage oder Nichterscheinen gilt die Leistung als erbracht und ist vollumfaenglich geschuldet – auch bei unverschuldeter Verhinderung (ausgenommen aerztlich belegte Krankheit oder Unfall). Verspaetungen fuehren nicht zu einer Verlaengerung der Trainingszeit.'),
                        _AgbItem(num: '3', title: 'Zahlungskonditionen',
                            text: 'Der Preis ist vor Leistungsbezug faellig. Abos sind innert 7 Tagen ab Unterzeichnung zahlbar. Die SIHLHEALTH GmbH behaelt sich vor, Leistungen bei Zahlungsverzug auszusetzen.'),
                        _AgbItem(num: '4', title: 'Gueltigkeit',
                            text: 'Nicht genutzte Leistungen verfallen nach Ablauf der Abo-Gueltigkeit ohne Anspruch auf Rueckerstattung.'),
                        _AgbItem(num: '5', title: 'Depot',
                            text: 'Fuer den Herzfrequenzsensor wird ein Depot von CHF 20.00 erhoben, welches bei unbeschaedigter Rueckgabe nach Vertragsende erstattet wird.'),
                        _AgbItem(num: '6', title: 'Gesundheitszustand',
                            text: 'Der Klient bestaetigt seine Sporttauglichkeit. Er verpflichtet sich, die SIHLHEALTH GmbH ueber koerperliche Einschraenkungen oder gesundheitliche Risiken proaktiv zu informieren. Das Training erfolgt auf eigenes Risiko.'),
                        _AgbItem(num: '7', title: 'Versicherung & Haftung',
                            text: 'Versicherung ist Sache des Klienten. Soweit gesetzlich zulaessig, wird jegliche Haftung der SIHLHEALTH GmbH fuer Personen- oder Sachschaeden ausgeschlossen.'),
                        _AgbItem(num: '8', title: 'Wertsachen',
                            text: 'Fuer Verlust oder Beschaedigung von persoenlichen Gegenstaenden wird keine Haftung uebernommen.'),
                        _AgbItem(num: '9', title: 'Uebertragbarkeit',
                            text: 'Leistungsansprueche sind persoenlich und nicht auf Dritte uebertragbar.'),
                        _AgbItem(num: '10', title: 'Datenschutz',
                            text: 'Personenbezogene Daten werden nur im Rahmen der Leistungserbringung erhoben und verarbeitet.'),
                        _AgbItem(num: '11', title: 'Schlussbestimmungen',
                            text: 'Aenderungen beduerfen der Schriftform. Sollten einzelne Bestimmungen unwirksam sein, bleibt der Rest des Vertrages gueltig.'),
                        _AgbItem(num: '12', title: 'Gerichtsstand',
                            text: 'Gerichtsstand fuer alle Streitigkeiten ist Zuerich.'),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Accept checkbox + button
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setModalState(() => accepted = !accepted),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: accepted ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: accepted ? AppColors.primary : AppColors.muted),
                              ),
                              child: accepted
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: Text(
                              'Ich habe die AGB gelesen und akzeptiere diese.',
                              style: TextStyle(color: AppColors.text, fontSize: 13),
                            )),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: accepted ? () => Navigator.pop(ctx, true) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              disabledBackgroundColor: AppColors.muted.withAlpha(40),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('AGB akzeptieren', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog(CreditPackage pkg) {
    final priceFormatted = NumberFormat('#,##0.00', 'de_CH').format(pkg.price);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Kauf bestaetigen',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withAlpha(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pkg.name, style: const TextStyle(
                    color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800,
                  )),
                  const SizedBox(height: 6),
                  _metaRow('Lektionen', '${pkg.credits}'),
                  if (pkg.durationMonths != null)
                    _metaRow('Gueltigkeit', '${pkg.durationMonths} Monate'),
                  _metaRow('Preis', 'CHF $priceFormatted'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Die Rechnung wird per E-Mail zugestellt und ist innert 7 Tagen zahlbar.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Kauf bestaetigen'),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
        Text(value, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _executePurchase(CreditPackage pkg) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Paket wird gebucht...'),
        ]),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 15),
      ),
    );

    try {
      final auth = context.read<AuthProvider>();
      final service = CreditsService();
      final result = await service.purchasePackage(auth.clientId!, pkg.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final success = result['success'] == true;
      final message = result['message']?.toString() ?? (success ? 'Paket gebucht!' : 'Fehler beim Kauf');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.green : AppColors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      if (success) {
        // Reload credits
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<CreditsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: credits.isLoading
              ? const LoadingIndicator(message: 'Lade Credits...')
              : credits.error != null
                  ? ErrorView(message: credits.error!, onRetry: _loadData)
                  : _CreditsContent(
                      credits: credits.data,
                      packages: credits.packages,
                      onPurchase: _startPurchase,
                    ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AGB Item
// ═══════════════════════════════════════════════════════════════════════════════

class _AgbItem extends StatelessWidget {
  final String num;
  final String title;
  final String text;

  const _AgbItem({required this.num, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(num, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
            ],
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main content
// ═══════════════════════════════════════════════════════════════════════════════

class _CreditsContent extends StatelessWidget {
  final List<ClientCredit> credits;
  final List<CreditPackage> packages;
  final ValueChanged<CreditPackage> onPurchase;

  const _CreditsContent({
    required this.credits,
    required this.packages,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int activeCredits = 0;
    for (final c in credits) {
      final isExpired = c.expires != null &&
          (DateTime.tryParse(c.expires!)?.isBefore(now) ?? false);
      final notYetStarted = c.startdate != null &&
          (DateTime.tryParse(c.startdate!)?.isAfter(now) ?? false);
      if (!isExpired && !notYetStarted) {
        activeCredits += c.remaining;
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(activeCredits: activeCredits, packCount: credits.length),
        const SizedBox(height: 8),
        if (credits.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.toll_outlined, title: 'Deine Credits'),
          ...credits.map((c) => _CreditPackCard(credit: c)),
          const SizedBox(height: 16),
        ],
        if (packages.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.local_offer_outlined, title: 'Unsere Pakete'),
          ...packages.map((p) => _PackageCard(package: p, onPurchase: () => onPurchase(p))),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Summary Card
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final int activeCredits;
  final int packCount;

  const _SummaryCard({required this.activeCredits, required this.packCount});

  @override
  Widget build(BuildContext context) {
    final hasCredits = activeCredits > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: (hasCredits ? AppColors.primary : AppColors.orange).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            hasCredits ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: hasCredits ? AppColors.primary : AppColors.orange,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasCredits
                  ? '$activeCredits Credit${activeCredits != 1 ? 's' : ''} verfügbar'
                  : 'Keine aktiven Credits',
              style: TextStyle(
                color: hasCredits ? AppColors.primary : AppColors.orange,
                fontSize: 17, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasCredits
                  ? 'Aus $packCount Credit-Paket${packCount != 1 ? 'en' : ''}'
                  : 'Waehle ein Paket und bestelle direkt',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(
          color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Client's credit pack card
// ═══════════════════════════════════════════════════════════════════════════════

class _CreditPackCard extends StatelessWidget {
  final ClientCredit credit;

  const _CreditPackCard({required this.credit});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction = credit.paid > 0 ? credit.remaining / credit.paid : 0.0;
    final isExpired = credit.expires != null &&
        DateTime.tryParse(credit.expires!)?.isBefore(DateTime.now()) == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.toll_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(credit.title, style: const TextStyle(
                  color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 2),
                Text('${credit.remaining} von ${credit.paid} verbleibend',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isExpired ? AppColors.red : AppColors.primary).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${credit.remaining} / ${credit.paid}',
                style: TextStyle(
                  color: isExpired ? AppColors.red : AppColors.primary,
                  fontSize: 13, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isExpired ? AppColors.red : AppColors.primary),
            ),
          ),
          if (credit.startdate != null || credit.expires != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (credit.startdate != null) ...[
                const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.muted),
                const SizedBox(width: 4),
                Text('Ab ${_formatDate(credit.startdate)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
              if (credit.startdate != null && credit.expires != null) const SizedBox(width: 12),
              if (credit.expires != null) ...[
                Icon(Icons.event_busy_rounded, size: 12,
                    color: isExpired ? AppColors.red : AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  isExpired
                      ? 'Abgelaufen ${_formatDate(credit.expires)}'
                      : 'Gueltig bis ${_formatDate(credit.expires)}',
                  style: TextStyle(
                    color: isExpired ? AppColors.red : AppColors.muted, fontSize: 11,
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Package card with buy button
// ═══════════════════════════════════════════════════════════════════════════════

class _PackageCard extends StatelessWidget {
  final CreditPackage package;
  final VoidCallback onPurchase;

  const _PackageCard({required this.package, required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    final priceFormatted = NumberFormat('#,##0', 'de_CH').format(package.price);
    final perSession = package.pricePerSession != null
        ? 'CHF ${package.pricePerSession!.toStringAsFixed(0)} / Lektion'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Name left, Price right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(package.name, style: const TextStyle(
                    color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800,
                  )),
                  if (package.description != null) ...[
                    const SizedBox(height: 4),
                    Text(package.description!, style: const TextStyle(
                      color: AppColors.muted, fontSize: 13,
                    )),
                  ],
                ],
              )),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "CHF $priceFormatted",
                    style: const TextStyle(
                      color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (perSession != null) ...[
                    const SizedBox(height: 2),
                    Text(perSession, style: const TextStyle(
                      color: AppColors.muted, fontSize: 12,
                    )),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details row
          Row(children: [
            _pkgDetail(Icons.fitness_center_rounded,
                '${package.credits} ${package.credits == 1 ? "Lektion" : "Lektionen"}'),
            const SizedBox(width: 16),
            if (package.durationMonths != null)
              _pkgDetail(Icons.schedule_outlined,
                  '${package.durationMonths} ${package.durationMonths == 1 ? "Monat" : "Monate"} gueltig'),
          ]),

          if (package.includes != null && package.includes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            ...package.includes!.split(', ').map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                const Icon(Icons.check_circle_outlined, size: 15, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(
                  color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500,
                ))),
              ]),
            )),
          ],

          const SizedBox(height: 14),

          // Buy button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.shopping_cart, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Paket kaufen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pkgDetail(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ]);
  }
}

// ═══════════════════════════════���═══════════════════════════════════════════════
// Payment method tile
// ═══════════════════════════════════════════════════════════════════════════════

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(
                  color: AppColors.muted, fontSize: 12,
                )),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 22),
          ]),
        ),
      ),
    );
  }
}

// ═══════��═══════════════════════════════════════════════════════════════════════
// Payment pending dialog (polls status while user pays in browser)
// ═══════════════════════════════════════���═══════════════════════════════════════

class _PaymentPendingDialog extends StatefulWidget {
  final String invoiceNumber;
  final PaymentService paymentService;
  final VoidCallback onPaid;
  final VoidCallback onCancel;

  const _PaymentPendingDialog({
    required this.invoiceNumber,
    required this.paymentService,
    required this.onPaid,
    required this.onCancel,
  });

  @override
  State<_PaymentPendingDialog> createState() => _PaymentPendingDialogState();
}

class _PaymentPendingDialogState extends State<_PaymentPendingDialog> {
  bool _polling = true;

  @override
  void initState() {
    super.initState();
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    while (_polling && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) break;

      final status = await widget.paymentService.checkStatus(widget.invoiceNumber);
      if (status == 'paid') {
        _polling = false;
        if (mounted) widget.onPaid();
        return;
      }
    }
  }

  @override
  void dispose() {
    _polling = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
          strokeWidth: 2.5, color: AppColors.primary,
        )),
        SizedBox(width: 14),
        Text('Zahlung laeuft...', style: TextStyle(
          color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700,
        )),
      ]),
      content: const Text(
        'Bitte schliesse die Zahlung im Browser ab.\n\nDieses Fenster schliesst automatisch nach erfolgreicher Zahlung.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _polling = false;
            widget.onCancel();
          },
          child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton(
          onPressed: () async {
            // Manual check
            final status = await widget.paymentService.checkStatus(widget.invoiceNumber);
            if (status == 'paid' && mounted) {
              _polling = false;
              widget.onPaid();
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Zahlung noch nicht abgeschlossen'),
                  backgroundColor: AppColors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Status pruefen'),
        ),
      ],
    );
  }
}
