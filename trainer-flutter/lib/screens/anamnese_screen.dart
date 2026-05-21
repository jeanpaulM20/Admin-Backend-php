import 'package:flutter/material.dart';
import '../models/anamnese.dart';
import '../models/client.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class AnamneseScreen extends StatefulWidget {
  final Client client;

  const AnamneseScreen({super.key, required this.client});

  @override
  State<AnamneseScreen> createState() => _AnamneseScreenState();
}

class _AnamneseScreenState extends State<AnamneseScreen> {
  final _apiService = ApiService();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Anamnese? _anamnese;

  final _professionCtrl = TextEditingController();
  final _sportartsCtrl = TextEditingController();
  final _sleepWeekCtrl = TextEditingController();
  final _sleepWeekendCtrl = TextEditingController();

  // Enum fields (INT in DB) — stored as state, not TextControllers
  int? _activities;         // 0-2
  int? _physicalDemands;    // 0-4
  int? _sportartsIntensity; // 0-2

  static const _activitiesOptions = <int, String>{
    0: 'Sitzend (Büro, Studium)',
    1: 'Mässige Bewegung (Handwerk)',
    2: 'Intensive Bewegung (Bau, Wald)',
  };

  static const _physicalDemandsOptions = <int, String>{
    0: '< 30 Min. / Woche',
    1: '≥ 30 Min. / Tag leicht aktiv',
    2: '< 2.5 Std. / Woche moderat',
    3: '≥ 2.5 Std. / Woche aktiv',
    4: '≥ 3× / Woche intensiv',
  };

  static const _intensityOptions = <int, String>{
    0: 'Leicht',
    1: 'Moderat',
    2: 'Anstrengend',
  };
  final _injuryTypeCtrl = TextEditingController();
  final _injuryBodypartCtrl = TextEditingController();
  final _musculoDescCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();

  bool _injury = false;
  bool _injuryChronic = false;
  bool _musculoskeletal = false;
  bool _medicalTreatment = false;
  bool _takingDrugs = false;
  bool _diseaseHeartattack = false;
  bool _diseaseArterialDisorder = false;
  bool _diseaseRaynald = false;
  bool _diseaseVasculitis = false;
  bool _diseaseCold = false;
  bool _diseaseSensory = false;
  bool _diseaseCirculatory = false;
  bool _diseaseNerve = false;
  bool _diseaseReplantation = false;
  bool _diseaseLymphatics = false;
  bool _diseaseHemoglobinemia = false;
  bool _diseaseKidney = false;
  bool _diseaseHeartCirculatory = false;

  @override
  void initState() {
    super.initState();
    _loadAnamnese();
  }

