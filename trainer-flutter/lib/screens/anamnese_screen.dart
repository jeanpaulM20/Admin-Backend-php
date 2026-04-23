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

  final _addressCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();
  final _activitiesCtrl = TextEditingController();
  final _physicalDemandsCtrl = TextEditingController();
  final _sportartsCtrl = TextEditingController();
  final _sportartsScopeCtrl = TextEditingController();
  final _sportartsIntensityCtrl = TextEditingController();
  final _sleepWeekCtrl = TextEditingController();
  final _sleepWeekendCtrl = TextEditingController();
  final _relaxWeekCtrl = TextEditingController();
  final _relaxWeekendCtrl = TextEditingController();
  final _trainingDayoffCtrl = TextEditingController();
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
    } catch (_) {
      // No anamnese yet — start fresh
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyToControllers(Anamnese a) {
    _addressCtrl.text = a.address ?? '';
    _professionCtrl.text = a.profession ?? '';
    _activitiesCtrl.text = a.activities ?? '';
    _physicalDemandsCtrl.text = a.physicalDemands ?? '';
    _sportartsCtrl.text = a.sportarts ?? '';
    _sportartsScopeCtrl.text = a.sportartsScope ?? '';
    _sportartsIntensityCtrl.text = a.sportartsIntensity ?? '';
    _sleepWeekCtrl.text = a.sleepWeek ?? '';
    _sleepWeekendCtrl.text = a.sleepWeekend ?? '';
    _relaxWeekCtrl.text = a.relaxationWeek ?? '';
    _relaxWeekendCtrl.text = a.relaxationWeekend ?? '';
    _trainingDayoffCtrl.text = a.trainingDayoff ?? '';
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
      address: _addressCtrl.text,
      profession: _professionCtrl.text,
      activities: _activitiesCtrl.text,
      physicalDemands: _physicalDemandsCtrl.text,
      sportarts: _sportartsCtrl.text,
      sportartsScope: _sportartsScopeCtrl.text,
      sportartsIntensity: _sportartsIntensityCtrl.text,
      sleepWeek: _sleepWeekCtrl.text,
      sleepWeekend: _sleepWeekendCtrl.text,
      relaxationWeek: _relaxWeekCtrl.text,
      relaxationWeekend: _relaxWeekendCtrl.text,
      trainingDayoff: _trainingDayoffCtrl.text,
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
            content: Text('Anamnese saved successfully'),
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
      _addressCtrl, _professionCtrl, _activitiesCtrl, _physicalDemandsCtrl,
      _sportartsCtrl, _sportartsScopeCtrl, _sportartsIntensityCtrl,
      _sleepWeekCtrl, _sleepWeekendCtrl, _relaxWeekCtrl, _relaxWeekendCtrl,
      _trainingDayoffCtrl, _injuryTypeCtrl, _injuryBodypartCtrl,
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
              label: Text(_saving ? 'Saving…' : 'Save',
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
          TextButton(onPressed: _loadAnamnese, child: const Text('Retry')),
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
          _section('Personal Information', [
            _field('Address', _addressCtrl),
            _field('Profession', _professionCtrl),
            _field('Activities', _activitiesCtrl),
            _field('Physical Demands', _physicalDemandsCtrl),
          ]),
          _section('Sport & Training', [
            _field('Sports', _sportartsCtrl),
            _field('Scope / Hours per week', _sportartsScopeCtrl),
            _field('Intensity', _sportartsIntensityCtrl),
            _field('Training days off', _trainingDayoffCtrl),
          ]),
          _section('Sleep & Recovery', [
            _field('Sleep – Weekdays (h)', _sleepWeekCtrl, keyboardType: TextInputType.number),
            _field('Sleep – Weekend (h)', _sleepWeekendCtrl, keyboardType: TextInputType.number),
            _field('Relaxation – Weekdays (h)', _relaxWeekCtrl, keyboardType: TextInputType.number),
            _field('Relaxation – Weekend (h)', _relaxWeekendCtrl, keyboardType: TextInputType.number),
          ]),
          _section('Injuries', [
            _toggle('Has injury', _injury, (v) => setState(() => _injury = v)),
            if (_injury) ...[
              _field('Injury type', _injuryTypeCtrl),
              _field('Body part', _injuryBodypartCtrl),
              _toggle('Chronic', _injuryChronic, (v) => setState(() => _injuryChronic = v)),
            ],
          ]),
          _section('Diseases / Contraindications', [
            _toggle('Heart attack', _diseaseHeartattack, (v) => setState(() => _diseaseHeartattack = v)),
            _toggle('Arterial disorder', _diseaseArterialDisorder, (v) => setState(() => _diseaseArterialDisorder = v)),
            _toggle('Raynaud syndrome', _diseaseRaynald, (v) => setState(() => _diseaseRaynald = v)),
            _toggle('Vasculitis', _diseaseVasculitis, (v) => setState(() => _diseaseVasculitis = v)),
            _toggle('Cold sensitivity', _diseaseCold, (v) => setState(() => _diseaseCold = v)),
            _toggle('Sensory disturbances', _diseaseSensory, (v) => setState(() => _diseaseSensory = v)),
            _toggle('Circulatory disorder', _diseaseCirculatory, (v) => setState(() => _diseaseCirculatory = v)),
            _toggle('Nerve damage', _diseaseNerve, (v) => setState(() => _diseaseNerve = v)),
            _toggle('Replantation', _diseaseReplantation, (v) => setState(() => _diseaseReplantation = v)),
            _toggle('Peripheral lymphatics', _diseaseLymphatics, (v) => setState(() => _diseaseLymphatics = v)),
            _toggle('Hemoglobinemia', _diseaseHemoglobinemia, (v) => setState(() => _diseaseHemoglobinemia = v)),
            _toggle('Kidney / bladder', _diseaseKidney, (v) => setState(() => _diseaseKidney = v)),
            _toggle('Heart / circulatory', _diseaseHeartCirculatory, (v) => setState(() => _diseaseHeartCirculatory = v)),
          ]),
          _section('Musculoskeletal', [
            _toggle('Problems', _musculoskeletal, (v) => setState(() => _musculoskeletal = v)),
            if (_musculoskeletal)
              _field('Description', _musculoDescCtrl, maxLines: 3),
          ]),
          _section('General', [
            _toggle('Medical treatment', _medicalTreatment, (v) => setState(() => _medicalTreatment = v)),
            _toggle('Taking medication', _takingDrugs, (v) => setState(() => _takingDrugs = v)),
            _field('Goals', _goalsCtrl, maxLines: 3),
            _field('Comments', _commentsCtrl, maxLines: 3),
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
              label: Text(_saving ? 'Saving…' : 'Save Anamnese'),
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
