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
  bool _generatingAi = false;
  String _aiStep = '';
  int _aiStepIndex = 0;
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

  static const _aiSteps = [
    'Kundendaten laden …',
    'Leistungstest analysieren …',
    'Körperzusammensetzung prüfen …',
    'Trainingshistorie auswerten …',
    'Schwächen identifizieren …',
    'KI erstellt Trainingsplan …',
  ];

  void _advanceAiSteps() async {
    for (var i = 0; i < _aiSteps.length; i++) {
      if (!_generatingAi || !mounted) return;
      setState(() {
        _aiStepIndex = i;
        _aiStep = _aiSteps[i];
      });
      // Stagger the steps: first ones quick, last one long (waiting for AI)
      await Future.delayed(Duration(milliseconds: i < 4 ? 1200 : 2500));
    }
  }

  // ── AI Config types ──────────────────────────────────────────────────────
  static const _trainingTypes = <String, Map<String, dynamic>>{
    'ausdauer':       {'label': 'Ausdauer',       'icon': Icons.directions_run},
    'kraft':          {'label': 'Kraft',           'icon': Icons.fitness_center},
    'propriozeptiv':  {'label': 'Propriozeptiv',   'icon': Icons.self_improvement},
    'mental_health':  {'label': 'Mental Health',   'icon': Icons.spa},
    'athletik':       {'label': 'Athletik',        'icon': Icons.sports_gymnastics},
    'schnelligkeit':  {'label': 'Schnelligkeit',   'icon': Icons.bolt},
  };

  static const _durations = <int?, String>{
    30:   '30 min',
    45:   '45 min',
    60:   '60 min',
    null: 'Frei',
  };

  static const _equipmentOptions = <String, Map<String, dynamic>>{
    'mft':        {'label': 'MFT Board',   'icon': Icons.circle_outlined},
    'slackline':  {'label': 'Slackline',   'icon': Icons.linear_scale},
    'springseil': {'label': 'Springseil',  'icon': Icons.cable},
  };

  /// Shows the AI config bottom sheet, returns the selected config or null if cancelled.
  Future<Map<String, dynamic>?> _showAiConfigSheet() async {
    String? selectedType;
    int? selectedDuration; // null = not explicitly set yet
    bool durationIsFrei = false;
    final selectedEquipment = <String>{};
    bool equipmentIsFrei = false;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final canGenerate = selectedType != null &&
              (selectedDuration != null || durationIsFrei);

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAB47BC).withAlpha(30),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFAB47BC), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Neuer KI-Trainingsplan',
                            style: GoogleFonts.montserrat(
                                color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(widget.client.name,
                            style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Training Type ──
                Text('TRAINING TYP',
                    style: GoogleFonts.openSans(
                        color: AppColors.muted, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _trainingTypes.entries.map((e) {
                    final isSelected = selectedType == e.key;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedType = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFAB47BC).withAlpha(25)
                              : AppColors.surface2.withAlpha(120),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFAB47BC)
                                : AppColors.border.withAlpha(60),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(e.value['icon'] as IconData,
                                size: 16,
                                color: isSelected ? const Color(0xFFAB47BC) : AppColors.muted),
                            const SizedBox(width: 6),
                            Text(e.value['label'] as String,
                                style: GoogleFonts.openSans(
                                    color: isSelected ? const Color(0xFFAB47BC) : AppColors.text,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Duration ──
                Text('DAUER',
                    style: GoogleFonts.openSans(
                        color: AppColors.muted, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Row(
                  children: _durations.entries.map((e) {
                    final isFrei = e.key == null;
                    final isSelected = isFrei ? durationIsFrei : (!durationIsFrei && selectedDuration == e.key);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setModalState(() {
                            if (isFrei) {
                              durationIsFrei = true;
                              selectedDuration = null;
                            } else {
                              durationIsFrei = false;
                              selectedDuration = e.key;
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFAB47BC).withAlpha(25)
                                  : AppColors.surface2.withAlpha(120),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFAB47BC)
                                    : AppColors.border.withAlpha(60),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(e.value,
                                style: GoogleFonts.openSans(
                                    color: isSelected ? const Color(0xFFAB47BC) : AppColors.text,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Equipment ──
                Text('GERÄTE',
                    style: GoogleFonts.openSans(
                        color: AppColors.muted, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    ..._equipmentOptions.entries.map((e) {
                      final isSelected = selectedEquipment.contains(e.key);
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          equipmentIsFrei = false;
                          if (isSelected) {
                            selectedEquipment.remove(e.key);
                          } else {
                            selectedEquipment.add(e.key);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFAB47BC).withAlpha(25)
                                : AppColors.surface2.withAlpha(120),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFAB47BC)
                                  : AppColors.border.withAlpha(60),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 16,
                                color: isSelected ? const Color(0xFFAB47BC) : AppColors.muted),
                              const SizedBox(width: 6),
                              Text(e.value['label'] as String,
                                  style: GoogleFonts.openSans(
                                      color: isSelected ? const Color(0xFFAB47BC) : AppColors.text,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    }),
                    // "Frei" option
                    GestureDetector(
                      onTap: () => setModalState(() {
                        equipmentIsFrei = !equipmentIsFrei;
                        if (equipmentIsFrei) selectedEquipment.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: equipmentIsFrei
                              ? const Color(0xFFAB47BC).withAlpha(25)
                              : AppColors.surface2.withAlpha(120),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: equipmentIsFrei
                                ? const Color(0xFFAB47BC)
                                : AppColors.border.withAlpha(60),
                            width: equipmentIsFrei ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16,
                                color: equipmentIsFrei ? const Color(0xFFAB47BC) : AppColors.muted),
                            const SizedBox(width: 6),
                            Text('Frei (KI wählt)',
                                style: GoogleFonts.openSans(
                                    color: equipmentIsFrei ? const Color(0xFFAB47BC) : AppColors.text,
                                    fontSize: 13,
                                    fontWeight: equipmentIsFrei ? FontWeight.w700 : FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Generate button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canGenerate
                        ? () {
                            Navigator.pop(ctx, {
                              'trainingType': selectedType,
                              'duration': durationIsFrei ? null : selectedDuration,
                              'equipment': equipmentIsFrei || selectedEquipment.isEmpty
                                  ? null
                                  : selectedEquipment.toList(),
                            });
                          }
                        : null,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Plan generieren'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAB47BC),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surface2,
                      disabledForegroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateAiPlan() async {
    // Step 1: Show config sheet
    final config = await _showAiConfigSheet();
    if (config == null || !mounted) return; // cancelled

    // Step 2: Start generation with loading overlay
    setState(() {
      _generatingAi = true;
      _aiStepIndex = 0;
      _aiStep = _aiSteps[0];
    });
    _advanceAiSteps();
    try {
      final result = await _api.post(
        '${ApiConfig.trainingPlan}/ai/recommend/${widget.client.id}',
        body: config,
      );
      if (!mounted) return;
      if (result is Map<String, dynamic>) {
        setState(() => _generatingAi = false);
        await _showAiPreview(result);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generatingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('KI-Generierung fehlgeschlagen: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _showAiPreview(Map<String, dynamic> result) async {
    final reasoning = result['ai_reasoning'] as String? ?? '';
    final planName = result['name'] as String? ?? 'KI-Plan';
    final weaknesses = result['weaknesses'] as List<dynamic>? ?? [];
    final contraindications = result['contraindications'] as List<dynamic>? ?? [];
    final sonsomo = result['sonsomo'] as List<dynamic>? ?? [];
    final main = result['main'] as List<dynamic>? ?? [];
    final core = result['core'] as List<dynamic>? ?? [];
    final mobility = result['mobility'] as List<dynamic>? ?? [];
    final totalExercises = sonsomo.length + main.length + core.length + mobility.length;
    final isRuleBased = result['isRuleBased'] == true;
    final requestEcho = result['request'] as Map<String, dynamic>?;

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB47BC).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFFAB47BC), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KI-Empfehlung',
                        style: GoogleFonts.montserrat(
                            color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('$totalExercises Übungen · $planName',
                        style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ]),

            // ── Request config chips ──
            if (requestEcho != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  if (requestEcho['trainingType'] != null)
                    _buildConfigChip(
                      _trainingTypes[requestEcho['trainingType']]?['label'] as String? ?? requestEcho['trainingType'].toString(),
                      _trainingTypes[requestEcho['trainingType']]?['icon'] as IconData? ?? Icons.sports,
                    ),
                  if (requestEcho['duration'] != null)
                    _buildConfigChip('${requestEcho['duration']} min', Icons.timer_outlined),
                  if (requestEcho['duration'] == null)
                    _buildConfigChip('Dauer: Frei', Icons.timer_outlined),
                  if (requestEcho['equipment'] is List)
                    ...((requestEcho['equipment'] as List).map<Widget>((e) =>
                      _buildConfigChip(
                        _equipmentOptions[e.toString()]?['label'] as String? ?? e.toString(),
                        _equipmentOptions[e.toString()]?['icon'] as IconData? ?? Icons.build,
                      ),
                    )),
                  if (requestEcho['equipment'] == null)
                    _buildConfigChip('Geräte: Frei', Icons.auto_awesome),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Rule-based fallback warning
            if (isRuleBased) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Regelbasierter Plan',
                              style: GoogleFonts.openSans(
                                  color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Die KI war nicht erreichbar. Dieser Plan wurde automatisch nach Regeln erstellt und sollte besonders sorgfältig geprüft werden.',
                              style: GoogleFonts.openSans(
                                  color: AppColors.text, fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // AI Reasoning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFAB47BC).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFAB47BC).withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.psychology_outlined, size: 16, color: Color(0xFFAB47BC)),
                    const SizedBox(width: 6),
                    Text('Begründung',
                        style: GoogleFonts.openSans(
                            color: const Color(0xFFAB47BC), fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text(reasoning,
                      style: GoogleFonts.openSans(
                          color: AppColors.text, fontSize: 13, height: 1.5)),
                ],
              ),
            ),

            // Weaknesses
            if (weaknesses.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('IDENTIFIZIERTE SCHWÄCHEN',
                  style: GoogleFonts.openSans(
                      color: AppColors.muted, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: weaknesses.map<Widget>((w) {
                  final m = w as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.red.withAlpha(60)),
                    ),
                    child: Text(
                      '${m['label']} (−${m['deficit']}%)',
                      style: GoogleFonts.openSans(
                          color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Contraindications
            if (contraindications.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('BEACHTETE KONTRAINDIKATIONEN',
                  style: GoogleFonts.openSans(
                      color: AppColors.muted, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: contraindications.map<Widget>((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.orange.withAlpha(60)),
                    ),
                    child: Text(
                      c.toString(),
                      style: GoogleFonts.openSans(
                          color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Exercise sections
            const SizedBox(height: 20),
            _buildAiSection('Aufwärmen / Sonsomo', sonsomo, AppColors.primary),
            _buildAiSection('Haupttraining', main, AppColors.blue),
            _buildAiSection('Core', core, AppColors.green),
            _buildAiSection('Mobilität', mobility, AppColors.orange),

            const SizedBox(height: 24),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Verwerfen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Übernehmen & Bearbeiten'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (accepted == true && mounted) {
      // Convert AI result to TrainingPlan and open editor
      final plan = _aiResultToPlan(result);
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TrainingPlanDetailScreen(client: widget.client, plan: plan),
        ),
      );
      if (saved == true) _load();
    }
  }

  Widget _buildAiSection(String title, List<dynamic> exercises, Color color) {
    if (exercises.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(children: [
            Container(
              width: 4, height: 16,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.openSans(
                    color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${exercises.length}',
                style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        ...exercises.map<Widget>((e) {
          final m = e as Map<String, dynamic>;
          final isNew = m['isNew'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
              border: isNew
                  ? Border.all(color: AppColors.orange.withAlpha(60))
                  : null,
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(m['exercise']?.toString() ?? '',
                            style: GoogleFonts.openSans(
                                color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('NEU', style: GoogleFonts.openSans(
                              color: AppColors.orange, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                    if ((m['device']?.toString() ?? '').isNotEmpty ||
                        (m['position']?.toString() ?? '').isNotEmpty ||
                        (m['sets']?.toString() ?? '').isNotEmpty)
                      Text(
                        [m['device'], m['position'], m['sets']]
                            .where((s) => s != null && s.toString().isNotEmpty)
                            .join(' · '),
                        style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if ((m['weight']?.toString() ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(m['weight'].toString(),
                      style: GoogleFonts.openSans(
                          color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildConfigChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFAB47BC).withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFAB47BC).withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFAB47BC)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.openSans(
                  color: const Color(0xFFAB47BC), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  TrainingPlan _aiResultToPlan(Map<String, dynamic> result) {
    List<TrainingPlanRow> mapRows(List<dynamic> rows) {
      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        return TrainingPlanRow(
          exercise: m['exercise']?.toString() ?? '',
          device: m['device']?.toString() ?? '',
          position: m['position']?.toString() ?? '',
          weight: m['weight']?.toString() ?? '',
          sets: m['sets']?.toString() ?? '',
        );
      }).toList();
    }

    return TrainingPlan(
      clientId: widget.client.id,
      name: result['name']?.toString() ?? 'KI-Plan',
      values: TrainingPlanValues(
        sonsomo: mapRows(result['sonsomo'] as List<dynamic>? ?? []),
        main: mapRows(result['main'] as List<dynamic>? ?? []),
        core: mapRows(result['core'] as List<dynamic>? ?? []),
        mobility: mapRows(result['mobility'] as List<dynamic>? ?? []),
      ),
    );
  }

  Future<void> _deletePlan(TrainingPlan plan) async {
    final name = plan.name?.isNotEmpty == true ? plan.name! : 'Diesen Plan';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Plan löschen?',
            style: GoogleFonts.montserrat(
                color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text('„$name" wird unwiderruflich gelöscht.',
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
    if (confirmed != true || plan.id == null) return;
    try {
      await _api.delete('${ApiConfig.trainingPlan}/${plan.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('„$name" gelöscht'),
          backgroundColor: const Color(0xFF2E7D32),
        ));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    }
  }

  int _countExercises(TrainingPlan p) =>
      p.values.sonsomo.where((r) => r.exercise.isNotEmpty).length +
      p.values.main.where((r) => r.exercise.isNotEmpty).length +
      p.values.core.where((r) => r.exercise.isNotEmpty).length +
      p.values.mobility.where((r) => r.exercise.isNotEmpty).length;

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
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_generatingAi) _buildAiOverlay(),
        ],
      ),
      floatingActionButton: _generatingAi
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI-Plan button
                FloatingActionButton.small(
                  heroTag: 'ai',
                  onPressed: _generateAiPlan,
                  backgroundColor: const Color(0xFF1E2740),
                  foregroundColor: const Color(0xFFAB47BC),
                  tooltip: 'KI-Plan erstellen',
                  child: const Icon(Icons.auto_awesome, size: 20),
                ),
                const SizedBox(height: 10),
                // Manual plan button
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: () => _open(null),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  tooltip: 'Neuer Plan',
                  child: const Icon(Icons.add),
                ),
              ],
            ),
    );
  }

  Widget _buildAiOverlay() {
    final progress = (_aiStepIndex + 1) / _aiSteps.length;
    return AnimatedOpacity(
      opacity: _generatingAi ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI icon with glow
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E2740),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB47BC).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Color(0xFFAB47BC), size: 36),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'KI-Trainingsplan',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.client.name,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFAB47BC)),
                  ),
                ),
                const SizedBox(height: 16),
                // Step list
                ...List.generate(_aiSteps.length, (i) {
                  final done = i < _aiStepIndex;
                  final active = i == _aiStepIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20, height: 20,
                          child: done
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFFAB47BC), size: 18)
                              : active
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFAB47BC),
                                      ),
                                    )
                                  : Icon(Icons.circle_outlined,
                                      color: Colors.white24, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _aiSteps[i].replaceAll(' …', ''),
                          style: GoogleFonts.inter(
                            color: done
                                ? Colors.white70
                                : active
                                    ? Colors.white
                                    : Colors.white30,
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
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
              color: AppColors.muted.withAlpha(153), fontSize: 13),
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

    return Dismissible(
      key: ValueKey(plan.id ?? index),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deletePlan(plan);
        return false; // We handle removal ourselves via _load()
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.red.withAlpha(30),
        child: const Icon(Icons.delete_outline, color: AppColors.red, size: 24),
      ),
      child: InkWell(
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
                color: accent.withAlpha(46),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: accent.withAlpha(77), width: 0.5),
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
                            color: AppColors.muted.withAlpha(179)),
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
                                color: AppColors.muted.withAlpha(128),
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
    ),
    );
  }
}
