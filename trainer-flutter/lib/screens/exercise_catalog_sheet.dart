import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

/// Result returned when user selects or creates an exercise.
class ExerciseSelection {
  final String name;
  final String device;
  final String? bodyRegion;

  const ExerciseSelection({
    required this.name,
    this.device = '',
    this.bodyRegion,
  });
}

/// Bottom sheet for browsing, filtering, and creating exercises.
///
/// Usage:
/// ```dart
/// final result = await ExerciseCatalogSheet.show(context);
/// if (result != null) { /* use result.name, result.device */ }
/// ```
class ExerciseCatalogSheet extends StatefulWidget {
  const ExerciseCatalogSheet({super.key});

  static Future<ExerciseSelection?> show(BuildContext context) {
    return showModalBottomSheet<ExerciseSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExerciseCatalogSheet(),
    );
  }

  @override
  State<ExerciseCatalogSheet> createState() => _ExerciseCatalogSheetState();
}

class _ExerciseCatalogSheetState extends State<ExerciseCatalogSheet> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Exercise> _all = [];
  List<ExerciseGroup> _groups = [];
  String _query = '';

  // Filters
  String? _filterBodyRegion;
  int? _filterGroupId;
  List<Exercise>? _filteredCache;

  // Create mode
  bool _showCreateForm = false;
  final _newNameCtrl = TextEditingController();
  String? _newBodyRegion;
  int? _newGroupId;
  bool _creating = false;

  // AI verify state
  bool _verifying = false;
  Map<String, dynamic>? _verifyResult;  // null = not verified yet

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() { _query = _searchCtrl.text; _filteredCache = null; }));
    _newNameCtrl.addListener(() {
      if (_verifyResult != null || _verifying) {
        setState(() { _verifyResult = null; _verifying = false; });
      } else {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _newNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.get(ApiConfig.exercise),
        _api.get(ApiConfig.exerciseGroups),
      ]);

      // Parse exercises
      final exList = results[0] is List ? results[0] as List : [];
      _all = exList
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .where((e) => e.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Parse groups
      final grList = results[1] is List ? results[1] as List : [];
      _groups = grList
          .map((g) => ExerciseGroup.fromJson(g as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() { _loading = false; _filteredCache = null; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; _filteredCache = null; });
    } catch (e) {
      setState(() { _error = 'Fehler beim Laden'; _loading = false; });
    }
  }

  List<Exercise> get _filtered {
    if (_filteredCache != null) return _filteredCache!;
    var list = _all;
    if (_filterBodyRegion != null) {
      list = list.where((e) => e.bodyRegion == _filterBodyRegion).toList();
    }
    if (_filterGroupId != null) {
      list = list.where((e) => e.groupId == _filterGroupId).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((e) {
        return e.name.toLowerCase().contains(q) ||
            (e.group?.name.toLowerCase().contains(q) ?? false) ||
            (e.subgroupName?.toLowerCase().contains(q) ?? false) ||
            (e.primaryMuscleGroup?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    _filteredCache = list;
    return list;
  }

  void _select(Exercise ex) {
    Navigator.pop(context, ExerciseSelection(
      name: ex.name,
      device: ex.group?.name ?? '',
      bodyRegion: ex.bodyRegion,
    ));
  }

  Future<void> _verifyExercise() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name muss mindestens 2 Zeichen haben'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    setState(() { _verifying = true; _verifyResult = null; });
    try {
      final groupName = _newGroupId != null
          ? _groups.where((g) => g.id == _newGroupId).firstOrNull?.name
          : null;
      final result = await _api.post('${ApiConfig.exercise}/verify', body: {
        'name': name,
        if (groupName != null) 'groupName': groupName,
        if (_newBodyRegion != null) 'bodyRegion': _newBodyRegion,
      });
      if (mounted) {
        setState(() {
          _verifyResult = result is Map<String, dynamic> ? result : {};
          // Auto-apply AI-suggested bodyRegion/movementPattern if user hasn't set one
          final suggestedRegion = _verifyResult?['bodyRegion'];
          if (_newBodyRegion == null && suggestedRegion is String && suggestedRegion.isNotEmpty) {
            _newBodyRegion = suggestedRegion;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _verifyResult = {
          'valid': true,
          'correctedName': name,
          'corrections': <dynamic>[],
          'confidence': 0.5,
          'summary': 'Prüfung fehlgeschlagen: ${e.message}',
        });
      }
    } catch (e) {
      // Network timeout or unexpected error
      if (mounted) {
        setState(() => _verifyResult = {
          'valid': true,
          'correctedName': name,
          'corrections': <dynamic>[],
          'confidence': 0.5,
          'summary': 'Verbindungsfehler – Name wird ungeprüft übernommen.',
        });
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _createExercise({String? overrideName}) async {
    final name = (overrideName ?? _newNameCtrl.text).trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'archive': 0,
        'published': 0,
        'groupId': _newGroupId,
        if (_newBodyRegion != null) 'bodyRegion': _newBodyRegion,
      };
      await _api.post(ApiConfig.exercise, body: body);
      if (mounted) {
        final groupName = _newGroupId != null
            ? _groups.where((g) => g.id == _newGroupId).firstOrNull?.name ?? ''
            : '';
        Navigator.pop(context, ExerciseSelection(
          name: name,
          device: groupName,
          bodyRegion: _newBodyRegion,
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  _showCreateForm ? 'Neue Übung erstellen' : 'Übungskatalog',
                  style: GoogleFonts.montserrat(
                    color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_showCreateForm)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.muted, size: 20),
                    onPressed: () => setState(() {
                      _showCreateForm = false;
                      _verifyResult = null;
                      _verifying = false;
                    }),
                  ),
                if (!_showCreateForm)
                  Text(
                    _filterBodyRegion != null || _filterGroupId != null || _query.isNotEmpty
                        ? '${_filtered.length} von ${_all.length}'
                        : '${_all.length} Übungen',
                    style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_showCreateForm)
            Expanded(child: _buildCreateForm())
          else
            Expanded(child: _buildCatalogView(scrollCtrl)),
        ],
      ),
    );
  }

  // ─── Catalog view ─────────────────────────────────────────────────────

  Widget _buildCatalogView(ScrollController scrollCtrl) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.openSans(color: AppColors.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Übung suchen…',
              hintStyle: GoogleFonts.openSans(color: AppColors.muted.withAlpha(153), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AppColors.muted, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildFilterChip(
                label: _filterBodyRegion != null
                    ? Exercise.bodyRegionLabels[_filterBodyRegion] ?? _filterBodyRegion!
                    : 'Körperregion',
                isActive: _filterBodyRegion != null,
                onTap: _showBodyRegionFilter,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: _filterGroupId != null
                    ? _groups.where((g) => g.id == _filterGroupId).firstOrNull?.name ?? 'Gruppe'
                    : 'Gruppe',
                isActive: _filterGroupId != null,
                onTap: _showGroupFilter,
              ),
              if (_filterBodyRegion != null || _filterGroupId != null) ...[
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Filter zurücksetzen',
                  isActive: false,
                  icon: Icons.close,
                  onTap: () => setState(() {
                    _filterBodyRegion = null;
                    _filterGroupId = null;
                    _filteredCache = null;
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.border, height: 1),

        // Results
        Expanded(child: _buildResults(scrollCtrl)),
      ],
    );
  }

  Widget _buildResults(ScrollController scrollCtrl) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.openSans(color: AppColors.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }

    final items = _filtered;

    if (items.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.search_off, color: AppColors.muted.withAlpha(100), size: 48),
          const SizedBox(height: 12),
          Text(
            'Keine Übungen gefunden',
            style: GoogleFonts.montserrat(
              color: AppColors.muted, fontSize: 15, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _query.isNotEmpty
                ? 'Versuch einen anderen Suchbegriff'
                : 'Ändere die Filtereinstellungen',
            style: GoogleFonts.openSans(color: AppColors.muted.withAlpha(153), fontSize: 12),
          ),
          const SizedBox(height: 20),
          _buildCreateButton(),
        ],
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      itemCount: items.length + 1, // +1 for "create new" button
      itemBuilder: (ctx, i) {
        if (i == items.length) return _buildCreateButton();
        return _buildExerciseRow(items[i]);
      },
    );
  }

  Widget _buildExerciseRow(Exercise ex) {
    return InkWell(
      onTap: () => _select(ex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Body region icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _regionColor(ex.bodyRegion).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _regionIcon(ex.bodyRegion),
                color: _regionColor(ex.bodyRegion),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.name,
                    style: GoogleFonts.openSans(
                      color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      ex.group?.name,
                      ex.bodyRegionLabel,
                      ex.movementPattern,
                    ].where((s) => s != null && s.isNotEmpty).join(' · '),
                    style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: GestureDetector(
        onTap: () => setState(() => _showCreateForm = true),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withAlpha(77), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.primary.withAlpha(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary.withAlpha(204)),
              const SizedBox(width: 8),
              Text(
                'Neue Übung erstellen',
                style: GoogleFonts.openSans(
                  color: AppColors.primary.withAlpha(204),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Create form ──────────────────────────────────────────────────────

  Widget _buildCreateForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Name
        Text('ÜBUNGSNAME',
            style: GoogleFonts.openSans(
                color: AppColors.muted, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextField(
          controller: _newNameCtrl,
          autofocus: true,
          style: GoogleFonts.openSans(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'z.B. Front Wipp',
            hintStyle: GoogleFonts.openSans(color: AppColors.muted.withAlpha(102), fontSize: 16),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),

        // Group
        Text('GRUPPE',
            style: GoogleFonts.openSans(
                color: AppColors.muted, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _groups.map((g) => _SelectChip(
            label: g.name,
            isActive: _newGroupId == g.id,
            onTap: () => setState(() => _newGroupId = _newGroupId == g.id ? null : g.id),
          )).toList(),
        ),
        const SizedBox(height: 20),

        // Body region
        Text('KÖRPERREGION',
            style: GoogleFonts.openSans(
                color: AppColors.muted, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: Exercise.bodyRegions.map((r) => _SelectChip(
            label: Exercise.bodyRegionLabels[r] ?? r,
            isActive: _newBodyRegion == r,
            onTap: () => setState(() => _newBodyRegion = _newBodyRegion == r ? null : r),
          )).toList(),
        ),
        const SizedBox(height: 28),

        // ── AI Verify → Create (2-step) ─────────────────────────
        if (_verifyResult == null && !_verifying)
          // Step 1: Show "KI Prüfung starten" button
          ElevatedButton.icon(
            onPressed: _newNameCtrl.text.trim().length < 2 ? null : _verifyExercise,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text('KI Prüfung starten',
                style: GoogleFonts.openSans(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

        if (_verifying)
          // Step 1b: Loading state
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.blue),
              ),
              const SizedBox(height: 12),
              Text('KI prüft Übung…',
                  style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13)),
            ]),
          ),

        if (_verifyResult != null) ...[
          // Step 2: AI result card
          _buildVerifyResultCard(),
          const SizedBox(height: 16),
          // Action buttons
          ..._buildVerifyActions(),
        ],
      ],
    );
  }

  // ─── AI Verify result UI ───────────────────────────────────────────────

  Widget _buildVerifyResultCard() {
    final result = _verifyResult!;
    final corrections = (result['corrections'] as List<dynamic>?) ?? [];
    final correctedName = result['correctedName'] as String? ?? _newNameCtrl.text.trim();
    final summary = result['summary'] as String? ?? '';
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final valid = result['valid'] as bool? ?? true;
    final nameChanged = correctedName != _newNameCtrl.text.trim();
    final hasDuplicate = corrections.any((c) => c['type'] == 'duplicate');

    final statusColor = !valid
        ? AppColors.red
        : hasDuplicate
            ? AppColors.orange
            : corrections.isNotEmpty
                ? AppColors.orange
                : AppColors.green;
    final statusIcon = !valid
        ? Icons.cancel_outlined
        : hasDuplicate
            ? Icons.warning_amber_rounded
            : corrections.isNotEmpty
                ? Icons.auto_fix_high
                : Icons.check_circle_outline;
    final statusLabel = !valid
        ? 'Keine gültige Übung'
        : hasDuplicate
            ? 'Duplikat gefunden'
            : corrections.isNotEmpty
                ? 'Korrektur vorgeschlagen'
                : 'Name korrekt';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(statusLabel,
                  style: GoogleFonts.montserrat(
                      color: statusColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${(confidence * 100).round()}%',
                  style: GoogleFonts.openSans(
                      color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),

          // Summary
          if (summary.isNotEmpty)
            Text(summary,
                style: GoogleFonts.openSans(color: AppColors.text, fontSize: 13, height: 1.4)),

          // Corrected name highlight
          if (nameChanged) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.arrow_forward, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(text: TextSpan(
                    style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 13),
                    children: [
                    TextSpan(
                      text: _newNameCtrl.text.trim(),
                      style: GoogleFonts.openSans(
                          color: AppColors.muted, fontSize: 13,
                          decoration: TextDecoration.lineThrough),
                    ),
                    const TextSpan(text: '  →  '),
                    TextSpan(
                      text: correctedName,
                      style: GoogleFonts.openSans(
                          color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ])),
                ),
              ]),
            ),
          ],

          // Corrections list
          if (corrections.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...corrections.map<Widget>((c) {
              final type = c['type'] as String? ?? '';
              final explanation = c['explanation'] as String? ?? '';
              final icon = type == 'duplicate'
                  ? Icons.copy
                  : type == 'spelling'
                      ? Icons.spellcheck
                      : type == 'format'
                          ? Icons.text_format
                          : Icons.info_outline;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 14, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(explanation,
                          style: GoogleFonts.openSans(
                              color: AppColors.muted, fontSize: 12, height: 1.3)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildVerifyActions() {
    final result = _verifyResult!;
    final correctedName = result['correctedName'] as String? ?? _newNameCtrl.text.trim();
    final valid = result['valid'] as bool? ?? true;
    final nameChanged = correctedName != _newNameCtrl.text.trim();
    final hasDuplicate = (result['corrections'] as List<dynamic>? ?? [])
        .any((c) => c['type'] == 'duplicate');

    final widgets = <Widget>[];

    // Primary action: accept correction & create (or just create if name unchanged)
    if (valid && !hasDuplicate) {
      if (nameChanged) {
        // "Accept corrected name & create"
        widgets.add(
          ElevatedButton.icon(
            onPressed: _creating ? null : () => _createExercise(overrideName: correctedName),
            icon: _creating
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_creating ? 'Erstellen…' : 'Korrektur übernehmen & Erstellen',
                style: GoogleFonts.openSans(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        // Secondary: "Create with original name anyway"
        widgets.add(
          OutlinedButton.icon(
            onPressed: _creating ? null : () => _createExercise(),
            icon: const Icon(Icons.edit_note, size: 18),
            label: Text('Trotzdem mit Originalname erstellen',
                style: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      } else {
        // Name is correct — just create
        widgets.add(
          ElevatedButton.icon(
            onPressed: _creating ? null : () => _createExercise(),
            icon: _creating
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_creating ? 'Erstellen…' : 'Erstellen & Übernehmen',
                style: GoogleFonts.openSans(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      }
    } else if (hasDuplicate) {
      // Duplicate — warn but allow creation
      widgets.add(
        OutlinedButton.icon(
          onPressed: _creating ? null : () => _createExercise(),
          icon: const Icon(Icons.warning_amber_rounded, size: 18),
          label: Text('Trotzdem erstellen (Duplikat)',
              style: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.orange,
            side: const BorderSide(color: AppColors.orange),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else if (!valid) {
      // AI says invalid — still allow override (trainer may know better)
      widgets.add(
        OutlinedButton.icon(
          onPressed: _creating ? null : () => _createExercise(),
          icon: const Icon(Icons.warning_amber_rounded, size: 18),
          label: Text('Trotzdem erstellen',
              style: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    // Always: "Re-check" / edit name button
    widgets.add(const SizedBox(height: 8));
    widgets.add(
      TextButton.icon(
        onPressed: () => setState(() => _verifyResult = null),
        icon: const Icon(Icons.refresh, size: 16),
        label: Text('Name ändern & erneut prüfen',
            style: GoogleFonts.openSans(fontSize: 12)),
        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
      ),
    );

    return widgets;
  }

  // ─── Filter dialogs ───────────────────────────────────────────────────

  void _showBodyRegionFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Körperregion',
                style: GoogleFonts.montserrat(
                    color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...Exercise.bodyRegions.map((r) => ListTile(
              leading: Icon(_regionIcon(r), color: _regionColor(r), size: 22),
              title: Text(Exercise.bodyRegionLabels[r] ?? r,
                  style: GoogleFonts.openSans(color: AppColors.text, fontSize: 14)),
              trailing: _filterBodyRegion == r
                  ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                  : null,
              onTap: () {
                setState(() { _filterBodyRegion = _filterBodyRegion == r ? null : r; _filteredCache = null; });
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGroupFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Gruppe',
                  style: GoogleFonts.montserrat(
                      color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (_, i) {
                  final g = _groups[i];
                  return ListTile(
                    title: Text(g.name,
                        style: GoogleFonts.openSans(color: AppColors.text, fontSize: 14)),
                    trailing: _filterGroupId == g.id
                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      setState(() { _filterGroupId = _filterGroupId == g.id ? null : g.id; _filteredCache = null; });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(26) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary.withAlpha(128) : AppColors.border,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: GoogleFonts.openSans(
                  color: isActive ? AppColors.primary : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (!isActive && icon == null) ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16,
                color: AppColors.muted.withAlpha(153)),
          ],
        ]),
      ),
    );
  }

  Color _regionColor(String? region) {
    switch (region) {
      case 'UpperBody': return AppColors.blue;
      case 'LowerBody': return AppColors.orange;
      case 'Core': return AppColors.green;
      case 'FullBody': return AppColors.primary;
      case 'Foot': return const Color(0xFFAB47BC);
      default: return AppColors.muted;
    }
  }

  IconData _regionIcon(String? region) {
    switch (region) {
      case 'UpperBody': return Icons.fitness_center;
      case 'LowerBody': return Icons.directions_run;
      case 'Core': return Icons.self_improvement;
      case 'FullBody': return Icons.accessibility_new;
      case 'Foot': return Icons.do_not_step;
      default: return Icons.circle_outlined;
    }
  }
}

// ─── Reusable select chip ────────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(26) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary.withAlpha(128) : AppColors.border,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.openSans(
                color: isActive ? AppColors.primary : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
