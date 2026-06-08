import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/api_config.dart';
import '../models/training_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/exercise_timer.dart';
import '../services/training_plan_service.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import 'coaching_paywall_screen.dart';

// ─── Section metadata ─────────────────────────────────────────────────────────

class _SectionMeta {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const _SectionMeta(this.key, this.label, this.color, this.icon);
}

const _sections = [
  _SectionMeta('sonsomo', 'Aufwärmen',    AppColors.primary, Icons.accessibility_new),
  _SectionMeta('main',    'Haupttraining', AppColors.blue,    Icons.fitness_center),
  _SectionMeta('core',    'Core',          AppColors.green,   Icons.self_improvement),
  _SectionMeta('mobility','Mobilität',     AppColors.orange,  Icons.swap_calls),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClientPlanDetailScreen extends StatefulWidget {
  final int planId;
  final String? planName;
  const ClientPlanDetailScreen({super.key, required this.planId, this.planName});

  @override
  State<ClientPlanDetailScreen> createState() => _ClientPlanDetailScreenState();
}

class _ClientPlanDetailScreenState extends State<ClientPlanDetailScreen>
    with TickerProviderStateMixin {
  final _service = TrainingPlanService();
  late final ExerciseTimer _timer;
  late final TabController _tabCtrl;

  bool _loading = true;
  String? _error;
  ClientTrainingPlan? _plan;

  // Expanded state per exercise tile
  final Set<String> _expanded = {};

  // Client likes: exerciseKey → 'like'|'dislike'
  Map<String, String> _likes = {};

  // Comment counts per exerciseKey
  Map<String, int> _commentCounts = {};

  // Exercise name → id map for icon display
  Map<String, int> _exerciseIdMap = {};

  RealtimeService? _realtime;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _timer = ExerciseTimer()..addListener(() => setState(() {}));
    _load();
    _loadExerciseIds();
    _subscribeRealtime();
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

  @override
  void dispose() {
    _realtime?.dispose();
    _timer.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── Realtime ────────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    final auth = context.read<AuthProvider>();
    final token = apiClient.token;
    if (auth.clientId == null || token == null || token.isEmpty) return;
    _realtime = RealtimeService(
      channel: 'client_${auth.clientId}',
      token: token,
      onEvent: (type) {
        if (mounted && (type == 'plan_updated' || type == 'plan_comment')) _load();
      },
    )..connect();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = _plan == null; _error = null; });
    try {
      final plan = await _service.getPlan(widget.planId);
      if (!mounted) return;
      _likes = Map<String, String>.from(plan.clientLikes ?? {});
      await _loadCommentCounts();
      setState(() { _plan = plan; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Plan konnte nicht geladen werden'; _loading = false; });
    }
  }

  List<TrainingPlanRow> _sectionRows(TrainingPlanValues v, String key) {
    switch (key) {
      case 'sonsomo': return v.sonsomo;
      case 'main':    return v.main;
      case 'core':    return v.core;
      case 'mobility':return v.mobility;
      default:        return [];
    }
  }

  Future<void> _loadCommentCounts() async {
    if (widget.planId <= 0) return;
    try {
      final data = await apiClient.get('api/training-plan/${widget.planId}/comment-counts');
      if (data is Map) {
        _commentCounts = data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
  }

  // ─── Like / Dislike ───────────────────────────────────────────────────────

  Future<void> _toggleLike(String exerciseKey, String type) async {
    final plan = _plan;
    if (plan?.id == null) return;

    // Snapshot before optimistic update so we can revert precisely (no full reload)
    final prevLikes = Map<String, String>.from(_likes);
    setState(() {
      if (_likes[exerciseKey] == type) {
        _likes.remove(exerciseKey);
      } else {
        _likes[exerciseKey] = type;
      }
    });
    try {
      final result = await apiClient.post(
        'api/training-plan/${plan!.id}/like',
        body: {'exerciseKey': exerciseKey, 'type': type},
      );
      if (result is Map && mounted) {
        setState(() => _likes = Map<String, String>.from(result));
      }
    } catch (_) {
      // Revert to snapshot — no full re-fetch that would lose user's open tiles
      if (mounted) setState(() => _likes = prevLikes);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(widget.planName ?? 'Trainingsplan',
            style: GoogleFonts.inter(
                color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _plan == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _plan == null) {
      return _centered(Icons.error_outline, AppColors.red, _error!);
    }
    final plan = _plan;
    if (plan == null) return _centered(Icons.help_outline, AppColors.muted, 'Kein Plan');

    if (plan.locked || plan.values == null) {
      return _paywallRedirect(plan);
    }

    return Column(children: [
      _buildSectionTabs(),
      _buildTimerWidget(),
      Expanded(child: TabBarView(
        controller: _tabCtrl,
        children: _sections.map((m) => _buildTab(m, plan.values!)).toList(),
      )),
    ]);
  }

  // ─── Section tabs ─────────────────────────────────────────────────────────

  Widget _buildSectionTabs() {
    return Container(
      color: AppColors.background,
      child: Column(children: [
        const Divider(color: AppColors.border, height: 1),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
          tabs: _sections.map((m) => Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(m.icon, size: 14, color: m.color),
              const SizedBox(width: 5),
              Text(m.label.toUpperCase()),
            ]),
          )).toList(),
        ),
      ]),
    );
  }

  // ─── Timer ────────────────────────────────────────────────────────────────

  Widget _buildTimerWidget() {
    final t = _timer;
    final timeColor = (t.isCountdown && t.countdownRemaining == 0 && !t.isRunning)
        ? AppColors.red
        : t.isRunning ? AppColors.primary : AppColors.text;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isRunning ? AppColors.primary.withAlpha(180) : AppColors.border,
          width: t.isRunning ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play / Pause
          GestureDetector(
            onTap: t.toggle,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: t.isRunning ? AppColors.primary : AppColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                t.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: t.isRunning ? Colors.white : AppColors.primary, size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Time — dominant typography, FittedBox für responsive scaling
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                t.display,
                style: GoogleFonts.inter(
                  color: timeColor,
                  fontSize: 90,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Reset
          IconButton(
            icon: const Icon(Icons.replay_rounded, size: 20),
            color: AppColors.muted,
            onPressed: t.reset,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ─── Tab content ──────────────────────────────────────────────────────────

  Widget _buildTab(_SectionMeta meta, TrainingPlanValues v) {
    final rows = _sectionRows(v, meta.key);
    if (rows.isEmpty) {
      return Center(
        child: Text('Keine Übungen in diesem Abschnitt',
            style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: rows.length,
      itemBuilder: (context, i) => _buildExerciseTile(meta, i, rows[i]),
    );
  }

  // ─── Exercise Tile ────────────────────────────────────────────────────────

  Widget _buildExerciseTile(_SectionMeta meta, int i, TrainingPlanRow row) {
    final key = '${meta.key}-$i';
    final isExpanded = _expanded.contains(key);
    final likeType = _likes[key];
    final isLiked    = likeType == 'like';
    final isDisliked = likeType == 'dislike';
    final commentCount = _commentCounts[key] ?? 0;

    // Border color semantics (1:1 mit Trainer)
    Color borderColor = AppColors.border;
    if (isLiked)    borderColor = AppColors.green;
    if (isDisliked) borderColor = AppColors.red;
    final isTimerActive = _timer.isCountdown &&
        _timer.activePrefix == meta.key && _timer.activeIndex == i;
    if (isTimerActive) borderColor = meta.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isExpanded ? 1.5 : 1),
      ),
      child: Column(
        children: [
          // ── Collapsed header ──────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => isExpanded ? _expanded.remove(key) : _expanded.add(key)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                // Exercise image — fixed 100×100
                _buildExerciseBadge(i, row.exercise, meta.color, isLiked, isDisliked),
                const SizedBox(width: 12),
                // Name + hints
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.exercise.isEmpty ? 'Übung ${i + 1}' : row.exercise,
                          style: GoogleFonts.inter(
                              color: AppColors.text, fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      if (!isExpanded)
                        _collapsedHints(row, key, commentCount, meta.color),
                    ],
                  ),
                ),
                // Comment badge
                if (commentCount > 0 && !isExpanded)
                  Row(children: [
                    Icon(Icons.chat_bubble_outline, size: 12, color: meta.color.withAlpha(200)),
                    const SizedBox(width: 2),
                    Text('$commentCount',
                        style: GoogleFonts.inter(color: meta.color, fontSize: 11)),
                    const SizedBox(width: 6),
                  ]),
                // Chevron
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted, size: 20),
                ),
              ]),
            ),
          ),

          // ── Expanded content ──────────────────────────────────────────
          if (isExpanded) ...[
            const Divider(color: AppColors.border, height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata chips — compact Wrap (nur wenn vorhanden)
                  if (row.device.isNotEmpty || row.position.isNotEmpty ||
                      row.sets.isNotEmpty || row.weight.isNotEmpty) ...[
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        if (row.device.isNotEmpty)   _infoChip(row.device),
                        if (row.sets.isNotEmpty)      _infoChip(row.sets),
                        if (row.weight.isNotEmpty)    _infoChip(row.weight),
                        if (row.position.isNotEmpty)  _infoChip(row.position),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Timer chips
                  _buildTimerChips(meta, i, row),

                  const SizedBox(height: 8),
                  // Action buttons
                  _buildActionRow(key, meta, i, row, isLiked, isDisliked, commentCount),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseBadge(int i, String name, Color color, bool liked, bool disliked) {
    final activeColor = liked ? AppColors.green : disliked ? AppColors.red : color;
    final exerciseId = _exerciseIdMap[name];
    const double size = 100.0;
    const double radius = 12.0;

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
          errorBuilder: (_, __, ___) => _numberBadge(i, activeColor, size),
        ),
      );
    }
    return _numberBadge(i, activeColor, size);
  }

  Widget _numberBadge(int i, Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(46),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text('${i + 1}',
          style: GoogleFonts.inter(
              color: color, fontSize: 13, fontWeight: FontWeight.w800))),
    );
  }

  Widget _collapsedHints(TrainingPlanRow row, String key, int commentCount, Color accent) {
    final parts = <String>[
      if (row.timers.isNotEmpty) '⏱ ${row.timers.map(_fmtSec).join(', ')}',
      if (row.device.isNotEmpty) row.device,
      if (row.sets.isNotEmpty)   row.sets,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(parts.join(' · '),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11));
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: GoogleFonts.inter(color: AppColors.text, fontSize: 12)),
    );
  }

  // ─── Timer chips ─────────────────────────────────────────────────────────

  Widget _buildTimerChips(_SectionMeta meta, int i, TrainingPlanRow row) {
    // Use trainer-defined timers if available; otherwise show common presets
    final timerValues = row.timers.isNotEmpty ? row.timers : [30, 60, 90, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('TIMER',
              style: GoogleFonts.inter(
                  color: AppColors.muted, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          if (row.timers.isEmpty) ...[
            const SizedBox(width: 6),
            Text('(Vorschläge)',
                style: GoogleFonts.inter(
                    color: AppColors.muted.withAlpha(120), fontSize: 9,
                    letterSpacing: 0.5)),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: timerValues.map((secs) {
            final isActive = _timer.isCountdown &&
                _timer.activePrefix == meta.key &&
                _timer.activeIndex == i &&
                _timer.countdownFrom == secs;
            return GestureDetector(
              onTap: () => _timer.selectCountdown(
                prefix: meta.key, index: i,
                name: row.exercise.isEmpty ? 'Übung ${i + 1}' : row.exercise,
                seconds: secs,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? meta.color.withAlpha(46) : AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? meta.color : AppColors.border,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isActive)
                    Icon(Icons.play_arrow_rounded, size: 14, color: meta.color)
                  else
                    Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(_fmtSec(secs),
                      style: GoogleFonts.inter(
                          color: isActive ? meta.color : AppColors.muted,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Action row (like / dislike / comment) ────────────────────────────────

  Widget _buildActionRow(
    String key, _SectionMeta meta, int i, TrainingPlanRow row,
    bool isLiked, bool isDisliked, int commentCount,
  ) {
    return Row(children: [
      _actionChip(
        icon: isLiked ? Icons.favorite : Icons.favorite_border,
        label: 'Gefällt mir',
        active: isLiked,
        color: AppColors.green,
        onTap: () => _toggleLike(key, 'like'),
      ),
      const SizedBox(width: 8),
      _actionChip(
        icon: isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
        label: 'Passt nicht',
        active: isDisliked,
        color: AppColors.red,
        onTap: () => _toggleLike(key, 'dislike'),
      ),
      const SizedBox(width: 8),
      _actionChip(
        icon: Icons.chat_bubble_outline,
        label: commentCount > 0 ? '$commentCount' : 'Kommentar',
        active: commentCount > 0,
        color: meta.color,
        onTap: () => _openComments(key, row.exercise),
      ),
    ]);
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(36) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color.withAlpha(120) : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? color : AppColors.muted),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: active ? color : AppColors.muted,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ─── Comments Sheet ───────────────────────────────────────────────────────

  void _openComments(String exerciseKey, String exerciseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        planId: widget.planId,
        exerciseKey: exerciseKey,
        exerciseName: exerciseName,
        onClose: () {
          _loadCommentCounts().then((_) => setState(() {}));
        },
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _paywallRedirect(ClientTrainingPlan plan) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text(plan.name ?? 'Trainingsplan',
            style: GoogleFonts.inter(color: AppColors.text,
                fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, color: AppColors.orange, size: 48),
            const SizedBox(height: 16),
            Text('Dieser Plan ist gesperrt',
                style: GoogleFonts.inter(color: AppColors.text,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Schalte Online Coaching frei, um den Plan zu sehen.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => CoachingPaywallScreen(plan: plan))),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Freischalten'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _centered(IconData icon, Color color, String msg) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.text)),
      body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(height: 14),
          Text(msg, textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.muted, fontSize: 14)),
        ],
      ))),
    );
  }

  String _fmtSec(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60; final r = s % 60;
    return r == 0 ? '${m}min' : '$m:${r.toString().padLeft(2, '0')}';
  }
}

// ─── Comments Sheet ───────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final int planId;
  final String? exerciseKey;
  final String? exerciseName;
  final VoidCallback? onClose;

  const _CommentsSheet({
    required this.planId,
    this.exerciseKey,
    this.exerciseName,
    this.onClose,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  List<dynamic> _comments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    widget.onClose?.call();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ek = widget.exerciseKey;
      final path = ek != null
          ? 'api/training-plan/${widget.planId}/comments?exerciseKey=$ek'
          : 'api/training-plan/${widget.planId}/comments';
      final data = await apiClient.get(path);
      if (!mounted) return;
      setState(() { _comments = data is List ? data : []; _loading = false; });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await apiClient.post(
        'api/training-plan/${widget.planId}/comments',
        body: {
          'text': text,
          if (widget.exerciseKey != null) 'exerciseKey': widget.exerciseKey,
        },
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fehler: $e'),
        backgroundColor: AppColors.red,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(int commentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Kommentar löschen?',
            style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiClient.delete('api/training-plan/comments/$commentId');
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(widget.exerciseName != null
              ? 'Kommentare · ${widget.exerciseName}'
              : 'Plan-Kommentare',
              style: GoogleFonts.inter(color: AppColors.text,
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _comments.isEmpty
              ? Center(child: Text('Noch keine Kommentare',
                  style: GoogleFonts.inter(color: AppColors.muted)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _comments.length,
                  itemBuilder: (context, i) => _commentBubble(_comments[i]),
                ),
        ),
        // Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 3, minLines: 1,
                style: GoogleFonts.inter(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Kommentar schreiben…',
                  hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 14),
                  filled: true, fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: _sending
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _commentBubble(dynamic comment) {
    final author = comment['authorName'] ?? comment['author_name'] ?? '?';
    final text   = comment['text'] ?? '';
    final id     = comment['id'];
    final isClient = comment['senderType'] == 'client' || comment['sender_type'] == 'client';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: (isClient ? AppColors.primary : AppColors.blue).withAlpha(46),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              author.isNotEmpty ? author[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                  color: isClient ? AppColors.primary : AppColors.blue,
                  fontSize: 13, fontWeight: FontWeight.w700),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(author,
                      style: GoogleFonts.inter(color: AppColors.text,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  if (isClient) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(36),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('Du', style: GoogleFonts.inter(
                          color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  if (id != null && isClient)
                    GestureDetector(
                      onTap: () => _delete(id as int),
                      child: const Icon(Icons.close, size: 14, color: AppColors.muted),
                    ),
                ]),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12), bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(text,
                      style: GoogleFonts.inter(color: AppColors.text, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
