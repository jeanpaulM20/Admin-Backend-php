import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/client_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final clientId = context.read<AuthProvider>().clientId;
    if (clientId != null) {
      await context.read<ClientProvider>().fetchProfile(clientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final prov   = context.watch<ClientProvider>();
    final client = prov.profile ?? auth.client;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Mein Profil',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.muted),
            onPressed: () => _confirmLogout(context),
            tooltip: 'Abmelden',
          ),
        ],
      ),
      body: prov.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Avatar + name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            client != null && client.firstname.isNotEmpty
                                ? client.firstname[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          client?.fullName ?? '',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (client?.email.isNotEmpty ?? false)
                          Text(
                            client!.email,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Info tiles
                  _InfoCard(
                    items: [
                      if (client?.phone.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Telefon',
                          value: client!.phone,
                        ),
                      if (client?.email.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'E-Mail',
                          value: client!.email,
                        ),
                      _InfoRow(
                        icon: Icons.credit_card_outlined,
                        label: 'Credits',
                        value: '${prov.credits}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Credit packs
                  if (prov.creditPacks.isNotEmpty) ...[
                    const Text(
                      'Abbonnemente',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...prov.creditPacks.map((p) => _PackCard(pack: p)),
                    const SizedBox(height: 20),
                  ],

                  // Logout button
                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, color: AppColors.red),
                    label: const Text('Abmelden',
                        style: TextStyle(color: AppColors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Abmelden', style: TextStyle(color: AppColors.text)),
        content: const Text('Wirklich abmelden?',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abmelden',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final row = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(row.icon, color: AppColors.muted, size: 18),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.label,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 11)),
                        Text(row.value,
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                    height: 1, color: AppColors.border, indent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
}

class _PackCard extends StatelessWidget {
  final Map<String, dynamic> pack;
  const _PackCard({required this.pack});

  @override
  Widget build(BuildContext context) {
    final name = pack['name']?.toString() ?? 'Abbonnement';
    final credits = pack['credits']?.toString() ?? '';
    final price = pack['price']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_membership_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
          ),
          if (credits.isNotEmpty)
            Text('$credits Credits',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if (price.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('CHF $price',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
