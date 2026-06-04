import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/training_plan.dart';
import '../services/training_plan_service.dart';
import '../services/api_client.dart';
import 'coaching_paywall_screen.dart';

class _Section {
  final String key;
  final String label;
  final Color color;
  final List<TrainingPlanRow> rows;
  const _Section(this.key, this.label, this.color, this.rows);
}

/// Read-only plan view for the client, mirroring the trainer's section layout.
class ClientPlanDetailScreen extends StatefulWidget {
  final int planId;
  final String? planName;
  const ClientPlanDetailScreen({super.key, required this.planId, this.planName});

  @override
  State<ClientPlanDetailScreen> createState() => _ClientPlanDetailScreenState();
}

class _ClientPlanDetailScreenState extends State<ClientPlanDetailScreen> {
  final _service = TrainingPlanService();
  bool _loading = true;
  String? _error;
  ClientTrainingPlan? _plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final plan = await _service.getPlan(widget.planId);
      if (!mounted) return;
      setState(() { _plan = plan; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Plan konnte nicht geladen werden'; _loading = false; });
    }
  }

  List<_Section> _sections(TrainingPlanValues v) {
    final all = [
      _Section('sonsomo', 'Aufwärmen', AppColors.primary, v.sonsomo),
      _Section('main', 'Haupttraining', AppColors.blue, v.main),
      _Section('core', 'Core', AppColors.green, v.core),
      _Section('mobility', 'Mobilität', AppColors.orange, v.mobility),
    ];
    return all.where((s) => s.rows.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(widget.planName ?? _plan?.name ?? 'Trainingsplan',
            style: GoogleFonts.montserrat(
                color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return _centered(Icons.error_outline, AppColors.red, _error!);
    }
    final plan = _plan;
    if (plan == null) {
      return _centered(Icons.help_outline, AppColors.muted, 'Kein Plan');
    }
    // Defensive: backend returned a locked teaser → send to paywall.
    if (plan.locked || plan.values == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: AppColors.orange, size: 48),
              const SizedBox(height: 16),
              Text('Dieser Plan ist gesperrt',
                  style: GoogleFonts.montserrat(
                      color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Schalte Online Coaching frei, um den vollständigen Plan zu sehen.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => CoachingPaywallScreen(plan: plan),
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Freischalten'),
              ),
            ],
          ),
        ),
      );
    }

    final sections = _sections(plan.values!);
    if (sections.isEmpty) {
      return _centered(Icons.assignment_outlined, AppColors.muted, 'Dieser Plan hat noch keine Übungen');
    }

    return DefaultTabController(
      length: sections.length,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              isScrollable: true,
              labelColor: AppColors.text,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.primary,
              labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: sections.map((s) => Tab(text: '${s.label} (${s.rows.length})')).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: sections.map((s) => _sectionList(s)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionList(_Section s) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: s.rows.length,
      itemBuilder: (context, i) => _exerciseCard(s.rows[i], i + 1, s.color),
    );
  }

  Widget _exerciseCard(TrainingPlanRow row, int index, Color accent) {
    final meta = [
      if (row.device.isNotEmpty) row.device,
      if (row.position.isNotEmpty) row.position,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: accent.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('$index',
                      style: GoogleFonts.montserrat(
                          color: accent, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.exercise.isEmpty ? 'Übung' : row.exercise,
                        style: GoogleFonts.montserrat(
                            color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta, style: GoogleFonts.inter(color: AppColors.muted, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (row.sets.isNotEmpty || row.weight.isNotEmpty || row.timers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (row.sets.isNotEmpty) _metaChip(Icons.repeat, row.sets, AppColors.blue),
              if (row.weight.isNotEmpty) _metaChip(Icons.fitness_center, row.weight, AppColors.primary),
              ...row.timers.map((t) => _metaChip(Icons.timer_outlined, _fmtTimer(t), AppColors.orange)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _fmtTimer(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}min' : '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _centered(IconData icon, Color color, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 44),
            const SizedBox(height: 14),
            Text(msg, textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
