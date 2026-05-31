import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/availability.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

/// Bottom sheet dialog for trainers to book a training for a client.
class BookTrainingDialog extends StatefulWidget {
  final int trainerId;
  final List<Client> clients;
  final List<Location> locations;
  final DateTime? initialDate;
  final int? initialLocationId;

  const BookTrainingDialog({
    super.key,
    required this.trainerId,
    required this.clients,
    required this.locations,
    this.initialDate,
    this.initialLocationId,
  });

  /// Show the dialog as a modal bottom sheet. Returns true if a booking was created.
  static Future<bool?> show(
    BuildContext context, {
    required int trainerId,
    required List<Client> clients,
    required List<Location> locations,
    DateTime? initialDate,
    int? initialLocationId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookTrainingDialog(
        trainerId: trainerId,
        clients: clients,
        locations: locations,
        initialDate: initialDate,
        initialLocationId: initialLocationId,
      ),
    );
  }

  @override
  State<BookTrainingDialog> createState() => _BookTrainingDialogState();
}

class _BookTrainingDialogState extends State<BookTrainingDialog> {
  final _api = ApiService();
  bool _saving = false;
  String? _error;

  // Form state
  Client? _selectedClient;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int? _selectedLocationId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedLocationId = widget.initialLocationId;
  }

  List<Client> get _filteredClients {
    var list = List<Client>.from(widget.clients)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _book() async {
    if (_selectedClient == null) {
      setState(() => _error = 'Bitte einen Kunden auswählen');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      await _api.post(ApiConfig.training, body: {
        'client_id': _selectedClient!.id,
        'date': dateStr,
        'starttime': timeStr,
        'location_id': _selectedLocationId,
        'training_type_id': 1, // Default: Persönliches Training
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Training gebucht für ${_selectedClient!.name}'),
          backgroundColor: AppColors.green,
        ));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Buchung fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(77),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text('Training buchen',
                    style: GoogleFonts.montserrat(
                        color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error message
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withAlpha(31),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: GoogleFonts.openSans(color: AppColors.red, fontSize: 13))),
              ]),
            ),
          if (_error != null) const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // ── Date & Time ──────────────────────────────
                Row(
                  children: [
                    Expanded(child: _buildPickerTile(
                      icon: Icons.calendar_today,
                      label: 'Datum',
                      value: DateFormat('dd.MM.yyyy').format(_selectedDate),
                      onTap: _pickDate,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPickerTile(
                      icon: Icons.access_time,
                      label: 'Uhrzeit',
                      value: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      onTap: _pickTime,
                    )),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Location ─────────────────────────────────
                Text('STANDORT', style: GoogleFonts.openSans(
                    color: AppColors.muted.withAlpha(153), fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: widget.locations.map((loc) {
                    final selected = _selectedLocationId == loc.id;
                    return ChoiceChip(
                      label: Text(loc.name, style: GoogleFonts.openSans(
                          color: selected ? AppColors.text : AppColors.muted,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                      selected: selected,
                      selectedColor: AppColors.primary.withAlpha(51),
                      backgroundColor: AppColors.surface2,
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                      onSelected: (_) => setState(() => _selectedLocationId = loc.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ── Client search ────────────────────────────
                Text('KUNDE', style: GoogleFonts.openSans(
                    color: AppColors.muted.withAlpha(153), fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.openSans(color: AppColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Kunde suchen...',
                    hintStyle: GoogleFonts.openSans(color: AppColors.muted.withAlpha(100)),
                    prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                    filled: true, fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),

                // Client list
                ..._filteredClients.take(8).map((client) {
                  final selected = _selectedClient?.id == client.id;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: selected ? AppColors.primary : AppColors.surface2,
                      child: Text(
                        client.name.isNotEmpty ? client.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join() : '?',
                        style: GoogleFonts.montserrat(
                          color: selected ? AppColors.background : AppColors.muted,
                          fontSize: 11, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text('${client.name}',
                        style: GoogleFonts.openSans(
                          color: selected ? AppColors.primary : AppColors.text,
                          fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                        : null,
                    onTap: () => setState(() => _selectedClient = client),
                  );
                }),
                if (_filteredClients.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('+ ${_filteredClients.length - 8} weitere...',
                        style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 12)),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Book button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _book,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Training buchen',
                        style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.openSans(
                  color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
              Text(value, style: GoogleFonts.montserrat(
                  color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ]),
      ),
    );
  }
}
