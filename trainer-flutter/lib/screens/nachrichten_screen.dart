import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import '../models/client.dart';
import 'workout_feedback_screen.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _ChatMsg {
  final int id;
  final int clientId;
  final String clientName;
  final String text;
  final String align; // 'right' = trainer, 'left' = client
  final bool readTrainer;
  final bool isCircle;

  const _ChatMsg({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.text,
    required this.align,
    required this.readTrainer,
    required this.isCircle,
  });

  bool get isTrainer => align == 'right';

  factory _ChatMsg.fromJson(Map<String, dynamic> j) {
    return _ChatMsg(
      id: _parseInt(j['id'] ?? 0),
      clientId: _parseInt(j['client_id'] ?? 0),
      clientName: j['client_name']?.toString() ?? 'Unbekannt',
      text: j['text']?.toString() ?? j['comment']?.toString() ?? '',
      align: j['align']?.toString() ?? 'left',
      readTrainer: j['read_trainer'] == true || j['read_trainer'] == 1 || j['read_trainer'] == '1',
      isCircle: _parseInt(j['is_circle'] ?? 0) == 1,
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class _ClientThread {
  final int clientId;
  final String clientName;
  final _ChatMsg lastMsg;
  final int unreadCount;

  const _ClientThread({
    required this.clientId,
    required this.clientName,
    required this.lastMsg,
    required this.unreadCount,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NachrichtenScreen extends StatefulWidget {
  const NachrichtenScreen({super.key});

  @override
  State<NachrichtenScreen> createState() => _NachrichtenScreenState();
}

class _NachrichtenScreenState extends State<NachrichtenScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<_ClientThread> _threads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Ensure clients are loaded so we can resolve IDs
      final provider = context.read<TrainerProvider>();
      if (provider.clients.isEmpty) {
        await provider.fetchClients();
      }

      final auth = context.read<AuthProvider>();
      final trainerId = auth.trainer?.id ?? 0;

      // Use efficient conversations endpoint (SQL aggregation)
      final resp = await _api.get(
        '${ApiConfig.feedback}/conversations',
        queryParams: {'trainer_id': trainerId.toString()},
      );
      final List<dynamic> raw = resp is List
          ? resp
          : (resp is Map && resp['data'] is List ? resp['data'] as List : []);

      final threads = raw.map((e) {
        final j = e as Map<String, dynamic>;
        final clientId = j['client_id'] is int
            ? j['client_id'] as int
            : int.tryParse(j['client_id']?.toString() ?? '') ?? 0;
        return _ClientThread(
          clientId: clientId,
          clientName: j['client_name']?.toString() ?? 'Unbekannt',
          lastMsg: _ChatMsg(
            id: j['last_id'] is int ? j['last_id'] : int.tryParse(j['last_id']?.toString() ?? '') ?? 0,
            clientId: clientId,
            clientName: j['client_name']?.toString() ?? 'Unbekannt',
            text: j['last_message']?.toString() ?? '',
            align: 'left',
            readTrainer: true,
            isCircle: false,
          ),
          unreadCount: j['unread_count'] is int ? j['unread_count'] : int.tryParse(j['unread_count']?.toString() ?? '') ?? 0,
        );
      }).toList();

      setState(() => _threads = threads);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Fehler beim Laden der Nachrichten');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Client _clientFor(_ClientThread t) {
    final clients = context.read<TrainerProvider>().clients;
    // Try by ID first (works when server returns client_id)
    if (t.clientId != 0) {
      try {
        return clients.firstWhere((c) => c.id == t.clientId);
      } catch (_) {}
    }
    // Fallback: match by full name (works when server omits client_id)
    final tName = t.clientName.toLowerCase().trim();
    try {
      return clients.firstWhere(
        (c) => c.name.toLowerCase().trim() == tName,
      );
    } catch (_) {}
    return Client(id: t.clientId, name: t.clientName);
  }

  void _openChat(_ClientThread t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutFeedbackScreen(client: _clientFor(t)),
      ),
    ).then((_) => _load()); // refresh unread counts on return
  }

  void _openNewChat() {
    final clients = context.read<TrainerProvider>().clients;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Kunden verfügbar'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    // Already-chatted client IDs (to mark them differently)
    final existingIds = _threads.map((t) => t.clientId).toSet();

    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final query = searchCtrl.text.toLowerCase();
            final filtered = query.isEmpty
                ? clients
                : clients
                    .where((c) => c.name.toLowerCase().contains(query))
                    .toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.70,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Neuer Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.muted),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (_) => setModal(() {}),
                      decoration: InputDecoration(
                        hintText: 'Kunde suchen…',
                        hintStyle: const TextStyle(color: AppColors.muted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  // Client list
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Kein Kunde gefunden',
                                style: TextStyle(color: AppColors.muted)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                                color: AppColors.border, height: 1, indent: 68),
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              final hasChat = existingIds.contains(c.id);
                              return ListTile(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          WorkoutFeedbackScreen(client: c),
                                    ),
                                  ).then((_) => _load());
                                },
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.initials,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: hasChat
                                    ? const Text('Bereits im Chat',
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11))
                                    : null,
                                trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.border,
                                    size: 18),
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 2),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnread = _threads.fold<int>(0, (s, t) => s + t.unreadCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            const Text(
              'Nachrichten',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalUnread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
            tooltip: 'Neuer Chat',
            onPressed: _openNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _threads.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppColors.red, size: 48),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: AppColors.muted),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton(
        onPressed: _load,
        child: const Text('Nochmal versuchen',
            style: TextStyle(color: AppColors.primary)),
      ),
    ]),
  );

  Widget _buildEmpty() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.chat_bubble_outline, color: AppColors.muted, size: 56),
      SizedBox(height: 16),
      Text('Keine Nachrichten', style: TextStyle(color: AppColors.muted, fontSize: 15)),
      SizedBox(height: 6),
      Text('Nachrichten erscheinen hier, sobald\nKunden oder Trainer schreiben.',
          style: TextStyle(color: AppColors.border, fontSize: 12),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _threads.length,
        separatorBuilder: (_, __) =>
            const Divider(color: AppColors.border, height: 1, indent: 72),
        itemBuilder: (_, i) => _ThreadTile(
          thread: _threads[i],
          onTap: () => _openChat(_threads[i]),
        ),
      ),
    );
  }
}

// ── Thread tile ───────────────────────────────────────────────────────────────

class _ThreadTile extends StatelessWidget {
  final _ClientThread thread;
  final VoidCallback onTap;

  const _ThreadTile({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unreadCount > 0;
    final msg = thread.lastMsg;

    String preview;
    if (msg.isCircle) {
      preview = '● Workout-Intensität: ${msg.text}/10';
    } else if (msg.isTrainer) {
      preview = 'Du: ${msg.text}';
    } else {
      preview = msg.text;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            _Avatar(name: thread.clientName, hasUnread: hasUnread),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.clientName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    style: TextStyle(
                      color: hasUnread ? AppColors.text : AppColors.muted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Unread badge
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${thread.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool hasUnread;

  const _Avatar({required this.name, required this.hasUnread});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.18),
            shape: BoxShape.circle,
            border: hasUnread
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
