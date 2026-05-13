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
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          itemCount: credits.data.length,
                          itemBuilder: (ctx, i) {
                            return _CreditPackCard(credit: credits.data[i]);
                          },
                        ),
        ),
      ),
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
                  color: AppColors.primary.withOpacity(0.12),
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
                      ? AppColors.red.withOpacity(0.15)
                      : AppColors.primary.withOpacity(0.15),
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
