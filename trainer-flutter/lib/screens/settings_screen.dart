import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

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
      setState(() => _prefsError = 'Failed to load preferences.');
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
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text(
          'Settings',
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
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF333333), width: 0.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF8B2020).withAlpha(40),
                    child: Text(
                      trainer.name.isNotEmpty
                          ? trainer.name[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Color(0xFFB03030),
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
                              color: Color(0xFF9E9E9E),
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

          // Account section
          _SectionHeader(label: 'Account'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            iconColor: const Color(0xFF8B2020),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF252525),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'Are you sure you want to sign out?',
                    style: TextStyle(color: Color(0xFFCCCCCC)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF9E9E9E))),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout',
                          style: TextStyle(color: Color(0xFFB71C1C))),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<AuthProvider>().logout();
              }
            },
          ),

          const SizedBox(height: 24),

          // Preferences section
          _SectionHeader(label: 'Preferences'),
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
            color: Color(0xFF8B2020),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_prefsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF333333), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFF777777), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _prefsError!,
                style:
                    const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _fetchPreferences,
              child: const Text(
                'Retry',
                style: TextStyle(
                    color: Color(0xFF8B2020), fontSize: 13),
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
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF333333), width: 0.5),
        ),
        child: const Center(
          child: Text(
            'No preferences configured.',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
        ),
      );
    }

    final entries = _preferences!.entries.toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF333333), width: 0.5),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFF333333)),
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
                      color: Color(0xFFCCCCCC),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
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
        color: Color(0xFF8B2020),
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
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF333333), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF8B2020)).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? const Color(0xFF9E9E9E),
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
                      color: Color(0xFF777777),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF555555), size: 20),
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
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
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
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF8B2020),
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
      backgroundColor: const Color(0xFF252525),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Change Password',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              controller: _oldPasswordController,
              label: 'Current Password',
              obscure: _obscureOld,
              onToggle: () => setState(() => _obscureOld = !_obscureOld),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newPasswordController,
              label: 'New Password',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newPasswordController.text) {
                  return 'Passwords do not match';
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
            'Cancel',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B2020),
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
              : const Text('Save'),
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
        labelStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF777777),
            size: 18,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF8B2020)),
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
