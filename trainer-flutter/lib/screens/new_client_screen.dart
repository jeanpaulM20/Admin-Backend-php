import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class NewClientScreen extends StatefulWidget {
  const NewClientScreen({super.key});

  @override
  State<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends State<NewClientScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _surnameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  String? _gender;
  DateTime? _birthday;

  @override
  void dispose() {
    for (final c in [
      _surnameCtrl, _nameCtrl, _emailCtrl,
      _phoneCtrl, _mobileCtrl, _birthdayCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _birthday = picked;
        _birthdayCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final response = await _apiService.post(ApiConfig.client, body: {
        'surname': _surnameCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)
          'e_mail': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_mobileCtrl.text.trim().isNotEmpty)
          'mobile': _mobileCtrl.text.trim(),
        if (_birthday != null)
          'birthday': _birthdayCtrl.text,
        if (_gender != null) 'gender': _gender,
      });
      if (mounted) {
        final newId = response is Map ? response['clientid']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newId != null
                ? 'Kunde erstellt — Kunden-ID: $newId'
                : 'Kunde erfolgreich erstellt'),
            backgroundColor: const Color(0xFF2E7D32),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Neuer Kunde'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.person_add_outlined, size: 18, color: Colors.white),
            label: Text(_saving ? 'Speichere…' : 'Speichern',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _card([
                _field('Nachname', _surnameCtrl,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null),
                _field('Vorname', _nameCtrl,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null),
              ], 'Name'),
              const SizedBox(height: 16),
              _card([
                _field('E-Mail', _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      return regex.hasMatch(v.trim()) ? null : 'Ungültige E-Mail';
                    }),
                _field('Telefon', _phoneCtrl,
                    keyboardType: TextInputType.phone),
                _field('Mobil', _mobileCtrl,
                    keyboardType: TextInputType.phone),
              ], 'Kontakt'),
              const SizedBox(height: 16),
              _card([
                GestureDetector(
                  onTap: _pickBirthday,
                  child: AbsorbPointer(
                    child: _field('Geburtstag', _birthdayCtrl,
                        suffixIcon: const Icon(Icons.calendar_today_outlined,
                            size: 18, color: AppColors.muted)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _gender,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Geschlecht',
                    labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'm', child: Text('Männlich')),
                    DropdownMenuItem(value: 'f', child: Text('Weiblich')),
                    DropdownMenuItem(value: 'd', child: Text('Divers')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ], 'Persönlich'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(_saving ? 'Erstelle…' : 'Kunde erstellen'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children, String title) {
    return Container(
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
                  letterSpacing: 0.8),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFB71C1C)),
          ),
        ),
      ),
    );
  }
}
