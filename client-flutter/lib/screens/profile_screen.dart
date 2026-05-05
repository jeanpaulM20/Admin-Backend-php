import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import '../config/app_colors.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../models/credit_pack.dart';
import '../models/invoice.dart';
import '../models/client_file.dart';
import '../services/api_client.dart';
import '../services/push_notification_service.dart';
import '../services/push_notification_stub.dart' if (dart.library.html) '../services/push_notification_web.dart' as push_js;
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _polarConnected = false;
  bool _polarLoading = false;
  String? _polarConnectUrl;
  bool _pushSupported = false;
  bool _pushEnabled = false;
  bool _pushLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<ProfileProvider>().fetch(auth.clientId!);
      await _loadPolarStatus(auth.clientId!);
      await _loadPushStatus();
    }
  }

  Future<void> _loadPushStatus() async {
    if (!kIsWeb) return;
    try {
      final supported = push_js.isPushSupported();
      final permission = await push_js.getNotificationPermission();
      final existing = await push_js.getExistingPushSubscription();
      if (mounted) {
        setState(() {
          _pushSupported = supported;
          _pushEnabled = permission == 'granted' && existing != null;
        });
      }
    } catch (_) {}
  }

  Future<void> _togglePush(bool enable) async {
    final auth = context.read<AuthProvider>();
    final clientId = auth.clientId ?? '';
    if (clientId.isEmpty) return;

    setState(() => _pushLoading = true);
    try {
      if (enable) {
        final ok = await PushNotificationService.instance.subscribe(clientId);
        if (mounted) setState(() => _pushEnabled = ok);
      } else {
        await PushNotificationService.instance.unsubscribe(clientId);
        if (mounted) setState(() => _pushEnabled = false);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _pushLoading = false);
    }
  }

  Future<void> _loadPolarStatus(String clientId) async {
    try {
      final data = await apiClient.get('api/client/polar/status/$clientId');
      if (data != null && mounted) {
        setState(() {
          _polarConnected = data['connected'] == true;
          _polarConnectUrl = data['connectUrl'];
        });
      }
    } catch (_) {}
  }

  Future<void> _syncPolar(String clientId) async {
    setState(() => _polarLoading = true);
    try {
      await apiClient.post('api/client/polar/sync/$clientId', body: {});
      await _loadPolarStatus(clientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Polar-Trainings synchronisiert!')),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _polarLoading = false);
    }
  }

  Future<void> _disconnectPolar(String clientId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Polar trennen', style: TextStyle(color: AppColors.text)),
        content: const Text('Polar-Verbindung wirklich trennen?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trennen', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _polarLoading = true);
    try {
      await apiClient.post('api/client/polar/disconnect/$clientId', body: {});
      setState(() => _polarConnected = false);
    } catch (_) {} finally {
      if (mounted) setState(() => _polarLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: profile.isLoading
              ? const LoadingIndicator(message: 'Lade Profil...')
              : profile.error != null
                  ? ErrorView(message: profile.error!, onRetry: _loadData)
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar + name
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 90,
                                        height: 90,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            profile.data?.initials ?? '?',
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        profile.data?.fullName ?? '',
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Mitglied',
                                          style: TextStyle(color: AppColors.muted, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Credits section
                                _SectionTile(
                                  icon: Icons.credit_score_rounded,
                                  title: 'Meine Credits',
                                  subtitle: _creditsSubtitle(profile.data?.creditPacks),
                                  initiallyExpanded: true,
                                  children: [
                                    if (_activePacks(profile.data?.creditPacks).isEmpty)
                                      _emptyHint('Keine aktiven Credit-Pakete')
                                    else
                                      ..._activePacks(profile.data?.creditPacks)
                                          .map((pack) => _CreditPackCard(pack: pack)),
                                    if (_expiredPacks(profile.data?.creditPacks).isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _SectionTile(
                                        icon: Icons.archive_rounded,
                                        title: 'Archiv',
                                        subtitle: '${_expiredPacks(profile.data?.creditPacks).length} abgelaufene Pakete',
                                        children: [
                                          ..._expiredPacks(profile.data?.creditPacks)
                                              .map((pack) => _CreditPackCard(pack: pack)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Invoices section
                                _SectionTile(
                                  icon: Icons.receipt_long_rounded,
                                  title: 'Rechnungen',
                                  subtitle: _countLabel(profile.invoices.length, 'Rechnung', 'Rechnungen'),
                                  children: [
                                    if (profile.invoices.isEmpty)
                                      _emptyHint('Keine Rechnungen vorhanden')
                                    else
                                      ...profile.invoices.map((inv) => Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: _InvoiceCard(invoice: inv),
                                          )),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Files section
                                _SectionTile(
                                  icon: Icons.folder_rounded,
                                  title: 'Files',
                                  subtitle: _countLabel(profile.files.length, 'Datei', 'Dateien'),
                                  children: [
                                    if (profile.files.isEmpty)
                                      _emptyHint('Keine Dateien vorhanden')
                                    else
                                      ...profile.files.map((f) => _FileRow(file: f)),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Push notifications section
                                if (_pushSupported && kIsWeb)
                                  _SectionTile(
                                    icon: Icons.notifications_rounded,
                                    title: 'Benachrichtigungen',
                                    subtitle: _pushEnabled ? 'Aktiviert' : 'Deaktiviert',
                                    children: [
                                      _PushNotificationCard(
                                        enabled: _pushEnabled,
                                        loading: _pushLoading,
                                        onToggle: _togglePush,
                                      ),
                                    ],
                                  ),
                                if (_pushSupported && kIsWeb)
                                  const SizedBox(height: 10),

                                // Polar section
                                Builder(builder: (ctx) {
                                  final auth = ctx.read<AuthProvider>();
                                  final clientId = auth.clientId ?? '';
                                  return _SectionTile(
                                    icon: Icons.link_rounded,
                                    title: 'Verbindungen',
                                    subtitle: _polarConnected ? 'Polar verbunden' : 'Keine Verbindung',
                                    children: [
                                      _PolarCard(
                                        connected: _polarConnected,
                                        loading: _polarLoading,
                                        onSync: () => _syncPolar(clientId),
                                        onDisconnect: () => _disconnectPolar(clientId),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  List<CreditPack> _activePacks(List<CreditPack>? packs) {
    if (packs == null) return [];
    return packs.where((p) => !p.isExpired).toList();
  }

  List<CreditPack> _expiredPacks(List<CreditPack>? packs) {
    if (packs == null) return [];
    return packs.where((p) => p.isExpired).toList();
  }

  String _creditsSubtitle(List<CreditPack>? packs) {
    if (packs == null || packs.isEmpty) return 'Keine Credits';
    final active = _activePacks(packs);
    if (active.isEmpty) return 'Keine aktiven Credits';
    return _countLabel(active.length, 'aktives Paket', 'aktive Pakete');
  }

  String _countLabel(int n, String s, String p) =>
      n == 0 ? 'Keine $p' : '$n ${n == 1 ? s : p}';

  Widget _emptyHint(String text) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 14))),
      );
}

// ── Section tile
class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: AppColors.primary, size: 22),
          title: Text(title,
              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: children,
        ),
      ),
    );
  }
}

// ── Credit pack card
class _CreditPackCard extends StatelessWidget {
  final CreditPack pack;
  const _CreditPackCard({required this.pack});

  @override
  Widget build(BuildContext context) {
    final remaining = pack.remainingCredits.clamp(0, pack.prepaidCredits);
    final fraction = pack.prepaidCredits > 0 ? remaining / pack.prepaidCredits : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(pack.title,
                    style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$remaining / ${pack.prepaidCredits}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Invoice card
class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.isPaid;
    final statusColor = isPaid ? AppColors.green : AppColors.primary;
    final statusBg = isPaid ? AppColors.green.withOpacity(0.12) : AppColors.primary.withOpacity(0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rechnung ${invoice.invoiceNumber}',
                    style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                if (invoice.transactionDate != null)
                  Text(DateFormat('dd.MM.yyyy').format(invoice.transactionDate!),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${invoice.currency} ${invoice.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(isPaid ? 'Bezahlt' : 'Offen',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── File row (tappable — opens in-app viewer)
class _FileRow extends StatelessWidget {
  final ClientFile file;
  const _FileRow({required this.file});

  String _buildDownloadUrl(String url) {
    if (url.startsWith('/api/')) {
      final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '').replaceFirst(RegExp(r'/$'), '');
      final token = apiClient.token;
      return '$base$url${url.contains('?') ? '&' : '?'}token=$token';
    }
    return url;
  }

  void _openFile(BuildContext context) {
    final url = file.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein Datei-Link verfügbar'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    final downloadUrl = _buildDownloadUrl(url);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _InAppFileViewer(title: file.name, url: downloadUrl),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = file.date != null ? DateFormat('dd.MM.yyyy').format(file.date!) : '-';
    final hasUrl = file.url != null && file.url!.isNotEmpty;

    return GestureDetector(
      onTap: hasUrl ? () => _openFile(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(dateStr, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            if (hasUrl)
              const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// In-app file viewer using sandboxed iframe
class _InAppFileViewer extends StatefulWidget {
  final String title;
  final String url;
  const _InAppFileViewer({required this.title, required this.url});

  @override
  State<_InAppFileViewer> createState() => _InAppFileViewerState();
}

class _InAppFileViewerState extends State<_InAppFileViewer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'file-viewer-${widget.url.hashCode}';
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen'
        ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-popups');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.title, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.text, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: HtmlElementView(viewType: _viewId),
    );
  }
}

// ── Polar card
class _PolarCard extends StatelessWidget {
  final bool connected;
  final bool loading;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  const _PolarCard({
    required this.connected,
    required this.loading,
    required this.onSync,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD4002A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('P',
                  style: TextStyle(color: Color(0xFFD4002A), fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Polar',
                    style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(connected ? 'Verbunden' : 'Nicht verbunden',
                    style: TextStyle(color: connected ? AppColors.green : AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          else if (connected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Trennen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.red.withOpacity(0.12),
                    foregroundColor: AppColors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            )
          else
            const Text('Nicht konfiguriert',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Push notification card
class _PushNotificationCard extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final ValueChanged<bool> onToggle;

  const _PushNotificationCard({
    required this.enabled,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Push-Benachrichtigungen',
                    style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  enabled ? 'Aktiv - du erhaeltst Benachrichtigungen' : 'Deaktiviert',
                  style: TextStyle(color: enabled ? AppColors.green : AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          else
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
              inactiveTrackColor: AppColors.surface,
              inactiveThumbColor: AppColors.muted,
            ),
        ],
      ),
    );
  }
}
