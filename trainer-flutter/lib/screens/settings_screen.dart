import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import 'qr_code_screen.dart';
import 'availability_serial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoadingPrefs = false;
  String? _prefsError;
  Map<String, dynamic>? _preferences;

  @override
  void initState() {
    super.initState();
    _fetchPreferences();
  }

  Future<void> _fetchPreferences() async {
    setState(() {
      _isLoadingPrefs = true;
      _prefsError = null;
    });
    try {
      final response = await _apiService.get(ApiConfig.preference);
      setState(() {
        if (response is Map<String, dynamic>) {
          _preferences = response;
        } else if (response is Map) {
          _preferences = Map<String, dynamic>.from(response);
        }
      });
    } on ApiException catch (e) {
      setState(() => _prefsError = e.message);
    } catch (_) {
      setState(() => _prefsError = 'Einstellungen konnten nicht geladen werden.');
    } finally {
      setState(() => _isLoadingPrefs = false);
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final trainer = authProvider.trainer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Einstellungen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trainer info summary
          if (trainer != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withAlpha(40),
                    child: Text(
                      trainer.name.isNotEmpty
                          ? trainer.name[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainer.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (trainer.email != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            trainer.email!,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Verfügbarkeit — war bisher nur über das Kalender-Symbol
          // erreichbar und damit im Profil nicht auffindbar
          if (trainer != null) ...[
            _SectionHeader(label: 'Verfügbarkeit'),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.event_available,
              title: 'Verfügbarkeit eintragen',
              subtitle: 'Zeiten festlegen, zu denen Kunden buchen können',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AvailabilitySerialScreen(trainerId: trainer.id),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Account section
          _SectionHeader(label: 'Konto'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Passwort ändern',
            subtitle: 'Aktualisiere dein Passwort',
            onTap: _showChangePasswordDialog,
          ),
          if (trainer != null)
            _SettingsTile(
              icon: Icons.qr_code_2,
              title: 'Mein QR-Code',
              subtitle: 'Mit Kunden teilen zum Verbinden',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrCodeScreen(trainerId: trainer.id),
                ),
              ),
            ),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Abmelden',
            subtitle: 'Von deinem Konto abmelden',
            iconColor: AppColors.primary,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  title: const Text(
                    'Abmelden',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'Möchtest du dich wirklich abmelden?',
                    style: TextStyle(color: AppColors.text),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Abmelden',
                          style: TextStyle(color: Color(0xFFB71C1C))),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                context.read<TrainerProvider>().clearAll();
                await context.read<AuthProvider>().logout();
              }
            },
          ),

          const SizedBox(height: 24),

          // Preferences section
          _SectionHeader(label: 'Präferenzen'),
          const SizedBox(height: 10),
          _buildPreferences(),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    if (_isLoadingPrefs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_prefsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.muted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _prefsError!,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _fetchPreferences,
              child: const Text(
                'Erneut',
                style: TextStyle(
                    color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_preferences == null || _preferences!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Center(
          child: Text(
            'Keine Präferenzen konfiguriert.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ),
      );
    }

    final entries = _preferences!.entries.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final key = entry.key
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1)}'
                  : w)
              .join(' ');
          final value = entry.value?.toString() ?? '';
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.muted,
                size: 19,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.postForm(
        ApiConfig.changePassword,
        body: {
          'password': _newPasswordController.text,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwort erfolgreich geändert.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Passwort ändern',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              controller: _newPasswordController,
              label: 'Neues Passwort',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Pflichtfeld';
                if (v.length < 6) return 'Min. 6 Zeichen';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmPasswordController,
              label: 'Passwort bestätigen',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Pflichtfeld';
                if (v != _newPasswordController.text) {
                  return 'Passwörter stimmen nicht überein';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text(
            'Abbrechen',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Speichern'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.muted,
            size: 18,
          ),
          onPressed: onToggle,
        ),
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB71C1C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB71C1C)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFB71C1C), fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
