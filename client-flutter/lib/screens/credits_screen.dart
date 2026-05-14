import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/credits_provider.dart';
import '../models/buyable_credit.dart';
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
                    ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main content: client credits + available packages
// ═══════════════════════════════════════════════════════════════════════════════

class _CreditsContent extends StatelessWidget {
  final List<ClientCredit> credits;
  final List<CreditPackage> packages;

  const _CreditsContent({required this.credits, required this.packages});

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
        // ── Summary card ──
        _SummaryCard(activeCredits: activeCredits, packCount: credits.length),
        const SizedBox(height: 8),

        // ── Active credit packs ──
        if (credits.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.toll_outlined, title: 'Deine Credits'),
          ...credits.map((c) => _CreditPackCard(credit: c)),
          const SizedBox(height: 16),
        ],

        // ── Available packages ──
        if (packages.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.local_offer_outlined, title: 'Unsere Pakete'),
          ...packages.map((p) => _PackageCard(package: p)),
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
                  ? '$activeCredits Credit${activeCredits != 1 ? 's' : ''} verfuegbar'
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
                  : 'Waehle ein Paket und kontaktiere uns',
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
// Client's owned credit pack card
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
// Available package card (from website pricing)
// ═══════════════════════════════════════════════════════════════════════════════

class _PackageCard extends StatelessWidget {
  final CreditPackage package;

  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final isPopular = package.credits == 10; // Basic is most popular
    final priceFormatted = NumberFormat('#,##0', 'de_CH').format(package.price);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPopular ? AppColors.primary.withAlpha(80) : AppColors.border,
          width: isPopular ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        // Popular badge
        if (isPopular)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              'BELIEBTESTES PAKET',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.name, style: const TextStyle(
                      color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800,
                    )),
                    const SizedBox(height: 2),
                    if (package.description != null)
                      Text(package.description!, style: const TextStyle(
                        color: AppColors.muted, fontSize: 12,
                      )),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CHF $priceFormatted',
                      style: const TextStyle(
                        color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (package.pricePerSession != null)
                      Text(
                        'CHF ${package.pricePerSession!.toStringAsFixed(0)} / Lektion',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                  ],
                ),
              ]),
              const SizedBox(height: 14),

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
                const SizedBox(height: 10),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
                ...package.includes!.split(', ').map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outlined, size: 14, color: AppColors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item, style: const TextStyle(
                      color: AppColors.text, fontSize: 12,
                    ))),
                  ]),
                )),
              ],
            ],
          ),
        ),
      ]),
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
