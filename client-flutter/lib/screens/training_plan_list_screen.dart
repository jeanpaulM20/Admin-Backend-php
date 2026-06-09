import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/api_config.dart';
import '../models/training_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/training_plan_provider.dart';
import '../services/api_client.dart';
import 'training_plan_detail_screen.dart';
import 'coaching_paywall_screen.dart';
import 'credits_screen.dart';

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
    'main':    'Haupttraining',
    'core':    'Core',
    'mobility':'Mobilität',
  };

  static const _sectionOrder = ['sonsomo', 'main', 'core', 'mobility'];

  // Exercise name → id map for cover image display
  Map<String, int> _exerciseIdMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadExerciseIds();
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<TrainingPlanProvider>().fetch(auth.clientId!);
    }
  }

  Future<void> _loadExerciseIds() async {
    try {
      final data = await apiClient.get('api/exercise');
      if (data is List && mounted) {
        setState(() {
          _exerciseIdMap = {
            for (final ex in data)
              if (ex['name'] != null) ex['name'].toString(): ex['id'] as int,
          };
        });
      }
    } catch (_) {}
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

  void _openCoachingCredits() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const CreditsScreen(),
    ));
  }

  Widget _subscriptionBanner(TrainingPlanProvider prov) {
    final sub = prov.subscription;
    final active = sub.active;
    final accentColor = active ? AppColors.primary : const Color(0xFFD97706);
    return GestureDetector(
      onTap: active ? null : _openCoachingCredits,
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.primary.withAlpha(100) : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? '${sub.tierLabel} aktiv'
                      : 'Trainingsplan · HR-Analyse · Chat-Feedback',
                  style: GoogleFonts.inter(
                      color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Gültig bis ${_fmtDate(sub.validTo)}'
                      : 'Online Coaching starten',
                  style: GoogleFonts.inter(
                      color: active ? AppColors.muted : accentColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!active)
            Icon(Icons.chevron_right, color: accentColor.withAlpha(200), size: 20),
        ],
      ),
    ));
  }

  Widget _planCard(ClientTrainingPlan plan) {
    final locked = plan.locked;
    final borderColor = locked ? AppColors.muted : AppColors.primary;

    // All phases with exercises as plain-text subtitle
    final phaseText = _sectionOrder
        .where((key) => (plan.sections[key] ?? 0) > 0)
        .map((key) => '${_sectionLabels[key]} ${plan.sections[key]}')
        .join(' · ');

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
                          _coverImage(plan, locked),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan.name ?? 'Trainingsplan',
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: AppColors.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                if (phaseText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(phaseText,
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400)),
                                ],
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
                                      color: AppColors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
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

  Widget _coverImage(ClientTrainingPlan plan, bool locked) {
    const double size = 72.0;
    const double radius = 10.0;
    final exerciseId = plan.coverExerciseName != null
        ? _exerciseIdMap[plan.coverExerciseName!]
        : null;
    if (exerciseId != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          '${ApiConfig.baseUrl}api/exercise/$exerciseId/icon.png',
          width: size, height: size,
          fit: BoxFit.cover,
          headers: apiClient.token != null
              ? {ApiConfig.authHeader: apiClient.token!}
              : {},
          errorBuilder: (_, __, ___) => _fallbackIcon(locked, size),
        ),
      );
    }
    return _fallbackIcon(locked, size);
  }

  Widget _fallbackIcon(bool locked, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: (locked ? AppColors.muted : AppColors.primary).withAlpha(38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(locked ? Icons.lock_outline : Icons.fitness_center,
          color: locked ? AppColors.muted : AppColors.primary, size: 22),
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
