import 'dart:async';
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

  // Per-section: row controllers, date controllers, liked, disliked
  late List<List<TextEditingController>> _sRowCtrls;
  late List<List<TextEditingController>> _mRowCtrls;
  late List<List<TextEditingController>> _cRowCtrls;
  late List<List<TextEditingController>> _mobRowCtrls;
  late List<List<TextEditingController>> _sDateCtrls;
  late List<List<TextEditingController>> _mDateCtrls;
  late List<List<TextEditingController>> _cDateCtrls;
  late List<List<TextEditingController>> _mobDateCtrls;
  late List<bool> _sLiked;
  late List<bool> _mLiked;
  late List<bool> _cLiked;
  late List<bool> _mobLiked;
  late List<bool> _sDisliked;
  late List<bool> _mDisliked;
  late List<bool> _cDisliked;
  late List<bool> _mobDisliked;

  final Set<String> _expanded = {};

  // ─── Timer state ──────────────────────────────────────────────────────
  final Stopwatch _sw = Stopwatch();
  Timer? _tickTimer;
  String _timerDisplay = '00:00';
  bool _isCountdown = false;
  int _countdownFrom = 0;
  int _countdownRemaining = 0;
  bool _timerRunning = false;
  String? _activeExPrefix;
  int? _activeExIndex;
  String _activeExName = '';

  late List<int> _sTimeSettings;
  late List<int> _mTimeSettings;
  late List<int> _cTimeSettings;
  late List<int> _mobTimeSettings;

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

    _sRowCtrls    = _buildRowCtrls(_values.sonsomo);
    _mRowCtrls    = _buildRowCtrls(_values.main);
    _cRowCtrls    = _buildRowCtrls(_values.core);
    _mobRowCtrls  = _buildRowCtrls(_values.mobility);
    _sDateCtrls   = _buildDateCtrls(_values.sonsomo);
    _mDateCtrls   = _buildDateCtrls(_values.main);
    _cDateCtrls   = _buildDateCtrls(_values.core);
    _mobDateCtrls = _buildDateCtrls(_values.mobility);
    _sLiked       = _values.sonsomo.map((r) => r.liked).toList();
    _mLiked       = _values.main.map((r) => r.liked).toList();
    _cLiked       = _values.core.map((r) => r.liked).toList();
    _mobLiked     = _values.mobility.map((r) => r.liked).toList();
    _sDisliked    = _values.sonsomo.map((r) => r.disliked).toList();
    _mDisliked    = _values.main.map((r) => r.disliked).toList();
    _cDisliked    = _values.core.map((r) => r.disliked).toList();
    _mobDisliked  = _values.mobility.map((r) => r.disliked).toList();
    _sTimeSettings   = List.filled(_values.sonsomo.length, 0);
    _mTimeSettings   = List.filled(_values.main.length, 0);
    _cTimeSettings   = List.filled(_values.core.length, 0);
    _mobTimeSettings = List.filled(_values.mobility.length, 0);
  }

  List<List<TextEditingController>> _buildRowCtrls(List<TrainingPlanRow> rows) =>
      rows.map((r) => [
            TextEditingController(text: r.exercise),  // 0
            TextEditingController(text: r.device),     // 1
            TextEditingController(text: r.position),   // 2
            TextEditingController(text: r.weight),     // 3
            TextEditingController(text: r.sets),       // 4
          ]).toList();

  List<List<TextEditingController>> _buildDateCtrls(List<TrainingPlanRow> rows) =>
      rows.map((r) => List.generate(8, (i) => TextEditingController(text: r.dates[i]))).toList();

  // ─── Add / Remove exercise ──────────────────────────────────────────────

  void _addExercise(String prefix) {
    setState(() {
      _rowCtrls(prefix).add([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),  // sets
      ]);
      _dateCtrlsFor(prefix).add(List.generate(8, (_) => TextEditingController()));
      _likedFor(prefix).add(false);
      _dislikedFor(prefix).add(false);
      _timeSettingsFor(prefix).add(0);
    });
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
      if (confirmed != true) return;
      setState(() {
        final rc = _rowCtrls(prefix);
        final dc = _dateCtrlsFor(prefix);
        for (final c in rc[index]) c.dispose();
        rc.removeAt(index);
        for (final c in dc[index]) c.dispose();
        dc.removeAt(index);
        _likedFor(prefix).removeAt(index);
        _dislikedFor(prefix).removeAt(index);
        _timeSettingsFor(prefix).removeAt(index);
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

  // ─── Helpers to get lists by prefix ─────────────────────────────────────

  List<List<TextEditingController>> _rowCtrls(String p) =>
      p == 's' ? _sRowCtrls : p == 'm' ? _mRowCtrls : p == 'mob' ? _mobRowCtrls : _cRowCtrls;

  List<List<TextEditingController>> _dateCtrlsFor(String p) =>
      p == 's' ? _sDateCtrls : p == 'm' ? _mDateCtrls : p == 'mob' ? _mobDateCtrls : _cDateCtrls;

  List<bool> _likedFor(String p) =>
      p == 's' ? _sLiked : p == 'm' ? _mLiked : p == 'mob' ? _mobLiked : _cLiked;

  List<bool> _dislikedFor(String p) =>
      p == 's' ? _sDisliked : p == 'm' ? _mDisliked : p == 'mob' ? _mobDisliked : _cDisliked;

  List<int> _timeSettingsFor(String p) =>
      p == 's' ? _sTimeSettings : p == 'm' ? _mTimeSettings : p == 'mob' ? _mobTimeSettings : _cTimeSettings;

  // ─── Timer controls ─────────────────────────────────────────────────────

  void _toggleMainTimer() {
    if (_timerRunning) {
      _pauseMainTimer();
    } else {
      _startMainTimer();
    }
  }

  void _startMainTimer() {
    setState(() => _timerRunning = true);
    if (_isCountdown) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _countdownRemaining--;
          if (_countdownRemaining <= 0) {
            _countdownRemaining = 0;
            _timerRunning = false;
            _tickTimer?.cancel();
          }
          _updateTimerDisplay();
        });
      });
    } else {
      _sw.start();
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _updateTimerDisplay());
      });
    }
  }

  void _pauseMainTimer() {
    _tickTimer?.cancel();
    if (!_isCountdown) _sw.stop();
    setState(() => _timerRunning = false);
  }

  void _resetMainTimer() {
    _tickTimer?.cancel();
    _sw.stop();
    _sw.reset();
    setState(() {
      _timerRunning = false;
      if (_isCountdown) {
        _countdownRemaining = _countdownFrom;
      }
      _updateTimerDisplay();
    });
  }

  void _selectExerciseTime(String prefix, int index, int seconds) {
    _tickTimer?.cancel();
    _sw.stop();
    _sw.reset();
    setState(() {
      _timeSettingsFor(prefix)[index] = seconds;
      _isCountdown = true;
      _countdownFrom = seconds;
      _countdownRemaining = seconds;
      _timerRunning = false;
      _activeExPrefix = prefix;
      _activeExIndex = index;
      _activeExName = _rowCtrls(prefix)[index][0].text.isNotEmpty
          ? _rowCtrls(prefix)[index][0].text
          : 'Übung ${index + 1}';
      _updateTimerDisplay();
    });
  }

  void _switchToStopwatch() {
    _tickTimer?.cancel();
    _sw.stop();
    _sw.reset();
    setState(() {
      _isCountdown = false;
      _countdownFrom = 0;
      _countdownRemaining = 0;
      _timerRunning = false;
      _activeExPrefix = null;
      _activeExIndex = null;
      _activeExName = '';
      _updateTimerDisplay();
    });
  }

  void _updateTimerDisplay() {
    if (_isCountdown) {
      final m = (_countdownRemaining ~/ 60).toString().padLeft(2, '0');
      final s = (_countdownRemaining % 60).toString().padLeft(2, '0');
      _timerDisplay = '$m:$s';
    } else {
      final total = _sw.elapsed.inSeconds;
      final m = (total ~/ 60).toString().padLeft(2, '0');
      final s = (total % 60).toString().padLeft(2, '0');
      _timerDisplay = '$m:$s';
    }
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
      if (seconds != null && seconds > 0) {
        _selectExerciseTime(prefix, index, seconds);
      }
    });
  }

  // ─── Collect values for save ─────────────────────────────────────────────

  TrainingPlanValues _collectValues() {
    final dates = List.generate(8, (i) => _dateCtrls[i].text);

    List<TrainingPlanRow> collect(
      List<List<TextEditingController>> rc,
      List<List<TextEditingController>> dc,
      List<bool> liked,
      List<bool> disliked,
    ) =>
        List.generate(rc.length, (i) => TrainingPlanRow(
              exercise: rc[i][0].text,
              device:   rc[i][1].text,
              position: rc[i][2].text,
              weight:   rc[i][3].text,
              sets:     rc[i][4].text,
              dates:    List.generate(8, (j) => dc[i][j].text),
              liked:    liked[i],
              disliked: disliked[i],
            ));

    return TrainingPlanValues(
      sonsomo:  collect(_sRowCtrls, _sDateCtrls, _sLiked, _sDisliked),
      main:     collect(_mRowCtrls, _mDateCtrls, _mLiked, _mDisliked),
      core:     collect(_cRowCtrls, _cDateCtrls, _cLiked, _cDisliked),
      mobility: collect(_mobRowCtrls, _mobDateCtrls, _mobLiked, _mobDisliked),
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
    _tickTimer?.cancel();
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _dateCtrls) c.dispose();
    for (final row in [..._sRowCtrls, ..._mRowCtrls, ..._cRowCtrls, ..._mobRowCtrls])
      for (final c in row) c.dispose();
    for (final sec in [..._sDateCtrls, ..._mDateCtrls, ..._cDateCtrls, ..._mobDateCtrls])
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
          _buildSectionTabs(),
          _buildTimerViewer(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTab('s', _sRowCtrls, _sDateCtrls, _sLiked, _sDisliked, 0),
                _buildTab('m', _mRowCtrls, _mDateCtrls, _mLiked, _mDisliked, 1),
                _buildTab('c', _cRowCtrls, _cDateCtrls, _cLiked, _cDisliked, 2),
                _buildTab('mob', _mobRowCtrls, _mobDateCtrls, _mobLiked, _mobDisliked, 3),
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
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 20),
                onPressed: () => Navigator.pop(context),
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
                  color: AppColors.muted, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.8)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(8, (i) => Padding(
                padding: const EdgeInsets.only(right: 7),
                child: SizedBox(
                  width: 76,
                  child: TextField(
                    controller: _dateCtrls[i],
                    style: GoogleFonts.openSans(
                        color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '${i + 1}. Datum',
                      hintStyle: GoogleFonts.openSans(
                          color: AppColors.muted.withAlpha(102), fontSize: 10),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      isDense: true,
                    ),
                  ),
                ),
              )),
            ),
          ),
        ],
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
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _timerRunning
                ? AppColors.primary.withAlpha(128)
                : AppColors.border,
            width: _timerRunning ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            // Play / Pause
            GestureDetector(
              onTap: _toggleMainTimer,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _timerRunning
                      ? AppColors.primary.withAlpha(26)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Icon(
                  _timerRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: _timerRunning ? AppColors.primary : Colors.white,
                  size: 28,
                ),
              ),
            ),
            // Time display centered
            Expanded(
              child: Column(
                children: [
                  Text(
                    _timerDisplay,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: _timerRunning
                          ? Colors.white
                          : _isCountdown && _countdownRemaining == 0
                              ? AppColors.red
                              : AppColors.text,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isCountdown
                        ? 'Countdown${_activeExName.isNotEmpty ? ' · $_activeExName' : ''}'
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
                  onTap: _resetMainTimer,
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
                if (_isCountdown) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _switchToStopwatch,
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

  Widget _buildTab(
    String prefix,
    List<List<TextEditingController>> rowCtrls,
    List<List<TextEditingController>> dateCtrls,
    List<bool> liked,
    List<bool> disliked,
    int sectionIdx,
  ) {
    final section = _sections[sectionIdx];
    final filledCount = rowCtrls.where((r) => r[0].text.isNotEmpty).length;

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
        ...List.generate(rowCtrls.length, (i) {
          final key = '$prefix-$i';
          return _ExerciseTile(
            key: ValueKey('$prefix-$i-${rowCtrls.length}'),
            number:      i + 1,
            ctrls:       rowCtrls[i],
            dateCtrls:   dateCtrls[i],
            dateLabels:  _dateCtrls.map((c) => c.text).toList(),
            accentColor: section.color,
            isLiked:     liked[i],
            isDisliked:  disliked[i],
            isExpanded:  _expanded.contains(key),
            onToggle: () => setState(() {
              _expanded.contains(key)
                  ? _expanded.remove(key)
                  : _expanded.add(key);
            }),
            onLike: () => setState(() {
              liked[i] = !liked[i];
              if (liked[i]) disliked[i] = false;
            }),
            onDislike: () => setState(() {
              disliked[i] = !disliked[i];
              if (disliked[i]) liked[i] = false;
            }),
            onDelete: () => _removeExercise(prefix, i),
            timeSetting: _timeSettingsFor(prefix)[i],
            isTimerTarget: _activeExPrefix == prefix && _activeExIndex == i,
            onTimeSelect: (seconds) => _selectExerciseTime(prefix, i, seconds),
            onManualTime: () => _showManualTimeDialog(prefix, i),
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
  final int timeSetting;
  final bool isTimerTarget;
  final ValueChanged<int> onTimeSelect;
  final VoidCallback onManualTime;

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
    required this.timeSetting,
    required this.isTimerTarget,
    required this.onTimeSelect,
    required this.onManualTime,
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
                            (ctrls[1].text.isNotEmpty || ctrls[2].text.isNotEmpty || ctrls[4].text.isNotEmpty)) ...[
                          const SizedBox(height: 2),
                          Text(
                            [ctrls[1].text, ctrls[2].text, if (ctrls[4].text.isNotEmpty) ctrls[4].text]
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
                  const SizedBox(width: 6),

                  // Sets pill
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: ctrls[4],
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
                  Text('TIMER',
                      style: GoogleFonts.openSans(
                          color: AppColors.muted.withAlpha(153),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TimerPresetChip(
                        label: '30s',
                        isActive: timeSetting == 30 && isTimerTarget,
                        accentColor: accentColor,
                        onTap: () => onTimeSelect(30),
                      ),
                      const SizedBox(width: 6),
                      _TimerPresetChip(
                        label: '45s',
                        isActive: timeSetting == 45 && isTimerTarget,
                        accentColor: accentColor,
                        onTap: () => onTimeSelect(45),
                      ),
                      const SizedBox(width: 6),
                      _TimerPresetChip(
                        label: '60s',
                        isActive: timeSetting == 60 && isTimerTarget,
                        accentColor: accentColor,
                        onTap: () => onTimeSelect(60),
                      ),
                      const SizedBox(width: 6),
                      _TimerPresetChip(
                        label: timeSetting > 0 && timeSetting != 30 && timeSetting != 45 && timeSetting != 60
                            ? '${timeSetting}s'
                            : 'Eigene',
                        isActive: timeSetting > 0 && timeSetting != 30 && timeSetting != 45 && timeSetting != 60 && isTimerTarget,
                        accentColor: accentColor,
                        onTap: onManualTime,
                        icon: Icons.edit_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 10),

                  // Like / Dislike / Delete action row
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
  final Color accentColor;
  final VoidCallback onTap;
  final IconData? icon;

  const _TimerPresetChip({
    required this.label,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
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
          if (icon != null) ...[
            Icon(icon, size: 12, color: isActive ? accentColor : AppColors.muted),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: GoogleFonts.openSans(
                  color: isActive ? accentColor : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
