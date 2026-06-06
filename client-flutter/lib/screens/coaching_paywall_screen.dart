import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../models/training_plan.dart';
import '../models/buyable_credit.dart';
import '../providers/auth_provider.dart';
import '../services/training_plan_service.dart';
import '../services/payment_service.dart';

/// Paywall shown when a client opens a locked plan. Presents the teaser plus
/// the coaching tiers and starts a Saferpay purchase (same pipeline as credits).
class CoachingPaywallScreen extends StatefulWidget {
  final ClientTrainingPlan plan;
  const CoachingPaywallScreen({super.key, required this.plan});

  @override
  State<CoachingPaywallScreen> createState() => _CoachingPaywallScreenState();
}

class _CoachingPaywallScreenState extends State<CoachingPaywallScreen> {
  final _service = TrainingPlanService();
  final _payment = PaymentService();

  static const _sectionLabels = {
    'sonsomo': 'Aufwärmen',
    'main': 'Haupttraining',
    'core': 'Core',
    'mobility': 'Mobilität',
  };

  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  List<CreditPackage> _packages = [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pkgs = await _service.listCoachingPackages();
      if (!mounted) return;
      setState(() {
        _packages = pkgs;
        _selectedId = pkgs.isNotEmpty ? pkgs.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _purchase() async {
    final pkgId = _selectedId;
    final auth = context.read<AuthProvider>();
    if (pkgId == null || auth.clientId == null) return;
    setState(() => _purchasing = true);
    try {
      final result = await _payment.initialize(
        clientId: auth.clientId!,
        packageId: int.tryParse(pkgId) ?? 0,
      );
      if (!mounted) return;
      html.window.open(result.redirectUrl, '_blank');
      _showPendingDialog(result.invoiceNumber);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.red,
      ));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _showPendingDialog(String invoiceNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Zahlung läuft',
            style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text(
          'Schließe die Zahlung im neuen Browser-Tab ab (Rechnung $invoiceNumber). '
          'Danach ist dein Online Coaching freigeschaltet.',
          style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // back to list (which re-fetches)
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Online Coaching',
            style: GoogleFonts.inter(
                color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _teaserCard(),
                const SizedBox(height: 20),
                Text('Trainingsplan · Chat-Feedback · Analysen',
                    style: GoogleFonts.inter(
                        color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Wähle dein Abo und schalte alle Pläne frei.',
                    style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 14),
                if (_error != null) _errorBox(_error!),
                ..._packages.map(_tierCard),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_purchasing || _selectedId == null) ? null : _purchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _purchasing
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Online Coaching freischalten',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _teaserCard() {
    final plan = widget.plan;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name ?? 'Trainingsplan',
              style: GoogleFonts.inter(
                  color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('${plan.totalExercises} Übungen in diesem Plan',
              style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ...plan.sections.entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_sectionLabels[e.key] ?? e.key}: ${e.value}',
                      style: GoogleFonts.inter(
                          color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                )),
          ]),
        ],
      ),
    );
  }

  Widget _tierCard(CreditPackage pkg) {
    final selected = pkg.id == _selectedId;
    return GestureDetector(
      onTap: () => setState(() => _selectedId = pkg.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dominant price — the single primary value
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHF ${pkg.price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        color: selected ? AppColors.primary : AppColors.text,
                        fontSize: 24, fontWeight: FontWeight.w800)),
                Text(pkg.durationMonths != null
                    ? '/ ${pkg.durationMonths == 1 ? 'Monat' : 'Jahr'}'
                    : '',
                    style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 16),
            // Name + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pkg.name,
                      style: GoogleFonts.inter(
                          color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${pkg.credits} Credits${pkg.includes != null ? ' · ${pkg.includes}' : ''}',
                      style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
            // Selection indicator
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.border, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(color: AppColors.red, fontSize: 13))),
      ]),
    );
  }
}
