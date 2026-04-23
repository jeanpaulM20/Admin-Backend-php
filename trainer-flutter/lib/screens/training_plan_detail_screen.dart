import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/training_plan.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class TrainingPlanDetailScreen extends StatefulWidget {
  final Client client;
  final TrainingPlan? plan;

  const TrainingPlanDetailScreen({super.key, required this.client, this.plan});

  @override
  State<TrainingPlanDetailScreen> createState() => _TrainingPlanDetailScreenState();
}

class _TrainingPlanDetailScreenState extends State<TrainingPlanDetailScreen> {
  final _apiService = ApiService();
  bool _saving = false;
  late TrainingPlanValues _values;
  final _nameCtrl = TextEditingController();

  // Date controllers for column headers
  final List<TextEditingController> _dateCtrls =
      List.generate(8, (_) => TextEditingController());

  // Section row controllers: each row has 4 text fields (exercise, device, position, weight)
  // plus 8 date inputs handled separately
  late List<List<TextEditingController>> _sonsomoRowCtrls;
  late List<List<TextEditingController>> _mainRowCtrls;
  late List<List<TextEditingController>> _coreRowCtrls;
  late List<List<TextEditingController>> _sonsomoDateCtrls;
  late List<List<TextEditingController>> _mainDateCtrls;
  late List<List<TextEditingController>> _coreDateCtrls;

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
  }

  List<List<TextEditingController>> _buildRowCtrls(List<TrainingPlanRow> rows) {
    return rows.map((r) => [
      TextEditingController(text: r.exercise),
      TextEditingController(text: r.device),
      TextEditingController(text: r.position),
      TextEditingController(text: r.weight),
    ]).toList();
  }

  List<List<TextEditingController>> _buildDateCtrls(List<TrainingPlanRow> rows) {
    return rows.map((r) =>
      List.generate(8, (i) => TextEditingController(text: r.dates[i]))
    ).toList();
  }

  TrainingPlanValues _collectValues() {
    final dates = List.generate(8, (i) => _dateCtrls[i].text);

    List<TrainingPlanRow> collectRows(
      List<List<TextEditingController>> rowCtrls,
      List<List<TextEditingController>> dateCtrls,
    ) {
      return List.generate(rowCtrls.length, (i) => TrainingPlanRow(
        exercise: rowCtrls[i][0].text,
        device: rowCtrls[i][1].text,
        position: rowCtrls[i][2].text,
        weight: rowCtrls[i][3].text,
        dates: List.generate(8, (j) => dateCtrls[i][j].text),
      ));
    }

    return TrainingPlanValues(
      sonsomo: collectRows(_sonsomoRowCtrls, _sonsomoDateCtrls),
      main: collectRows(_mainRowCtrls, _mainDateCtrls),
      core: collectRows(_coreRowCtrls, _coreDateCtrls),
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
        await _apiService.put(
          '${ApiConfig.trainingPlan}/${plan.id}',
          body: plan.toJson(),
        );
      } else {
        await _apiService.post(ApiConfig.trainingPlan, body: plan.toJson());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training plan saved'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context, true);
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
    _nameCtrl.dispose();
    for (final c in _dateCtrls) c.dispose();
    for (final row in [..._sonsomoRowCtrls, ..._mainRowCtrls, ..._coreRowCtrls]) {
      for (final c in row) c.dispose();
    }
    for (final section in [..._sonsomoDateCtrls, ..._mainDateCtrls, ..._coreDateCtrls]) {
      for (final c in section) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.plan == null ? 'New Training Plan' : 'Edit Training Plan'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
            label: Text(_saving ? 'Saving…' : 'Save',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 20),
            _buildDateHeaders(),
            const SizedBox(height: 20),
            _buildSection('Warm-up / Sonsomo', _sonsomoRowCtrls, _sonsomoDateCtrls),
            const SizedBox(height: 20),
            _buildSection('Main', _mainRowCtrls, _mainDateCtrls),
            const SizedBox(height: 20),
            _buildSection('Core', _coreRowCtrls, _coreDateCtrls),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save Training Plan'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameCtrl,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Plan name (optional)',
        prefixIcon: const Icon(Icons.label_outline, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDateHeaders() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Training Dates',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              8,
              (i) => SizedBox(
                width: 80,
                child: _miniField('Date ${i + 1}', _dateCtrls[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<List<TextEditingController>> rowCtrls,
    List<List<TextEditingController>> dateCtrls,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5)),
          ),
          const Divider(color: AppColors.border, height: 1),
          ...List.generate(rowCtrls.length, (i) {
            return Column(
              children: [
                if (i > 0) const Divider(color: AppColors.surface, height: 1),
                _buildRow(i + 1, rowCtrls[i], dateCtrls[i]),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRow(
    int num,
    List<TextEditingController> ctrls,
    List<TextEditingController> dateCtrls,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercise $num',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniField('Exercise', ctrls[0])),
              const SizedBox(width: 8),
              Expanded(child: _miniField('Device', ctrls[1])),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _miniField('Position', ctrls[2])),
              const SizedBox(width: 8),
              Expanded(child: _miniField('Weight', ctrls[3])),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Results per date',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              8,
              (j) => SizedBox(
                width: 60,
                child: _miniField('${j + 1}', dateCtrls[j]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniField(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}
