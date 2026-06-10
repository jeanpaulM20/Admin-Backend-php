import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Guards the expiry reminder dialog against concurrent _load() invocations.
  bool _expiryPopupShowing = false;

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
    if (mounted) _maybeShowExpiryPopup();
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
    // Don't flash the banner while loading — subscription status is unknown.
    if (prov.isLoading) return const SizedBox.shrink();

    final sub = prov.subscription;

    // Active subscriber → no banner (renewal is handled by the expiry popup).
    if (sub.active) return const SizedBox.shrink();

    // Never used the trial → offer the free month.
    if (sub.canStartTrial) {
      return _banner(
        title: '1 Monat gratis testen',
        subtitle: 'Trainingsplan · HR-Analyse · Chat-Feedback',
        onTap: _startTrial,
      );
    }

    // Trial used / expired without conversion → paid upsell.
    return _banner(
      title: 'Trainingsplan · HR-Analyse · Chat-Feedback',
      subtitle: 'Online Coaching starten',
      onTap: _openCoachingCredits,
    );
  }

  Widget _banner({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const accentColor = Color(0xFFD97706);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(color: accentColor, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accentColor.withAlpha(200), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Trial activation ────────────────────────────────────────────────────

  Future<void> _startTrial() async {
    final confirmed = await _showTrialSheet();
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final clientId = auth.clientId;
    if (clientId == null) return;

    final err = await context.read<TrainingPlanProvider>().activateTrial(clientId);
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err), backgroundColor: AppColors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Test-Abo aktiviert — viel Erfolg!'),
        backgroundColor: AppColors.primary));
      _load(); // plans are now unlocked
    }
  }

  Future<bool?> _showTrialSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1 Monat gratis testen',
                style: GoogleFonts.inter(
                    color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Voller Zugriff: alle Trainingspläne · HR-Analyse · Chat-Feedback.\n'
                'Keine Zahlung. Endet automatisch nach 30 Tagen.',
                style: GoogleFonts.inter(
                    color: AppColors.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Test-Abo aktivieren',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Später', style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expiry reminder popup (uniform for trial / monthly / yearly) ─────────

  Future<void> _maybeShowExpiryPopup() async {
    // Guard against concurrent _load() calls stacking two dialogs.
    if (_expiryPopupShowing) return;

    final sub = context.read<TrainingPlanProvider>().subscription;
    if (!sub.active || !sub.expiringSoon || sub.validTo == null) return;

    // Throttle: show at most once per day per subscription period.
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'expiry_popup_${sub.validTo}';
    if (prefs.getString(key) == today) return;
    if (!mounted || _expiryPopupShowing) return;

    final d = sub.daysLeft ?? 0;
    final whenStr = d <= 0 ? 'heute' : 'in $d ${d == 1 ? 'Tag' : 'Tagen'}';

    // Only mark as shown once we're actually about to display it.
    _expiryPopupShowing = true;
    await prefs.setString(key, today);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Abo läuft bald ab',
            style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text(
          'Dein Abo läuft $whenStr ab. Verlängere jetzt, um nahtlos weiterzutrainieren.',
          style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Später', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openCoachingCredits();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Verlängern'),
          ),
        ],
      ),
    ).whenComplete(() => _expiryPopupShowing = false);
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
            Text('Du erhältst nach dem Onboarding deinen personalisierten Trainingsplan.',
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

}
