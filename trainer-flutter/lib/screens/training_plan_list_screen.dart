import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/client.dart';
import '../models/training_plan.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import 'training_plan_detail_screen.dart';

class TrainingPlanListScreen extends StatefulWidget {
  final Client client;
  const TrainingPlanListScreen({super.key, required this.client});

  @override
  State<TrainingPlanListScreen> createState() => _TrainingPlanListScreenState();
}

class _TrainingPlanListScreenState extends State<TrainingPlanListScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<TrainingPlan> _plans = [];
  String _query = '';

  // Accent colors for plan icons (cycling)
  static const _accentColors = [
    Color(0xFF8B6B3D), // amber
    Color(0xFF3D6B8B), // blue
    Color(0xFF3D8B5A), // green
    Color(0xFF7A3D8B), // purple
    Color(0xFF636B2F), // olive (brand)
    Color(0xFF8B4A3D), // rust
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await _api.get(
        ApiConfig.trainingPlan,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      List<dynamic> list = [];
      if (resp is List) {
        list = resp;
      } else if (resp is Map && resp['data'] is List) {
        list = resp['data'] as List;
      }
      setState(() {
        _plans = list
            .map((e) => TrainingPlan.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Fehler beim Laden der Pläne');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(TrainingPlan? plan) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingPlanDetailScreen(client: widget.client, plan: plan),
      ),
    );
    if (ok == true) _load();
  }

  int _countExercises(TrainingPlan p) =>
      p.values.sonsomo.where((r) => r.exercise.isNotEmpty).length +
      p.values.main.where((r) => r.exercise.isNotEmpty).length +
      p.values.core.where((r) => r.exercise.isNotEmpty).length;

  List<TrainingPlan> get _filtered {
    if (_query.isEmpty) return _plans;
    final q = _query.toLowerCase();
    return _plans.where((p) {
      final name = (p.name ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Neuer Plan',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ─── Gradient header ──────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3010), Color(0xFF111808), AppColors.background],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppColors.text, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trainingspläne',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(
                          widget.client.name,
                          style: GoogleFonts.openSans(
                              color: Colors.white54, fontSize: 12),
                        ),
                        if (_plans.isNotEmpty) ...[
                          Text('  ·  ',
                              style: GoogleFonts.openSans(
                                  color: Colors.white30, fontSize: 12)),
                          Text(
                            '${_plans.length} ${_plans.length == 1 ? 'Plan' : 'Pläne'}',
                            style: GoogleFonts.openSans(
                                color: Colors.white30, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.muted),
                onPressed: _load,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.openSans(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Pläne durchsuchen…',
          hintStyle: GoogleFonts.openSans(
              color: AppColors.muted.withOpacity(0.6), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.muted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          isDense: true,
        ),
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3A4A1C), Color(0xFF111707)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.table_chart_outlined,
                  color: Colors.white54, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              _query.isEmpty ? 'Noch keine Pläne' : 'Keine Treffer',
              style: GoogleFonts.montserrat(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _query.isEmpty
                  ? 'Tippe + um den ersten Plan zu erstellen'
                  : 'Versuche einen anderen Suchbegriff',
              style:
                  GoogleFonts.openSans(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildRow(items[i], i),
    );
  }

  // ─── List row ─────────────────────────────────────────────────────────────

  Widget _buildRow(TrainingPlan plan, int index) {
    final accent = _accentColors[index % _accentColors.length];
    final name = plan.name?.isNotEmpty == true
        ? plan.name!
        : 'Plan ${index + 1}';
    final count = _countExercises(plan);
    final dateStr = plan.createdAt != null
        ? plan.createdAt!.substring(0, plan.createdAt!.length.clamp(0, 10))
        : null;

    return InkWell(
      onTap: () => _open(plan),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            // Colored icon thumbnail (like Spotify album art)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: accent.withOpacity(0.3), width: 0.5),
              ),
              child: Icon(Icons.table_chart_outlined,
                  color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.openSans(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (count > 0) ...[
                        Icon(Icons.bolt,
                            size: 11,
                            color: AppColors.muted.withOpacity(0.7)),
                        const SizedBox(width: 2),
                        Text(
                          '$count Übungen',
                          style: GoogleFonts.openSans(
                              color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                      if (count > 0 && dateStr != null)
                        Text('  ·  ',
                            style: GoogleFonts.openSans(
                                color: AppColors.muted.withOpacity(0.5),
                                fontSize: 11)),
                      if (dateStr != null)
                        Text(
                          dateStr,
                          style: GoogleFonts.openSans(
                              color: AppColors.muted, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
