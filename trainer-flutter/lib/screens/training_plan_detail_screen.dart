import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/client.dart';
import '../models/training_plan.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class TrainingPlanDetailScreen extends StatefulWidget {
  final Client client;
  final TrainingPlan? plan;

  const TrainingPlanDetailScreen(
      {super.key, required this.client, this.plan});

  @override
  State<TrainingPlanDetailScreen> createState() =>
      _TrainingPlanDetailScreenState();
}

class _TrainingPlanDetailScreenState extends State<TrainingPlanDetailScreen> {
  final _api = ApiService();
  bool _saving = false;
  late TrainingPlanValues _values;
  final _nameCtrl = TextEditingController();

  final List<TextEditingController> _dateCtrls =
      List.generate(8, (_) => TextEditingController());

  late List<List<TextEditingController>> _sonsomoRowCtrls;
  late List<List<TextEditingController>> _mainRowCtrls;
  late List<List<TextEditingController>> _coreRowCtrls;
  late List<List<TextEditingController>> _sonsomoDateCtrls;
  late List<List<TextEditingController>> _mainDateCtrls;
  late List<List<TextEditingController>> _coreDateCtrls;

  // Track which exercise tiles are expanded
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _values = widget.plan?.values ?? TrainingPlanValues();
    _nameCtrl.text = widget.plan?.name ?? '';

    for (var i = 0; i < 8; i++) {
      _dateCtrls[i].text = _values.dates[i];
    }

    _sonsomoRowCtrls = _buildRowCtrls(_values.sonsomo);
    _mainRowCtrls = _buildRowCtrls(_values.main);
    _coreRowCtrls = _buildRowCtrls(_values.core);
    _sonsomoDateCtrls = _buildDateCtrls(_values.sonsomo);
    _mainDateCtrls = _buildDateCtrls(_values.main);
    _coreDateCtrls = _buildDateCtrls(_values.core);

