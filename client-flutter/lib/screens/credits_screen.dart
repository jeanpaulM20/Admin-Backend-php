import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/credits_provider.dart';
import '../models/buyable_credit.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/empty_view.dart';

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
                  : credits.data.isEmpty
                      ? const EmptyView(
                          icon: Icons.credit_card_rounded,
                          title: 'Keine Credits',
                          subtitle: 'Noch keine Credit-Pakete vorhanden.',
                        )
                      : _CreditsList(credits: credits.data),
        ),
      ),
    );
  }
}

class _CreditsList extends StatelessWidget {
  final List<ClientCredit> credits;

  const _CreditsList({required this.credits});

  @override
  Widget build(BuildContext context) {
    // Calculate active credits (not expired, not future-start)
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
      padding: const EdgeInsets.all(20),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: activeCredits > 0
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  activeCredits > 0
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  color: activeCredits > 0 ? AppColors.primary : AppColors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$activeCredits Credit${activeCredits != 1 ? 's' : ''} verfügbar',
                      style: TextStyle(
                        color: activeCredits > 0
                            ? AppColors.primary
                            : AppColors.red,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeCredits > 0
                          ? 'Aus ${credits.length} Credit-Paket${credits.length != 1 ? 'en' : ''}'
                          : 'Kontaktiere das Studio für neue Credits',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Credit pack cards
        ...credits.map((c) => _CreditPackCard(credit: c)),
        // Contact hint if no active credits
        if (activeCredits <= 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Neue Credits erhältst du direkt im Studio '
                    'oder über deinen Trainer.',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CreditPackCard extends StatelessWidget {
  final ClientCredit credit;

  const _CreditPackCard({required this.credit});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(dt);
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${credit.remaining} von ${credit.paid} verbleibend',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired
                      ? AppColors.red.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${credit.remaining} / ${credit.paid}',
                  style: TextStyle(
                    color: isExpired ? AppColors.red : AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.surface2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                      isExpired ? AppColors.red : AppColors.primary),
            ),
          ),
          if (credit.startdate != null || credit.expires != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (credit.startdate != null) ...[
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Ab ${_formatDate(credit.startdate)}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
                if (credit.startdate != null && credit.expires != null)
                  const SizedBox(width: 12),
                if (credit.expires != null) ...[
                  Icon(Icons.event_busy_rounded,
                      size: 12,
                      color: isExpired ? AppColors.red : AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    isExpired
                        ? 'Abgelaufen ${_formatDate(credit.expires)}'
                        : 'Gültig bis ${_formatDate(credit.expires)}',
                    style: TextStyle(
                      color: isExpired ? AppColors.red : AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
