import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/client.dart';
import '../models/training_plan.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import '../providers/exercise_timer.dart';
import 'exercise_catalog_sheet.dart';

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

  // Per-section state (replaces 20 individual lists)
  late final Map<String, _SectionData> _sec;

  final Set<String> _expanded = {};
  bool _hasUnsavedChanges = false;
  bool _catalogOpen = false;

  // Exercise-level comment counts (loaded from API)
  Map<String, int> _commentCounts = {};

  // ─── Timer (separate ChangeNotifier) ──────────────────────────────────
  late final ExerciseTimer _timer;

  static const _sectionKeys = ['s', 'm', 'c', 'mob'];

  static const _sections = [
    _SectionMeta('AUFWÄRMEN',    'Warm-up / Sonsomo', Icons.accessibility_new, AppColors.primary),
    _SectionMeta('HAUPTTRAINING','Main',              Icons.fitness_center,    AppColors.blue),
    _SectionMeta('CORE',         'Core',              Icons.self_improvement,  AppColors.green),
    _SectionMeta('MOBILITÄT',    'Mobility',          Icons.swap_calls,        AppColors.orange),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _values = widget.plan?.values ?? TrainingPlanValues();
    _nameCtrl.text = widget.plan?.name ?? '';
    for (var i = 0; i < 8; i++) _dateCtrls[i].text = _values.dates[i];

    final rowsMap = {
      's': _values.sonsomo, 'm': _values.main,
      'c': _values.core, 'mob': _values.mobility,
    };
    _sec = { for (final key in _sectionKeys)
      key: _SectionData.fromRows(rowsMap[key]!),
    };

    _timer = ExerciseTimer()..addListener(_onTimerChanged);

    // Track unsaved changes via name controller
    _nameCtrl.addListener(_markDirty);

    // Load comment counts if plan already exists
    _loadCommentCounts();
  }

  Future<void> _loadCommentCounts() async {
    final planId = widget.plan?.id;
    if (planId == null) return;
    try {
      final data = await _api.get('${ApiConfig.trainingPlan}/$planId/comment-counts');
      if (data is Map && mounted) {
        setState(() {
          _commentCounts = Map<String, int>.from(
            data.map((k, v) => MapEntry(k.toString(), v is int ? v : int.tryParse(v.toString()) ?? 0)),
          );
        });
      }
    } catch (_) {
      // Non-critical — counts will just show 0
    }
  }

  void _onTimerChanged() {
    if (mounted) setState(() {});
  }

  void _markDirty() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Änderungen verwerfen?',
            style: GoogleFonts.montserrat(
                color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text('Du hast ungespeicherte Änderungen. Möchtest du wirklich zurückgehen?',
            style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Verwerfen')),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Add / Remove exercise ──────────────────────────────────────────────

  Future<void> _addExercise(String prefix) async {
    if (_catalogOpen) return;
    _catalogOpen = true;
    try {
    final result = await ExerciseCatalogSheet.show(context);
    if (result == null || !mounted) return;
    _markDirty();
    setState(() {
      final s = _s(prefix);
      s.rowCtrls.add([
        TextEditingController(text: result.name),
        TextEditingController(text: result.device),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),  // sets
      ]);
      s.dateCtrls.add(List.generate(8, (_) => TextEditingController()));
      s.liked.add(false);
      s.disliked.add(false);
      s.timeSettings.add(0);
    });
    } finally {
      _catalogOpen = false;
    }
  }

  void _removeExercise(String prefix, int index) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Übung löschen?',
            style: GoogleFonts.montserrat(
                color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text('Diese Übung wird unwiderruflich entfernt.',
            style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Löschen')),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      setState(() {
        final s = _s(prefix);
        for (final c in s.rowCtrls[index]) c.dispose();
        s.rowCtrls.removeAt(index);
        for (final c in s.dateCtrls[index]) c.dispose();
        s.dateCtrls.removeAt(index);
        s.liked.removeAt(index);
        s.disliked.removeAt(index);
        s.timeSettings.removeAt(index);

        // Reset timer if the deleted exercise was the active timer target
        _timer.onExerciseRemoved(prefix, index);

        // Re-key expanded state
        final reKeyed = <String>{};
        for (final k in _expanded) {
          if (!k.startsWith('$prefix-')) { reKeyed.add(k); continue; }
          final i = int.tryParse(k.substring(prefix.length + 1));
          if (i == null || i == index) continue;
          reKeyed.add('$prefix-${i > index ? i - 1 : i}');
        }
        _expanded
          ..clear()
          ..addAll(reKeyed);
      });
    });
  }

  // ─── Section data access ─────────────────────────────────────────────────

  _SectionData _s(String p) => _sec[p]!;

  // ─── Timer controls (delegated to ExerciseTimer) ────────────────────────

  void _selectExerciseTime(String prefix, int index, int seconds) {
    final s = _s(prefix);
    // If tapping the same already-saved preset → clear it (delete saved timer)
    if (s.timeSettings[index] == seconds) {
      s.timeSettings[index] = 0;
      _timer.switchToStopwatch();
      _markDirty();
      return;
    }
    s.timeSettings[index] = seconds;
    _markDirty();
    final name = s.rowCtrls[index][0].text.isNotEmpty
        ? s.rowCtrls[index][0].text
        : 'Übung ${index + 1}';
    _timer.selectCountdown(
      prefix: prefix, index: index, name: name, seconds: seconds,
    );
  }

  void _showManualTimeDialog(String prefix, int index) {
    final ctrl = TextEditingController();
    showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Zeit eingeben',
            style: GoogleFonts.montserrat(
                color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.montserrat(
              color: AppColors.text, fontSize: 28, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '90',
            suffixText: 'Sek.',
            suffixStyle: GoogleFonts.openSans(color: AppColors.muted, fontSize: 14),
            hintStyle: GoogleFonts.montserrat(color: AppColors.muted.withAlpha(77), fontSize: 28),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () {
                final val = int.tryParse(ctrl.text);
                Navigator.pop(context, val);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Übernehmen')),
        ],
      ),
    ).then((seconds) {
      ctrl.dispose();
      if (seconds != null && seconds > 0 && mounted) {
        _selectExerciseTime(prefix, index, seconds);
      }
    });
  }

  // ─── Comments bottom sheet ───────────────────────────────────────────────

  void _showCommentsSheet() {
    final planId = widget.plan?.id;
    if (planId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(planId: planId),
    );
  }

  void _showExerciseCommentsSheet(String prefix, int index) {
    final planId = widget.plan?.id;
    if (planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst den Plan speichern'), backgroundColor: AppColors.red),
      );
      return;
    }
    final exerciseKey = '$prefix-$index';
    final s = _s(prefix);
    final exerciseName = s.rowCtrls[index][0].text.isNotEmpty
        ? s.rowCtrls[index][0].text
        : 'Übung ${index + 1}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        planId: planId,
        exerciseKey: exerciseKey,
        exerciseName: exerciseName,
      ),
    ).then((_) => _loadCommentCounts()); // refresh counts after closing
  }

  // ─── Collect values for save ─────────────────────────────────────────────

  TrainingPlanValues _collectValues() {
    final dates = List.generate(8, (i) => _dateCtrls[i].text);

    List<TrainingPlanRow> collect(String prefix) {
      final s = _s(prefix);
      return List.generate(s.rowCtrls.length, (i) => TrainingPlanRow(
            exercise: s.rowCtrls[i][0].text,
            device:   s.rowCtrls[i][1].text,
            position: s.rowCtrls[i][2].text,
            weight:   s.rowCtrls[i][3].text,
            sets:     s.rowCtrls[i][4].text,
            dates:    List.generate(8, (j) => s.dateCtrls[i][j].text),
            liked:    s.liked[i],
            disliked: s.disliked[i],
            timer:    s.timeSettings[i],
          ));
    }

    return TrainingPlanValues(
      sonsomo:  collect('s'),
      main:     collect('m'),
      core:     collect('c'),
      mobility: collect('mob'),
      dates:    dates,
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
    _timer.removeListener(_onTimerChanged);
    _timer.dispose();
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _dateCtrls) c.dispose();
    for (final s in _sec.values) s.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeroHeader(),
            _buildSectionTabs(),
            _buildTimerViewer(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  ...List.generate(4, (i) => _buildTab(_sectionKeys[i], i)),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: widget.plan?.id != null
            ? FloatingActionButton(
                mini: true,
                backgroundColor: AppColors.surface,
                shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
                onPressed: () => _showCommentsSheet(),
                child: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.muted),
              )
            : null,
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
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 20),
                onPressed: () async {
                  if (_hasUnsavedChanges) {
                    final shouldPop = await _onWillPop();
                    if (!shouldPop || !mounted) return;
                  }
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.montserrat(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      decoration: InputDecoration(
                        hintText: 'Planname…',
                        hintStyle: GoogleFonts.montserrat(
                            color: Colors.white24, fontSize: 22,
                            fontWeight: FontWeight.w800),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(widget.client.name,
                          style: GoogleFonts.openSans(color: Colors.white38, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                label: Text(_saving ? '…' : 'Speichern',
                    style: GoogleFonts.openSans(
                        color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section tabs ─────────────────────────────────────────────────────────

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
            labelStyle: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w500),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: _sections.map((s) => Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.icon, size: 13),
                const SizedBox(width: 5),
                Text(s.label),
              ]),
            )).toList(),
          ),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }

  // ─── Timer viewer ─────────────────────────────────────────────────────────

  Widget _buildTimerViewer() {
    final t = _timer;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.isRunning
                ? AppColors.primary.withAlpha(128)
                : AppColors.border,
            width: t.isRunning ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            // Play / Pause
            GestureDetector(
              onTap: t.toggle,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: t.isRunning
                      ? AppColors.primary.withAlpha(26)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Icon(
                  t.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: t.isRunning ? AppColors.primary : Colors.white,
                  size: 28,
                ),
              ),
            ),
            // Time display centered
            Expanded(
              child: Column(
                children: [
                  Text(
                    t.display,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: t.isRunning
                          ? Colors.white
                          : t.isCountdown && t.countdownRemaining == 0
                              ? AppColors.red
                              : AppColors.text,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.isCountdown
                        ? 'Countdown${t.activeName.isNotEmpty ? ' · ${t.activeName}' : ''}'
                        : 'Stoppuhr',
                    style: GoogleFonts.openSans(
                        color: AppColors.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Reset + Stopwatch toggle
            Column(
              children: [
                GestureDetector(
                  onTap: t.reset,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.replay_rounded,
                        color: AppColors.muted, size: 20),
                  ),
                ),
                if (t.isCountdown) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: t.switchToStopwatch,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined,
                          color: AppColors.muted, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Exercise tab ─────────────────────────────────────────────────────────

  Widget _buildTab(String prefix, int sectionIdx) {
    final section = _sections[sectionIdx];
    final s = _s(prefix);
    final filledCount = s.rowCtrls.where((r) => r[0].text.isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        // Section label + count
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: section.color.withAlpha(31),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: section.color.withAlpha(77), width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(section.icon, size: 12, color: section.color),
                const SizedBox(width: 5),
                Text(section.subtitle,
                    style: GoogleFonts.openSans(
                        color: section.color, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text('$filledCount ${filledCount == 1 ? 'Übung' : 'Übungen'}',
                style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 11)),
          ]),
        ),

        // Exercise tiles
        ...List.generate(s.rowCtrls.length, (i) {
          final key = '$prefix-$i';
          final exerciseKey = '$prefix-$i';
          return _ExerciseTile(
            key: ValueKey('$prefix-$i-${s.rowCtrls.length}'),
            number:      i + 1,
            ctrls:       s.rowCtrls[i],
            dateCtrls:   s.dateCtrls[i],
            dateLabels:  _dateCtrls.map((c) => c.text).toList(),
            accentColor: section.color,
            commentCount: _commentCounts[exerciseKey] ?? 0,
            isLiked:     s.liked[i],
            isDisliked:  s.disliked[i],
            isExpanded:  _expanded.contains(key),
            onToggle: () => setState(() {
              _expanded.contains(key)
                  ? _expanded.remove(key)
                  : _expanded.add(key);
            }),
            onLike: () { _markDirty(); setState(() {
              s.liked[i] = !s.liked[i];
              if (s.liked[i]) s.disliked[i] = false;
            }); },
            onDislike: () { _markDirty(); setState(() {
              s.disliked[i] = !s.disliked[i];
              if (s.disliked[i]) s.liked[i] = false;
            }); },
            onDelete: () => _removeExercise(prefix, i),
            onFieldChanged: _markDirty,
            timeSetting: s.timeSettings[i],
            isTimerTarget: _timer.activePrefix == prefix && _timer.activeIndex == i,
            onTimeSelect: (seconds) => _selectExerciseTime(prefix, i, seconds),
            onManualTime: () => _showManualTimeDialog(prefix, i),
            onComment: () => _showExerciseCommentsSheet(prefix, i),
          );
        }),

        // Add exercise button
        const SizedBox(height: 6),
        _buildAddButton(prefix, section.color),
      ],
    );
  }

  Widget _buildAddButton(String prefix, Color color) {
    return GestureDetector(
      onTap: () => _addExercise(prefix),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withAlpha(77),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: color.withAlpha(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: color.withAlpha(204)),
            const SizedBox(width: 8),
            Text(
              'Übung hinzufügen',
              style: GoogleFonts.openSans(
                  color: color.withAlpha(204),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-section state container (replaces 20 individual lists)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionData {
  final List<List<TextEditingController>> rowCtrls;
  final List<List<TextEditingController>> dateCtrls;
  final List<bool> liked;
  final List<bool> disliked;
  final List<int> timeSettings;

  _SectionData({
    required this.rowCtrls,
    required this.dateCtrls,
    required this.liked,
    required this.disliked,
    required this.timeSettings,
  });

  factory _SectionData.fromRows(List<TrainingPlanRow> rows) {
    return _SectionData(
      rowCtrls: rows.map((r) => [
        TextEditingController(text: r.exercise),
        TextEditingController(text: r.device),
        TextEditingController(text: r.position),
        TextEditingController(text: r.weight),
        TextEditingController(text: r.sets),
      ]).toList(),
      dateCtrls: rows.map((r) =>
        List.generate(8, (i) => TextEditingController(text: r.dates[i])),
      ).toList(),
      liked: rows.map((r) => r.liked).toList(),
      disliked: rows.map((r) => r.disliked).toList(),
      timeSettings: rows.map((r) => r.timer).toList(),
    );
  }

  void dispose() {
    for (final row in rowCtrls) {
      for (final c in row) c.dispose();
    }
    for (final row in dateCtrls) {
      for (final c in row) c.dispose();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionMeta {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _SectionMeta(this.label, this.subtitle, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  final int number;
  final List<TextEditingController> ctrls;
  final List<TextEditingController> dateCtrls;
  final List<String> dateLabels;
  final Color accentColor;
  final bool isLiked;
  final bool isDisliked;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onDelete;
  final VoidCallback onFieldChanged;
  final int timeSetting;
  final bool isTimerTarget;
  final ValueChanged<int> onTimeSelect;
  final VoidCallback onManualTime;
  final int commentCount;
  final VoidCallback onComment;

  const _ExerciseTile({
    super.key,
    required this.number,
    required this.ctrls,
    required this.dateCtrls,
    required this.dateLabels,
    required this.accentColor,
    required this.isLiked,
    required this.isDisliked,
    required this.isExpanded,
    required this.onToggle,
    required this.onLike,
    required this.onDislike,
    required this.onDelete,
    required this.onFieldChanged,
    required this.timeSetting,
    required this.isTimerTarget,
    required this.onTimeSelect,
    required this.onManualTime,
    this.commentCount = 0,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = ctrls[0].text.isNotEmpty;

    // Determine tile accent: liked=green, disliked=red, else normal
    final borderColor = isTimerTarget
        ? AppColors.primary.withAlpha(128)
        : isLiked
            ? AppColors.green.withAlpha(128)
            : isDisliked
                ? AppColors.red.withAlpha(102)
                : isExpanded
                    ? accentColor.withAlpha(89)
                    : AppColors.border.withAlpha(128);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  // Number badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isLiked
                          ? AppColors.green.withAlpha(38)
                          : isDisliked
                              ? AppColors.red.withAlpha(31)
                              : hasContent
                                  ? accentColor.withAlpha(38)
                                  : AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: GoogleFonts.montserrat(
                          color: isLiked
                              ? AppColors.green
                              : isDisliked
                                  ? AppColors.red
                                  : hasContent
                                      ? accentColor
                                      : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Exercise name field
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: ctrls[0],
                          onChanged: (_) => onFieldChanged(),
                          style: GoogleFonts.openSans(
                            color: hasContent
                                ? AppColors.text
                                : AppColors.muted.withAlpha(128),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Übung eingeben…',
                            hintStyle: GoogleFonts.openSans(
                                color: AppColors.muted.withAlpha(77),
                                fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (!isExpanded &&
                            (ctrls[1].text.isNotEmpty || ctrls[2].text.isNotEmpty || ctrls[4].text.isNotEmpty || timeSetting > 0 || commentCount > 0)) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (timeSetting > 0) ...[
                                Icon(Icons.timer_outlined, size: 10, color: AppColors.primary.withAlpha(153)),
                                Text(' ${timeSetting}s',
                                    style: GoogleFonts.openSans(
                                        color: AppColors.primary.withAlpha(153), fontSize: 10, fontWeight: FontWeight.w600)),
                                if (ctrls[1].text.isNotEmpty || ctrls[2].text.isNotEmpty || commentCount > 0)
                                  Text('  ·  ', style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 11)),
                              ],
                              if (commentCount > 0) ...[
                                Icon(Icons.chat_bubble_outline, size: 10, color: accentColor.withAlpha(153)),
                                Text(' $commentCount',
                                    style: GoogleFonts.openSans(
                                        color: accentColor.withAlpha(153), fontSize: 10, fontWeight: FontWeight.w600)),
                                if (ctrls[1].text.isNotEmpty || ctrls[2].text.isNotEmpty)
                                  Text('  ·  ', style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 11)),
                              ],
                              Expanded(
                                child: Text(
                                  [ctrls[1].text, ctrls[2].text, if (ctrls[4].text.isNotEmpty) ctrls[4].text]
                                      .where((s) => s.isNotEmpty)
                                      .join('  ·  '),
                                  style: GoogleFonts.openSans(
                                      color: AppColors.muted, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Sets pill
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: ctrls[4],
                      onChanged: (_) => onFieldChanged(),
                      style: GoogleFonts.openSans(
                          color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Sätze',
                        hintStyle: GoogleFonts.openSans(
                            color: AppColors.muted.withAlpha(77), fontSize: 10),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: accentColor, width: 1)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Weight pill
                  SizedBox(
                    width: 54,
                    child: TextField(
                      controller: ctrls[3],
                      onChanged: (_) => onFieldChanged(),
                      style: GoogleFonts.openSans(
                          color: accentColor, fontSize: 12, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'kg',
                        hintStyle: GoogleFonts.openSans(
                            color: AppColors.muted.withAlpha(77), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        filled: true,
                        fillColor: accentColor.withAlpha(26),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: accentColor, width: 1)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Chevron
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

          // ── Expanded details ───────────────────────────────────────────────
          if (isExpanded) ...[
            Divider(color: accentColor.withAlpha(51), height: 1, indent: 50),
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 12, 12, 14),
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

                  // Ergebnisse label
                  Text('ERGEBNISSE',
                      style: GoogleFonts.openSans(
                          color: AppColors.muted.withAlpha(153),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(8, (j) {
                      final lbl = j < dateLabels.length && dateLabels[j].isNotEmpty
                          ? dateLabels[j]
                          : '${j + 1}';
                      return _dateResultField(lbl, dateCtrls[j]);
                    }),
                  ),

                  const SizedBox(height: 14),

                  // Timer presets
                  Row(
                    children: [
                      Text('TIMER',
                          style: GoogleFonts.openSans(
                              color: AppColors.muted.withAlpha(153),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                      if (timeSetting > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(31),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${timeSetting}s gespeichert',
                              style: GoogleFonts.openSans(
                                  color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TimerPresetChip(
                        label: '30s',
                        isActive: timeSetting == 30,
                        isSaved: timeSetting == 30,
                        accentColor: accentColor,
                        onTap: () => onTimeSelect(30),
                      ),
                      const SizedBox(width: 6),
                      _TimerPresetChip(
                        label: '45s',
                        isActive: timeSetting == 45,
                        isSaved: timeSetting == 45,
                        accentColor: accentColor,
                        onTap: () => onTimeSelect(45),
                      ),
                      const SizedBox(width: 6),
                      _TimerPresetChip(
                        label: '60s',
                        isActive: timeSetting == 60,
                        isSaved: timeSetting == 60,
                        accentColor: accentColor,
                        onTap: () => onTimeSelect(60),
                      ),
                      const SizedBox(width: 6),
                      _TimerPresetChip(
                        label: timeSetting > 0 && timeSetting != 30 && timeSetting != 45 && timeSetting != 60
                            ? '${timeSetting}s'
                            : 'Eigene',
                        isActive: timeSetting > 0 && timeSetting != 30 && timeSetting != 45 && timeSetting != 60,
                        isSaved: timeSetting > 0 && timeSetting != 30 && timeSetting != 45 && timeSetting != 60,
                        accentColor: accentColor,
                        onTap: onManualTime,
                        icon: Icons.edit_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 10),

                  // Like / Dislike / Comment / Delete action row
                  Row(
                    children: [
                      // Like
                      _ActionChip(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        label: 'Gefällt mir',
                        color: isLiked ? AppColors.green : AppColors.muted,
                        filled: isLiked,
                        fillColor: AppColors.green.withAlpha(31),
                        onTap: onLike,
                      ),
                      const SizedBox(width: 8),
                      // Dislike
                      _ActionChip(
                        icon: isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                        label: 'Passt nicht',
                        color: isDisliked ? AppColors.red : AppColors.muted,
                        filled: isDisliked,
                        fillColor: AppColors.red.withAlpha(26),
                        onTap: onDislike,
                      ),
                      const SizedBox(width: 8),
                      // Comment
                      _ActionChip(
                        icon: Icons.chat_bubble_outline,
                        label: commentCount > 0 ? '$commentCount' : 'Kommentar',
                        color: commentCount > 0 ? accentColor : AppColors.muted,
                        filled: commentCount > 0,
                        fillColor: accentColor.withAlpha(26),
                        onTap: onComment,
                      ),
                      const Spacer(),
                      // Delete
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline,
                              size: 16, color: AppColors.red),
                        ),
                      ),
                    ],
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
        onChanged: (_) => onFieldChanged(),
        style: GoogleFonts.openSans(color: AppColors.text, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor, width: 1)),
          isDense: true,
        ),
      );

  Widget _dateResultField(String label, TextEditingController ctrl) => SizedBox(
        width: 60,
        child: TextField(
          controller: ctrl,
          onChanged: (_) => onFieldChanged(),
          style: GoogleFonts.openSans(
              color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.openSans(color: AppColors.muted, fontSize: 8),
            floatingLabelAlignment: FloatingLabelAlignment.center,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor, width: 1)),
            isDense: true,
          ),
        ),
      );
}

// ─── Small action chip ────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final Color fillColor;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.fillColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? fillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? color.withAlpha(102) : AppColors.border,
            width: 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.openSans(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Timer preset chip ──────────────────────────────────────────────────────

class _TimerPresetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isSaved;
  final Color accentColor;
  final VoidCallback onTap;
  final IconData? icon;

  const _TimerPresetChip({
    required this.label,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
    this.isSaved = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? accentColor.withAlpha(26) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? accentColor.withAlpha(128) : AppColors.border,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isSaved && !isActive) ...[
            Icon(Icons.check_circle, size: 11, color: AppColors.primary.withAlpha(153)),
            const SizedBox(width: 4),
          ],
          if (icon != null && !isSaved) ...[
            Icon(icon, size: 12, color: isActive ? accentColor : AppColors.muted),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: GoogleFonts.openSans(
                  color: isActive ? accentColor : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          if (isActive) ...[
            const SizedBox(width: 4),
            Icon(Icons.close, size: 10, color: accentColor.withAlpha(153)),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments Bottom Sheet — chat-style comment thread (Asana-like)
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final int planId;
  final String? exerciseKey;
  final String? exerciseName;
  const _CommentsSheet({required this.planId, this.exerciseKey, this.exerciseName});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic>? _comments;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ek = widget.exerciseKey;
      final url = ek != null
          ? '${ApiConfig.trainingPlan}/${widget.planId}/comments?exerciseKey=$ek'
          : '${ApiConfig.trainingPlan}/${widget.planId}/comments';
      final data = await _api.get(url);
      if (!mounted) return;
      setState(() {
        _comments = data is List ? data : [];
        _error = null;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.post(
        '${ApiConfig.trainingPlan}/${widget.planId}/comments',
        body: {
          'text': text,
          if (widget.exerciseKey != null) 'exerciseKey': widget.exerciseKey,
        },
      );
      _ctrl.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kommentar löschen?',
            style: GoogleFonts.montserrat(
                color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text('Dieser Kommentar wird unwiderruflich entfernt.',
            style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('${ApiConfig.trainingPlan}/comments/$commentId');
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
      child: Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─ Handle + Title ─
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.exerciseName != null
                        ? widget.exerciseName!
                        : 'Kommentare',
                    style: GoogleFonts.montserrat(
                        color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_comments != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(31),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${_comments!.length}',
                          style: GoogleFonts.montserrat(
                              color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // ─ Comments list ─
          Flexible(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 36, color: AppColors.red),
                          const SizedBox(height: 8),
                          Text(_error!, style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _load, child: const Text('Erneut versuchen')),
                        ],
                      ),
                    ),
                  )
                : _comments == null
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                      ))
                    : _comments!.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 40, color: AppColors.muted.withAlpha(77)),
                                  const SizedBox(height: 12),
                                  Text('Noch keine Kommentare',
                                      style: GoogleFonts.openSans(
                                          color: AppColors.muted, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('Schreib den ersten Kommentar!',
                                      style: GoogleFonts.openSans(
                                          color: AppColors.muted.withAlpha(128), fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            itemCount: _comments!.length,
                            itemBuilder: (_, i) => _CommentBubble(
                              comment: _comments![i],
                              onDelete: () => _delete(_comments![i]['id']),
                            ),
                          ),
          ),

          // ─ Input bar ─
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: GoogleFonts.openSans(color: AppColors.text, fontSize: 14),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Kommentar schreiben…',
                      hintStyle: GoogleFonts.openSans(
                          color: AppColors.muted.withAlpha(128), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Single comment bubble ──────────────────────────────────────────────────

class _CommentBubble extends StatelessWidget {
  final dynamic comment;
  final VoidCallback onDelete;

  const _CommentBubble({required this.comment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final author = (comment['authorName'] ?? comment['author_name'] ?? 'Unbekannt') as String;
    final text = (comment['text'] ?? '') as String;
    final createdAt = comment['createdAt'] ?? comment['created_at'] ?? '';
    final timeStr = _formatTime(createdAt.toString());
    final initials = author.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(38),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withAlpha(77), width: 0.5),
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.montserrat(
                      color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          // Bubble
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(author,
                        style: GoogleFonts.openSans(
                            color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(timeStr,
                        style: GoogleFonts.openSans(
                            color: AppColors.muted.withAlpha(153), fontSize: 10)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline,
                            size: 14, color: AppColors.muted.withAlpha(102)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(color: AppColors.border.withAlpha(128), width: 0.5),
                  ),
                  child: Text(text,
                      style: GoogleFonts.openSans(
                          color: AppColors.text, fontSize: 13, height: 1.45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Gerade eben';
      if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
      if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
      if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
