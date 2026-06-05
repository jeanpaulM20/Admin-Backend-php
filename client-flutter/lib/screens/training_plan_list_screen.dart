import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../models/training_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/training_plan_provider.dart';
import 'training_plan_detail_screen.dart';
import 'coaching_paywall_screen.dart';

/// Client "Training" tab — lists the trainer-published plans. Locked plans
/// open the paywall; unlocked plans open the read-only detail view.
class TrainingPlanListScreen extends StatefulWidget {
  const TrainingPlanListScreen({super.key});

  @override
  State<TrainingPlanListScreen> createState() => _TrainingPlanListScreenState();
}

class _TrainingPlanListScreenState extends State<TrainingPlanListScreen> {
  static const _sectionLabels = {
    'sonsomo': 'Aufwärmen',
    'main': 'Haupt',
    'core': 'Core',
    'mobility': 'Mobilität',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<TrainingPlanProvider>().fetch(auth.clientId!);
    }
  }

  void _openPlan(ClientTrainingPlan plan) {
    if (plan.id == null) return;
    if (plan.locked) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CoachingPaywallScreen(plan: plan),
      )).then((_) => _load());
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ClientPlanDetailScreen(planId: plan.id!, planName: plan.name),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TrainingPlanProvider>();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: prov.isLoading && prov.plans.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _subscriptionBanner(prov)),
                if (prov.error != null)
                  SliverToBoxAdapter(child: _errorBox(prov.error!)),
                if (prov.plans.isEmpty && !prov.isLoading)
                  SliverFillRemaining(hasScrollBody: false, child: _emptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _planCard(prov.plans[i]),
                        childCount: prov.plans.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _subscriptionBanner(TrainingPlanProvider prov) {
    final sub = prov.subscription;
    final active = sub.active;
    // Inactive: amber/gold accent — creates desire, not blockade
    final accentColor = active ? AppColors.primary : const Color(0xFFD97706);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withAlpha(active ? 120 : 80)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              active ? Icons.workspace_premium : Icons.emoji_events_rounded,
              color: accentColor, size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? '${sub.tierLabel} aktiv' : 'Starte dein Online Coaching',
                  style: GoogleFonts.inter(
                      color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Gültig bis ${_fmtDate(sub.validTo)}'
                      : 'Trainingsplan · HR-Analyse · Chat-Feedback',
                  style: GoogleFonts.inter(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: accentColor.withAlpha(180), size: 20),
        ],
      ),
    );
  }

  Widget _planCard(ClientTrainingPlan plan) {
    final locked = plan.locked;
    final borderColor = locked ? AppColors.muted : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: () => _openPlan(plan),
            splashColor: AppColors.primary.withAlpha(20),
            highlightColor: AppColors.primary.withAlpha(10),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // ── Left-Border accent ──
                  Container(width: 3, color: borderColor),
                  // ── Card content ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: (locked ? AppColors.muted : AppColors.primary).withAlpha(38),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(locked ? Icons.lock_outline : Icons.fitness_center,
                                color: locked ? AppColors.muted : AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan.name ?? 'Trainingsplan',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  _countChip('${plan.totalExercises} Übungen', AppColors.primary),
                                  ...plan.sections.entries.take(2).map((e) =>
                                      _countChip('${_sectionLabels[e.key] ?? e.key} ${e.value}', AppColors.muted)),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (locked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withAlpha(36),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Abo',
                                  style: GoogleFonts.inter(
                                      color: AppColors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
                            )
                          else
                            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, color: AppColors.muted, size: 48),
            const SizedBox(height: 16),
            Text('Noch keine Trainingspläne',
                style: GoogleFonts.inter(
                    color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Dein Trainer gibt dir hier deinen Plan frei, sobald er bereit ist.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: GoogleFonts.inter(color: AppColors.red, fontSize: 13))),
      ]),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '–';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
