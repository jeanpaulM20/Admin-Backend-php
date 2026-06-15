import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../models/glucose_reading.dart';
import '../models/libre_auth.dart';
import '../providers/libre_provider.dart';

/// FreeStyle Libre CGM-Daten-Screen.
/// Zeigt aktuelle Messung + Verlauf. Login-Dialog bei nicht eingeloggt.
class GlucoseScreen extends StatelessWidget {
  const GlucoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibreProvider>();

    if (!provider.isLoggedIn) return const _LoginView();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Blutzucker', style: TextStyle(color: AppColors.text)),
        actions: [
          if (provider.fromCache)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.offline_bolt, color: AppColors.orange, size: 18),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted),
            onPressed: () => provider.loadReadings(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadReadings(forceRefresh: true),
        color: AppColors.primary,
        child: provider.isLoading && provider.readings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _Body(provider: provider),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final LibreProvider provider;
  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (provider.error != null) _ErrorBanner(message: provider.error!),
        if (provider.latestReading != null)
          _CurrentValueCard(reading: provider.latestReading!),
        if (provider.lastSync != null) ...[
          const SizedBox(height: 4),
          _SyncInfo(lastSync: provider.lastSync!, fromCache: provider.fromCache),
        ],
        const SizedBox(height: 20),
        if (provider.readings.isNotEmpty) ...[
          Text('Verlauf (letzte ${provider.readings.length} Messungen)',
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...provider.readings.reversed.take(20).map(_ReadingRow.new),
        ],
      ],
    );
  }
}

class _CurrentValueCard extends StatelessWidget {
  final GlucoseReading reading;
  const _CurrentValueCard({required this.reading});

  Color get _valueColor {
    if (reading.isHigh) return AppColors.orange;
    if (reading.isLow) return AppColors.red;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                reading.valueMmol.toStringAsFixed(1),
                style: TextStyle(
                    color: _valueColor,
                    fontSize: 56,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(' mmol/L',
                  style: TextStyle(color: AppColors.muted, fontSize: 18)),
              const SizedBox(width: 8),
              Text(reading.trendIcon,
                  style: TextStyle(color: _valueColor, fontSize: 28)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${reading.valueMgDl} mg/dL',
              style:
                  const TextStyle(color: AppColors.muted, fontSize: 14)),
          if (reading.isHigh)
            _StatusChip('Zu hoch', AppColors.orange)
          else if (reading.isLow)
            _StatusChip('Zu tief', AppColors.red)
          else
            _StatusChip('Im Bereich', AppColors.green),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  final GlucoseReading reading;
  const _ReadingRow(this.reading);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            _formatTime(reading.timestamp),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Text(
            reading.displayValue,
            style: TextStyle(
              color: reading.isHigh
                  ? AppColors.orange
                  : reading.isLow
                      ? AppColors.red
                      : AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(reading.trendIcon,
              style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _SyncInfo extends StatelessWidget {
  final DateTime lastSync;
  final bool fromCache;
  const _SyncInfo({required this.lastSync, required this.fromCache});

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(lastSync);
    final label = diff.inMinutes < 1
        ? 'Gerade synchronisiert'
        : 'Vor ${diff.inMinutes} Min. synchronisiert';
    return Row(
      children: [
        Icon(fromCache ? Icons.cached : Icons.check_circle,
            size: 12, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Text(message,
          style: const TextStyle(color: AppColors.red, fontSize: 13)),
    );
  }
}

// MARK: - Login View

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  LibreRegion _region = LibreRegion.eu;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final ok = await context.read<LibreProvider>().login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          region: _region,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<LibreProvider>().error ?? 'Login fehlgeschlagen'),
        backgroundColor: AppColors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibreProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                const Text('FreeStyle Libre Login',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('LibreView-Zugangsdaten eingeben',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 32),
                _field(_emailCtrl, 'E-Mail', Icons.email_outlined),
                const SizedBox(height: 12),
                _field(_passwordCtrl, 'Passwort', Icons.lock_outline,
                    obscure: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<LibreRegion>(
                  value: _region,
                  dropdownColor: AppColors.surface2,
                  style: const TextStyle(color: AppColors.text),
                  decoration: _inputDeco('Region', Icons.language),
                  items: LibreRegion.values
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r.name.toUpperCase())))
                      .toList(),
                  onChanged: (r) => setState(() => _region = r!),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: provider.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: provider.isLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2)
                        : const Text('Verbinden',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.text),
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      );
}