  Future<void> _loadAnamnese() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _apiService.get(
        '${ApiConfig.anamnese}/${widget.client.id}',
      );
      final data =
          resp is Map<String, dynamic> ? resp : (resp is List && resp.isNotEmpty ? resp[0] as Map<String, dynamic> : null);
      if (data != null) {
        _anamnese = Anamnese.fromJson(data);
        _applyToControllers(_anamnese!);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      debugPrint('Anamnese._load error: $e');
      // No anamnese yet — start fresh
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyToControllers(Anamnese a) {
    _professionCtrl.text = a.profession ?? '';
    _activities = a.activities;
    _physicalDemands = a.physicalDemands;
    _sportartsCtrl.text = a.sportarts ?? '';
    _sportartsIntensity = a.sportartsIntensity;
    _sleepWeekCtrl.text = a.sleepWeek?.toString() ?? '';
    _sleepWeekendCtrl.text = a.sleepWeekend?.toString() ?? '';
    _injuryTypeCtrl.text = a.injuryType ?? '';
    _injuryBodypartCtrl.text = a.injuryBodypart ?? '';
    _musculoDescCtrl.text = a.musculoskeletalProblemsDescription ?? '';
    _commentsCtrl.text = a.comments ?? '';
    _goalsCtrl.text = a.goals ?? '';
    _injury = a.injury ?? false;
    _injuryChronic = a.injuryChronic ?? false;
    _musculoskeletal = a.musculoskeletalProblems ?? false;
    _medicalTreatment = a.medicalTreatment ?? false;
    _takingDrugs = a.takingDrugs ?? false;
    _diseaseHeartattack = a.diseaseHeartattack ?? false;
    _diseaseArterialDisorder = a.diseaseArterialDisorder ?? false;
    _diseaseRaynald = a.diseaseRaynaldSyndrome ?? false;
    _diseaseVasculitis = a.diseaseVasculitis ?? false;
    _diseaseCold = a.diseaseColdSensitivity ?? false;
    _diseaseSensory = a.diseaseSensoryDisturbances ?? false;
    _diseaseCirculatory = a.diseaseCirculatoryDisorder ?? false;
    _diseaseNerve = a.diseaseNerveDamage ?? false;
    _diseaseReplantation = a.diseaseReplantation ?? false;
    _diseaseLymphatics = a.diseasePeripheralLymphatics ?? false;
    _diseaseHemoglobinemia = a.diseaseHemoglobinemia ?? false;
    _diseaseKidney = a.diseaseKidneyBladder ?? false;
    _diseaseHeartCirculatory = a.diseaseHeartCirculatory ?? false;
  }

  Anamnese _buildFromForm() {
    return Anamnese(
      clientId: widget.client.id,
      profession: _professionCtrl.text,
      activities: _activities,
      physicalDemands: _physicalDemands,
      sportarts: _sportartsCtrl.text,
      sportartsIntensity: _sportartsIntensity,
      sleepWeek: int.tryParse(_sleepWeekCtrl.text),
      sleepWeekend: int.tryParse(_sleepWeekendCtrl.text),
      injury: _injury,
      injuryType: _injuryTypeCtrl.text,
      injuryBodypart: _injuryBodypartCtrl.text,
      injuryChronic: _injuryChronic,
      diseaseHeartattack: _diseaseHeartattack,
      diseaseArterialDisorder: _diseaseArterialDisorder,
      diseaseRaynaldSyndrome: _diseaseRaynald,
      diseaseVasculitis: _diseaseVasculitis,
      diseaseColdSensitivity: _diseaseCold,
      diseaseSensoryDisturbances: _diseaseSensory,
      diseaseCirculatoryDisorder: _diseaseCirculatory,
      diseaseNerveDamage: _diseaseNerve,
      diseaseReplantation: _diseaseReplantation,
      diseasePeripheralLymphatics: _diseaseLymphatics,
      diseaseHemoglobinemia: _diseaseHemoglobinemia,
      diseaseKidneyBladder: _diseaseKidney,
      diseaseHeartCirculatory: _diseaseHeartCirculatory,
      musculoskeletalProblems: _musculoskeletal,
      musculoskeletalProblemsDescription: _musculoDescCtrl.text,
      comments: _commentsCtrl.text,
      goals: _goalsCtrl.text,
      medicalTreatment: _medicalTreatment,
      takingDrugs: _takingDrugs,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = _buildFromForm();
      if (_anamnese?.clientId != null) {
        await _apiService.put(
          '${ApiConfig.anamnese}/${widget.client.id}',
          body: data.toJson(),
        );
      } else {
        await _apiService.post(ApiConfig.anamnese, body: data.toJson());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anamnese gespeichert'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _anamnese = data;
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _professionCtrl, _sportartsCtrl,
      _sleepWeekCtrl, _sleepWeekendCtrl,
      _injuryTypeCtrl, _injuryBodypartCtrl,
      _musculoDescCtrl, _commentsCtrl, _goalsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Anamnese – ${widget.client.name}'),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
              label: Text(_saving ? 'Speichere…' : 'Speichern',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadAnamnese, child: const Text('Erneut versuchen')),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Beruf & Alltag', [
            _field('Beruf', _professionCtrl),
            _enumSelector('Tätigkeiten', _activitiesOptions, _activities,
                (v) => setState(() => _activities = v)),
            _enumSelector('Körperliche Belastung', _physicalDemandsOptions,
                _physicalDemands, (v) => setState(() => _physicalDemands = v)),
          ]),
          _section('Sport & Training', [
            _field('Sportarten', _sportartsCtrl),
            _enumSelector('Intensität', _intensityOptions, _sportartsIntensity,
                (v) => setState(() => _sportartsIntensity = v)),
          ]),
          _section('Schlaf', [
            _field('Schlaf – Werktags (Std.)', _sleepWeekCtrl, keyboardType: TextInputType.number),
            _field('Schlaf – Wochenende (Std.)', _sleepWeekendCtrl, keyboardType: TextInputType.number),
          ]),
          _section('Verletzungen', [
            _toggle('Verletzung vorhanden', _injury, (v) => setState(() => _injury = v)),
            if (_injury) ...[
              _field('Verletzungsart', _injuryTypeCtrl),
              _field('Körperteil', _injuryBodypartCtrl),
              _toggle('Chronisch', _injuryChronic, (v) => setState(() => _injuryChronic = v)),
            ],
          ]),
          _section('Krankheiten / Kontraindikationen', [
            _toggle('Herzinfarkt', _diseaseHeartattack, (v) => setState(() => _diseaseHeartattack = v)),
            _toggle('Arterielle Verschlusskrankheit', _diseaseArterialDisorder, (v) => setState(() => _diseaseArterialDisorder = v)),
            _toggle('Raynaud-Syndrom', _diseaseRaynald, (v) => setState(() => _diseaseRaynald = v)),
            _toggle('Vaskulitis', _diseaseVasculitis, (v) => setState(() => _diseaseVasculitis = v)),
            _toggle('Kälteempfindlichkeit', _diseaseCold, (v) => setState(() => _diseaseCold = v)),
            _toggle('Sensibilitätsstörungen', _diseaseSensory, (v) => setState(() => _diseaseSensory = v)),
            _toggle('Durchblutungsstörung', _diseaseCirculatory, (v) => setState(() => _diseaseCirculatory = v)),
            _toggle('Nervenschädigung', _diseaseNerve, (v) => setState(() => _diseaseNerve = v)),
            _toggle('Replantation', _diseaseReplantation, (v) => setState(() => _diseaseReplantation = v)),
            _toggle('Periphere Lymphgefässe', _diseaseLymphatics, (v) => setState(() => _diseaseLymphatics = v)),
            _toggle('Hämoglobinämie', _diseaseHemoglobinemia, (v) => setState(() => _diseaseHemoglobinemia = v)),
            _toggle('Niere / Blase', _diseaseKidney, (v) => setState(() => _diseaseKidney = v)),
            _toggle('Herz / Kreislauf', _diseaseHeartCirculatory, (v) => setState(() => _diseaseHeartCirculatory = v)),
          ]),
          _section('Bewegungsapparat', [
            _toggle('Beschwerden', _musculoskeletal, (v) => setState(() => _musculoskeletal = v)),
            if (_musculoskeletal)
              _field('Beschreibung', _musculoDescCtrl, maxLines: 3),
          ]),
          _section('Allgemein', [
            _toggle('In ärztlicher Behandlung', _medicalTreatment, (v) => setState(() => _medicalTreatment = v)),
            _toggle('Medikamente', _takingDrugs, (v) => setState(() => _takingDrugs = v)),
            _field('Ziele', _goalsCtrl, maxLines: 3),
            _field('Bemerkungen', _commentsCtrl, maxLines: 3),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Speichere…' : 'Anamnese speichern'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _enumSelector(String label, Map<int, String> options, int? value,
      ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.entries.map((e) {
              final selected = value == e.key;
              return GestureDetector(
                onTap: () => onChanged(selected ? null : e.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.text,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
