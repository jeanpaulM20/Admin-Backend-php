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

class _TrainingPlanDetailScreenState extends State<TrainingPlanDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _saving = false;
  late TrainingPlanValues _values;
  final _nameCtrl = TextEditingController();
  late TabController _tabCtrl;

  final List<TextEditingController> _dateCtrls =
      List.generate(8, (_) => TextEditingController());

  late List<List<TextEditingController>> _sonsomoRowCtrls;
  late List<List<TextEditingController>> _mainRowCtrls;
  late List<List<TextEditingController>> _coreRowCtrls;
  late List<List<TextEditingController>> _sonsomoDateCtrls;
  late List<List<TextEditingController>> _mainDateCtrls;
  late List<List<TextEditingController>> _coreDateCtrls;

  final Set<String> _expanded = {};

  static const _sections = [
    _Section('AUFWÄRMEN',   'Warm-up / Sonsomo', Icons.accessibility_new,  AppColors.primary),
    _Section('HAUPTTRAINING','Main',             Icons.fitness_center,      AppColors.blue),
    _Section('CORE',         'Core',             Icons.self_improvement,    AppColors.green),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _values = widget.plan?.values ?? TrainingPlanValues();
    _nameCtrl.text = widget.plan?.name ?? '';
    for (var i = 0; i < 8; i++) _dateCtrls[i].text = _values.dates[i];

    _sonsomoRowCtrls = _buildRowCtrls(_values.sonsomo);
    _mainRowCtrls    = _buildRowCtrls(_values.main);
    _coreRowCtrls    = _buildRowCtrls(_values.core);
    _sonsomoDateCtrls = _buildDateCtrls(_values.sonsomo);
    _mainDateCtrls    = _buildDateCtrls(_values.main);
    _coreDateCtrls    = _buildDateCtrls(_values.core);
  }

  List<List<TextEditingController>> _buildRowCtrls(List<TrainingPlanRow> rows) =>
      rows.map((r) => [
            TextEditingController(text: r.exercise),
            TextEditingController(text: r.device),
            TextEditingController(text: r.position),
            TextEditingController(text: r.weight),
          ]).toList();

  List<List<TextEditingController>> _buildDateCtrls(List<TrainingPlanRow> rows) =>
      rows.map((r) => List.generate(8, (i) => TextEditingController(text: r.dates[i]))).toList();

  TrainingPlanValues _collectValues() {
    final dates = List.generate(8, (i) => _dateCtrls[i].text);
    List<TrainingPlanRow> collect(
      List<List<TextEditingController>> rc,
      List<List<TextEditingController>> dc,
    ) =>
        List.generate(rc.length, (i) => TrainingPlanRow(
              exercise: rc[i][0].text,
              device:   rc[i][1].text,
              position: rc[i][2].text,
              weight:   rc[i][3].text,
              dates:    List.generate(8, (j) => dc[i][j].text),
            ));
    return TrainingPlanValues(
      sonsomo: collect(_sonsomoRowCtrls, _sonsomoDateCtrls),
      main:    collect(_mainRowCtrls,    _mainDateCtrls),
      core:    collect(_coreRowCtrls,    _coreDateCtrls),
      dates:   dates,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final plan = TrainingPlan(
        id:       widget.plan?.id,
        clientId: widget.client.id,
        name:     _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
        values:   _collectValues(),
      );
      if (plan.id != null) {
        await _api.put('${ApiConfig.trainingPlan}/${plan.id}', body: plan.toJson());
      } else {
        await _api.post(ApiConfig.trainingPlan, body: plan.toJson());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Trainingsplan gespeichert'),
          backgroundColor: Color(0xFF2E7D32),
        ));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _dateCtrls) c.dispose();
    for (final row in [..._sonsomoRowCtrls, ..._mainRowCtrls, ..._coreRowCtrls])
      for (final c in row) c.dispose();
    for (final sec in [..._sonsomoDateCtrls, ..._mainDateCtrls, ..._coreDateCtrls])
      for (final c in sec) c.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeroHeader(),
          _buildDateStrip(),
          _buildSectionTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildExerciseTab('s', _sonsomoRowCtrls, _sonsomoDateCtrls, 0),
                _buildExerciseTab('m', _mainRowCtrls,    _mainDateCtrls,    1),
                _buildExerciseTab('c', _coreRowCtrls,    _coreDateCtrls,    2),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Speichern…' : 'Speichern',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ─── Hero header ──────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3010), Color(0xFF111808), AppColors.background],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppColors.text, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              // Plan name + client
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
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
                          color: Colors.white24,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(widget.client.name,
                          style: GoogleFonts.openSans(
                              color: Colors.white38, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              // Save button top-right
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.primary),
                label: Text(_saving ? '…' : 'Speichern',
                    style: GoogleFonts.openSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Date strip ───────────────────────────────────────────────────────────
  Widget _buildDateStrip() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRAININGSDATEN',
              style: GoogleFonts.openSans(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(8, (i) => Padding(
                padding: const EdgeInsets.only(right: 7),
                child: _dateChip(i),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(int i) => SizedBox(
        width: 76,
        child: TextField(
          controller: _dateCtrls[i],
          style: GoogleFonts.openSans(
              color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '${i + 1}. Datum',
            hintStyle: GoogleFonts.openSans(
                color: AppColors.muted.withOpacity(0.4), fontSize: 10),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            isDense: true,
          ),
        ),
      );

  // ─── Section tabs (Apple Music playlist phase tabs) ───────────────────────
  Widget _buildSectionTabs() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          const Divider(color: AppColors.border, height: 1),
          TabBar(
            controller: _tabCtrl,
            isScrollable: false,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.muted,
            labelStyle: GoogleFonts.openSans(
                fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.openSans(
                fontSize: 12, fontWeight: FontWeight.w500),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: _sections.map((s) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 13),
                  const SizedBox(width: 5),
                  Text(s.label),
                ],
              ),
            )).toList(),
          ),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }

  // ─── Exercise tab body ────────────────────────────────────────────────────
  Widget _buildExerciseTab(
    String prefix,
    List<List<TextEditingController>> rowCtrls,
    List<List<TextEditingController>> dateCtrls,
    int sectionIdx,
  ) {
    final section = _sections[sectionIdx];
    final filledCount =
        rowCtrls.where((r) => r[0].text.isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        // Section subtitle row
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: section.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: section.color.withOpacity(0.3), width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(section.icon, size: 12, color: section.color),
                const SizedBox(width: 5),
                Text(section.subtitle,
                    style: GoogleFonts.openSans(
                        color: section.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text(
              '$filledCount ${filledCount == 1 ? 'Übung' : 'Übungen'}',
              style: GoogleFonts.openSans(
                  color: AppColors.muted, fontSize: 11),
            ),
          ]),
        ),

        // Exercise tiles
        ...List.generate(rowCtrls.length, (i) {
          final key = '$prefix-$i';
          return _ExerciseTile(
            number:     i + 1,
            ctrls:      rowCtrls[i],
            dateCtrls:  dateCtrls[i],
            dateLabels: _dateCtrls.map((c) => c.text).toList(),
            accentColor: section.color,
            isExpanded: _expanded.contains(key),
            onToggle: () => setState(() {
              if (_expanded.contains(key)) {
                _expanded.remove(key);
              } else {
                _expanded.add(key);
              }
            }),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section data class
// ─────────────────────────────────────────────────────────────────────────────

class _Section {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Section(this.label, this.subtitle, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise Tile — Apple Music track card style
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  final int number;
  final List<TextEditingController> ctrls;
  final List<TextEditingController> dateCtrls;
  final List<String> dateLabels;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ExerciseTile({
    required this.number,
    required this.ctrls,
    required this.dateCtrls,
    required this.dateLabels,
    required this.accentColor,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = ctrls[0].text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? accentColor.withOpacity(0.35)
              : AppColors.border.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Main row ──────────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  // Number badge (circle, like Apple Music track number)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hasContent
                          ? accentColor.withOpacity(0.15)
                          : AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: GoogleFonts.montserrat(
                          color: hasContent ? accentColor : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Exercise name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: ctrls[0],
                          style: GoogleFonts.openSans(
                            color: hasContent
                                ? AppColors.text
                                : AppColors.muted.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Übung eingeben…',
                            hintStyle: GoogleFonts.openSans(
                                color: AppColors.muted.withOpacity(0.35),
                                fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        // Show device/position as subtitle when collapsed
                        if (!isExpanded &&
                            (ctrls[1].text.isNotEmpty ||
                                ctrls[2].text.isNotEmpty)) ...[
                          const SizedBox(height: 2),
                          Text(
                            [ctrls[1].text, ctrls[2].text]
                                .where((s) => s.isNotEmpty)
                                .join('  ·  '),
                            style: GoogleFonts.openSans(
                                color: AppColors.muted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Weight pill
                  SizedBox(
                    width: 58,
                    child: TextField(
                      controller: ctrls[3],
                      style: GoogleFonts.openSans(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'kg',
                        hintStyle: GoogleFonts.openSans(
                            color: AppColors.muted.withOpacity(0.35),
                            fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        filled: true,
                        fillColor: accentColor.withOpacity(0.1),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide:
                                BorderSide(color: accentColor, width: 1)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: AppColors.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details ──────────────────────────────────────────────
          if (isExpanded) ...[
            Divider(
                color: accentColor.withOpacity(0.2),
                height: 1,
                indent: 54),
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device + Position
                  Row(children: [
                    Expanded(child: _detailField('Gerät',    ctrls[1])),
                    const SizedBox(width: 8),
                    Expanded(child: _detailField('Position', ctrls[2])),
                  ]),
                  const SizedBox(height: 12),

                  // Results header
                  Text('ERGEBNISSE',
                      style: GoogleFonts.openSans(
                          color: AppColors.muted.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),

                  // Date result inputs
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

  Widget _detailField(String label, TextEditingController ctrl) => TextField(
        controller: ctrl,
        style: GoogleFonts.openSans(color: AppColors.text, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.openSans(color: AppColors.muted, fontSize: 10),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor, width: 1)),
          isDense: true,
        ),
      );

  Widget _dateResultField(String label, TextEditingController ctrl) =>
      SizedBox(
        width: 60,
        child: TextField(
          controller: ctrl,
          style: GoogleFonts.openSans(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                GoogleFonts.openSans(color: AppColors.muted, fontSize: 8),
            floatingLabelAlignment: FloatingLabelAlignment.center,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor, width: 1)),
            isDense: true,
          ),
        ),
      );
}
