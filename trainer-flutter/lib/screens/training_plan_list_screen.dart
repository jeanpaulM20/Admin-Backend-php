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
  bool _loading = true;
  String? _error;
  List<TrainingPlan> _plans = [];

  // Spotify-style dark gradient pairs for plan cards
  static const _cardGradients = [
    [Color(0xFF5A3E28), Color(0xFF1E1209)], // warm amber
    [Color(0xFF1B3A5C), Color(0xFF070F1A)], // deep blue
    [Color(0xFF2E4A2A), Color(0xFF0B1709)], // forest green
    [Color(0xFF4A2845), Color(0xFF130A12)], // deep purple
    [Color(0xFF3A4A1C), Color(0xFF111707)], // olive (brand)
    [Color(0xFF4A3214), Color(0xFF150D04)], // caramel
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
        builder: (_) =>
            TrainingPlanDetailScreen(client: widget.client, plan: plan),
      ),
    );
    if (ok == true) _load();
  }

  int _countExercises(TrainingPlan p) =>
      p.values.sonsomo.where((r) => r.exercise.isNotEmpty).length +
      p.values.main.where((r) => r.exercise.isNotEmpty).length +
      p.values.core.where((r) => r.exercise.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_plans.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            _buildGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.muted),
          onPressed: _load,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: Text(
          'Trainingspläne',
          style: GoogleFonts.montserrat(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A3010), Color(0xFF111808), AppColors.background],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                Icons.fitness_center,
                size: 130,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trainingspläne',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: Colors.white54),
                      const SizedBox(width: 5),
                      Text(
                        widget.client.name,
                        style: GoogleFonts.openSans(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      if (_plans.isNotEmpty) ...[
                        Text('  ·  ',
                            style: GoogleFonts.openSans(
                                color: Colors.white38, fontSize: 13)),
                        Text(
                          '${_plans.length} ${_plans.length == 1 ? 'Plan' : 'Pläne'}',
                          style: GoogleFonts.openSans(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _buildCard(_plans[i], i),
          childCount: _plans.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.80,
        ),
      ),
    );
  }

  Widget _buildCard(TrainingPlan plan, int index) {
    final grad = _cardGradients[index % _cardGradients.length];
    final name = plan.name?.isNotEmpty == true
        ? plan.name!
        : 'Plan ${index + 1}';
    final count = _countExercises(plan);
    final dateStr = plan.createdAt != null
        ? plan.createdAt!.substring(0, plan.createdAt!.length.clamp(0, 10))
        : null;

    return GestureDetector(
      onTap: () => _open(plan),
      child: Container(
        decoration: BoxDecoration(
          gradient:
              LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: grad[0].withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -12,
              child: Icon(Icons.fitness_center,
                  size: 100, color: Colors.white.withOpacity(0.06)),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon box (like album art placeholder)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_outlined,
                        color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  // Plan name
                  Text(
                    name,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Exercise count
                  Row(
                    children: [
                      Icon(Icons.bolt,
                          size: 12, color: Colors.white.withOpacity(0.55)),
                      const SizedBox(width: 3),
                      Text(
                        count > 0 ? '$count Übungen' : 'Leer',
                        style: GoogleFonts.openSans(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (dateStr != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      dateStr,
                      style: GoogleFonts.openSans(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3A4A1C), Color(0xFF111707)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child:
                const Icon(Icons.table_chart_outlined, color: Colors.white54, size: 42),
          ),
          const SizedBox(height: 22),
          Text(
            'Noch keine Pläne',
            style: GoogleFonts.montserrat(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tippe + um den ersten Plan zu erstellen',
            style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
}