    // Expand all exercises by default so fields are immediately accessible
    for (var i = 0; i < _values.sonsomo.length; i++) _expanded.add('s-$i');
    for (var i = 0; i < _values.main.length; i++) _expanded.add('m-$i');
    for (var i = 0; i < _values.core.length; i++) _expanded.add('c-$i');
  }

  List<List<TextEditingController>> _buildRowCtrls(
      List<TrainingPlanRow> rows) {
    return rows
        .map((r) => [
              TextEditingController(text: r.exercise),
              TextEditingController(text: r.device),
              TextEditingController(text: r.position),
              TextEditingController(text: r.weight),
            ])
        .toList();
  }

  List<List<TextEditingController>> _buildDateCtrls(
      List<TrainingPlanRow> rows) {
    return rows
        .map((r) => List.generate(
            8, (i) => TextEditingController(text: r.dates[i])))
        .toList();
  }

  TrainingPlanValues _collectValues() {
    final dates = List.generate(8, (i) => _dateCtrls[i].text);
    List<TrainingPlanRow> collect(
      List<List<TextEditingController>> rc,
      List<List<TextEditingController>> dc,
    ) =>
        List.generate(
          rc.length,
          (i) => TrainingPlanRow(
            exercise: rc[i][0].text,
            device: rc[i][1].text,
            position: rc[i][2].text,
            weight: rc[i][3].text,
            dates: List.generate(8, (j) => dc[i][j].text),
          ),
        );
    return TrainingPlanValues(
      sonsomo: collect(_sonsomoRowCtrls, _sonsomoDateCtrls),
      main: collect(_mainRowCtrls, _mainDateCtrls),
      core: collect(_coreRowCtrls, _coreDateCtrls),
      dates: dates,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final plan = TrainingPlan(
        id: widget.plan?.id,
        clientId: widget.client.id,
        name: _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
        values: _collectValues(),
      );
      if (plan.id != null) {
        await _api.put('${ApiConfig.trainingPlan}/${plan.id}',
            body: plan.toJson());
      } else {
        await _api.post(ApiConfig.trainingPlan, body: plan.toJson());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trainingsplan gespeichert'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _dateCtrls) c.dispose();
    for (final row in [
      ..._sonsomoRowCtrls,
      ..._mainRowCtrls,
      ..._coreRowCtrls
    ]) {
      for (final c in row) c.dispose();
    }
    for (final section in [
      ..._sonsomoDateCtrls,
      ..._mainDateCtrls,
      ..._coreDateCtrls
    ]) {
      for (final c in section) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildDateStrip()),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(
                'AUFWÄRMEN',
                'Warm-up / Sonsomo',
                Icons.accessibility_new,
                AppColors.primary,
              ),
              ..._buildExerciseList('s', _sonsomoRowCtrls, _sonsomoDateCtrls),
              _buildSectionHeader(
                'HAUPTTRAINING',
                'Main',
                Icons.fitness_center,
                AppColors.blue,
              ),
              ..._buildExerciseList('m', _mainRowCtrls, _mainDateCtrls),
              _buildSectionHeader(
                'CORE',
                'Core',
                Icons.self_improvement,
                AppColors.green,
              ),
              ..._buildExerciseList('c', _coreRowCtrls, _coreDateCtrls),
              const SizedBox(height: 120),
            ]),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _saving ? 'Speichern…' : 'Speichern',
          style: GoogleFonts.openSans(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ─── Sliver App Bar ──────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios,
            color: AppColors.text, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.check_rounded,
                  size: 18, color: AppColors.primary),
          label: Text(
            _saving ? 'Läuft…' : 'Speichern',
            style: GoogleFonts.openSans(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameCtrl,
          builder: (_, v, __) => Text(
            v.text.isNotEmpty ? v.text : 'Trainingsplan',
            style: GoogleFonts.montserrat(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2A3010),
                    Color(0xFF131A08),
                    AppColors.background,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // Decorative icon
            Positioned(
              right: 16,
              bottom: 16,
              child: Icon(
                Icons.fitness_center,
                size: 100,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            // Plan name editor + client info
            Positioned(
              left: 20,
              right: 90,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Planname…',
                      hintStyle: GoogleFonts.montserrat(
                        color: Colors.white30,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        widget.client.name,
                        style: GoogleFonts.openSans(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
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

  // ─── Date Strip ──────────────────────────────────────────────────────────────

  Widget _buildDateStrip() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAININGSDATEN',
            style: GoogleFonts.openSans(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(8, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _dateChip(i),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }

  Widget _dateChip(int i) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: _dateCtrls[i],
        style: GoogleFonts.openSans(
          color: AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '${i + 1}. Dat.',
          hintStyle: GoogleFonts.openSans(
            color: AppColors.muted.withOpacity(0.4),
            fontSize: 10,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          isDense: true,
        ),
      ),
    );
  }

  // ─── Section Header ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    String label,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.openSans(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.openSans(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Exercise List ────────────────────────────────────────────────────────────

  List<Widget> _buildExerciseList(
    String prefix,
    List<List<TextEditingController>> rowCtrls,
    List<List<TextEditingController>> dateCtrls,
  ) {
    return List.generate(rowCtrls.length, (i) {
      final key = '$prefix-$i';
      return _ExerciseTile(
        number: i + 1,
        ctrls: rowCtrls[i],
        dateCtrls: dateCtrls[i],
        dateLabels: _dateCtrls.map((c) => c.text).toList(),
        isExpanded: _expanded.contains(key),
        onToggle: () => setState(() {
          if (_expanded.contains(key)) {
            _expanded.remove(key);
          } else {
            _expanded.add(key);
          }
        }),
      );
    });
  }
}

// ─── Exercise Tile ────────────────────────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  final int number;
  final List<TextEditingController> ctrls; // [exercise, device, position, weight]
  final List<TextEditingController> dateCtrls; // [8 date results]
  final List<String> dateLabels;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ExerciseTile({
    required this.number,
    required this.ctrls,
    required this.dateCtrls,
    required this.dateLabels,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (always visible, Spotify track style) ──
          InkWell(
            onTap: onToggle,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  // Track number
                  SizedBox(
                    width: 22,
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: GoogleFonts.montserrat(
                        color: AppColors.muted.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Exercise name field (prominent, like track title)
                  Expanded(
                    child: TextField(
                      controller: ctrls[0],
                      style: GoogleFonts.openSans(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Übung eingeben…',
                        hintStyle: GoogleFonts.openSans(
                          color: AppColors.muted.withOpacity(0.4),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Weight pill (like duration in Spotify)
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: ctrls[3],
                      style: GoogleFonts.openSans(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'kg',
                        hintStyle: GoogleFonts.openSans(
                          color: AppColors.muted.withOpacity(0.4),
                          fontSize: 11,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        filled: true,
                        fillColor: AppColors.primary.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Expand/collapse chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details ──
          if (isExpanded) ...[
            Divider(
              color: AppColors.border.withOpacity(0.6),
              height: 1,
              indent: 46,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(46, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device + Position fields
                  Row(
                    children: [
                      Expanded(child: _detailField('Gerät', ctrls[1])),
                      const SizedBox(width: 8),
                      Expanded(child: _detailField('Position', ctrls[2])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date results label
                  Text(
                    'ERGEBNISSE',
                    style: GoogleFonts.openSans(
                      color: AppColors.muted.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date result fields (8 compact inputs)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(8, (j) {
                      final lbl = j < dateLabels.length &&
                              dateLabels[j].isNotEmpty
                          ? dateLabels[j]
                          : '${j + 1}';
                      return _dateResultField(lbl, dateCtrls[j]);
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.openSans(color: AppColors.text, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.openSans(
            color: AppColors.muted, fontSize: 10),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1),
        ),
        isDense: true,
      ),
    );
  }

  Widget _dateResultField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 58,
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.openSans(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(
            color: AppColors.muted,
            fontSize: 8,
          ),
          floatingLabelAlignment: FloatingLabelAlignment.center,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1),
          ),
          isDense: true,
        ),
      ),
    );
  }
}
