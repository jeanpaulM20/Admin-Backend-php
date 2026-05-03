import 'dart:async';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show EventSource, MessageEvent;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/empty_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _selectedTrainerId;
  String? _selectedTrainerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConversations());
  }

  Future<void> _loadConversations() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<ChatProvider>().fetchConversations(auth.clientId!);
      final convs = context.read<ChatProvider>().conversations;
      if (convs.length == 1 && _selectedTrainerId == null) {
        _openThread(convs.first.trainerId, convs.first.trainerName);
      }
    }
  }

  void _openThread(String trainerId, String trainerName) {
    setState(() {
      _selectedTrainerId = trainerId;
      _selectedTrainerName = trainerName;
    });
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      context.read<ChatProvider>().fetchMessages(auth.clientId!, trainerId);
      context.read<ChatProvider>().markAsRead(auth.clientId!, trainerId);
    }
  }

  void _backToList() {
    setState(() {
      _selectedTrainerId = null;
      _selectedTrainerName = null;
    });
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTrainerId != null) {
      return _ChatThread(
        trainerId: _selectedTrainerId!,
        trainerName: _selectedTrainerName ?? 'Trainer',
        onBack: _backToList,
      );
    }
    return _ConversationList(
      onSelect: _openThread,
      onRefresh: _loadConversations,
    );
  }
}

// ── Conversation List ──────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final void Function(String trainerId, String trainerName) onSelect;
  final Future<void> Function() onRefresh;

  const _ConversationList({required this.onSelect, required this.onRefresh});

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} T.';
    return DateFormat('dd.MM.yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final totalUnread = chat.totalUnreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with unread count
            if (totalUnread > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalUnread ungelesen',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: onRefresh,
                child: chat.isLoading
                    ? const LoadingIndicator(message: 'Lade Nachrichten...')
                    : chat.error != null
                        ? ErrorView(message: chat.error!, onRetry: onRefresh)
                        : chat.conversations.isEmpty
                            ? const EmptyView(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Keine Nachrichten',
                                subtitle:
                                    'Nachrichten erscheinen hier, sobald\ndein Trainer dir schreibt.',
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: chat.conversations.length,
                                separatorBuilder: (_, __) => const Divider(
                                    color: AppColors.border, height: 1, indent: 72),
                                itemBuilder: (context, index) {
                                  final conv = chat.conversations[index];
                                  return _ConversationTile(
                                    conversation: conv,
                                    timeLabel: _formatTime(conv.lastMessageAt),
                                    onTap: () =>
                                        onSelect(conv.trainerId, conv.trainerName),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String timeLabel;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.timeLabel,
    required this.onTap,
  });

  String get _initials {
    final parts = conversation.trainerName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(46),
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
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.trainerName,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conversation.lastMessage ?? 'Noch keine Nachrichten',
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
            // Unread badge or chevron
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: AppColors.white,
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

// ── Chat Thread ────────────────────────────────────���────────────────

class _ChatThread extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final VoidCallback onBack;

  const _ChatThread({
    required this.trainerId,
    required this.trainerName,
    required this.onBack,
  });

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<_ChatThread> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  html.EventSource? _eventSource;
  StreamSubscription<html.MessageEvent>? _esSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeFirebase();
  }

  void _subscribeFirebase() {
    try {
      final auth = context.read<AuthProvider>();
      final clientId = auth.clientId;
      if (clientId == null) return;
      const dbUrl =
          'https://sihltraining-3ce40-default-rtdb.europe-west1.firebasedatabase.app';
      final url = '$dbUrl/chat_pings/client_$clientId.json';
      _eventSource = html.EventSource(url);
      _esSubscription =
          _eventSource!.onMessage.cast<html.MessageEvent>().listen((_) {
        if (mounted) _refresh();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _esSubscription?.cancel();
    _eventSource?.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context
          .read<ChatProvider>()
          .sendMessage(auth.clientId!, widget.trainerId, text);
      _scrollToBottom();
    }
    setState(() => _sending = false);
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context
          .read<ChatProvider>()
          .fetchMessages(auth.clientId!, widget.trainerId);
      await context
          .read<ChatProvider>()
          .markAsRead(auth.clientId!, widget.trainerId);
    }
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Heute';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Gestern';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  String get _trainerInitials {
    final parts = widget.trainerName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _getStatusText(List<ChatMessage> messages) {
    final msgCount = messages.where((m) => !m.isCircle).length;
    final circleCount = messages.where((m) => m.isCircle).length;
    final parts = <String>[];
    if (msgCount > 0) parts.add('$msgCount Nachrichten');
    if (circleCount > 0) parts.add('$circleCount Workouts');
    return parts.isEmpty ? 'Chat' : parts.join(' · ');
  }

  // ── Attach menu ──────────────────────────────────────────────────

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Daten teilen',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              _AttachOption(
                icon: Icons.monitor_heart,
                label: 'Trainings-Aufzeichnung',
                subtitle: 'Letzte Trainingsaufzeichnung teilen',
                color: AppColors.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _shareReviewData();
                },
              ),
              _AttachOption(
                icon: Icons.show_chart,
                label: 'Performance Daten',
                subtitle: 'Leistungstest-Ergebnisse teilen',
                color: AppColors.green,
                onTap: () {
                  Navigator.pop(ctx);
                  _sharePerformanceData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareReviewData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId == null) return;
    try {
      final data = await apiClient.get('api/client/reviews/${auth.clientId}');
      if (data is! List || data.isEmpty) {
        _showSnack('Keine Aufzeichnungen vorhanden');
        return;
      }
      if (!mounted) return;
      _showPickerSheet(
        title: 'Aufzeichnung waehlen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final type = _trainingTypeLabel(item['training_type']?.toString());
          final training = item['training'] as Map<String, dynamic>?;
          final date = _fmtDate(training?['date']?.toString());
          return '$type -- $date';
        },
        subtitleBuilder: (item) {
          final duration = item['duration'] ?? '--';
          final kcal = item['kcal'] ?? '--';
          final hr = item['heart_rate'];
          return 'Dauer: $duration | Kcal: $kcal | HR: ${hr ?? "--"} bpm';
        },
        iconBuilder: (_) => Icons.monitor_heart,
        colorBuilder: (_) => AppColors.red,
        onSelect: (item) {
          final type = _trainingTypeLabel(item['training_type']?.toString());
          final duration = item['duration'] ?? '--';
          final kcal = item['kcal'] ?? '--';
          final hr = item['heart_rate'];
          final training = item['training'] as Map<String, dynamic>?;
          final date = _fmtDate(training?['date']?.toString());
          _controller.text =
              '[Aufzeichnung] $type ($date)\nDauer: $duration | Kcal: $kcal | HR: ${hr ?? "--"} bpm';
        },
      );
    } catch (e) {
      _showSnack('Daten konnten nicht geladen werden');
    }
  }

  Future<void> _sharePerformanceData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId == null) return;
    try {
      final data = await apiClient.get('api/client/tests/${auth.clientId}');
      if (data is! List || data.isEmpty) {
        _showSnack('Keine Performance-Daten vorhanden');
        return;
      }
      if (!mounted) return;
      _showPickerSheet(
        title: 'Performance Test waehlen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final date = _fmtDate(item['date']?.toString());
          return 'Test vom $date';
        },
        subtitleBuilder: (item) {
          final points = item['points'] ?? 0;
          final parts = <String>['Punkte: $points'];
          final pushups = item['pushups'];
          final pullups = item['pullups'];
          if (pushups != null && pushups != 0) parts.add('Liegestuetz: $pushups');
          if (pullups != null && pullups != 0) parts.add('Klimmzuege: $pullups');
          return parts.join(' | ');
        },
        iconBuilder: (_) => Icons.show_chart,
        colorBuilder: (_) => AppColors.green,
        onSelect: (item) {
          final date = _fmtDate(item['date']?.toString());
          final points = item['points'] ?? 0;
          final parts = <String>['Punkte: $points'];
          final pushups = item['pushups'];
          final pullups = item['pullups'];
          final forearm = item['forearm_support'];
          if (pushups != null && pushups != 0) parts.add('Liegestuetz: $pushups');
          if (pullups != null && pullups != 0) parts.add('Klimmzuege: $pullups');
          if (forearm != null && forearm != 0) parts.add('Unterarmstuetz: $forearm');
          _controller.text = '[Performance] Test ($date)\n${parts.join(" | ")}';
        },
      );
    } catch (e) {
      _showSnack('Daten konnten nicht geladen werden');
    }
  }

  void _showPickerSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) titleBuilder,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required IconData Function(Map<String, dynamic>) iconBuilder,
    required Color Function(Map<String, dynamic>) colorBuilder,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${items.length} Eintraege',
                        style:
                            const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: items.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (_, i) {
                    final item = items[items.length - 1 - i];
                    final icon = iconBuilder(item);
                    final color = colorBuilder(item);
                    return ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      title: Text(titleBuilder(item),
                          style:
                              const TextStyle(color: AppColors.text, fontSize: 14)),
                      subtitle: Text(subtitleBuilder(item),
                          style:
                              const TextStyle(color: AppColors.muted, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.send,
                          color: AppColors.primary, size: 16),
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelect(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _trainingTypeLabel(String? type) {
    const labels = {
      'cardio': 'Cardio',
      'endurance': 'Ausdauer',
      'strenght': 'Kraft',
      'speed': 'Schnelligkeit',
      'coordination': 'Koordination',
      'free': 'Freies Training',
      'running': 'Laufen',
      'fitness': 'Fitness Level',
      'interval': 'Intervall',
    };
    return labels[type] ?? type ?? 'Training';
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Data card popup ──────────────────────────────────────────────

  void _showDataPopup(String text) {
    final header = text.split('\n').first;
    final dateStr = _extractDate(text);

    if (header.startsWith('[TRAINING_REPORT]') ||
        header.startsWith('[Aufzeichnung]')) {
      _showReviewDetail(dateStr);
    } else if (header.startsWith('[Performance]')) {
      _showPerformanceDetail(dateStr);
    } else if (header.startsWith('[Messwerte]')) {
      _showMetricDetail(dateStr);
    }
  }

  String? _extractDate(String text) {
    final match = RegExp(r'(\d{2}\.\d{2}\.\d{4})').firstMatch(text);
    return match?.group(1);
  }

  Future<void> _showReviewDetail(String? dateStr) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewDetailSheet(matchDate: dateStr),
    );
  }

  Future<void> _showPerformanceDetail(String? dateStr) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PerformanceDetailSheet(matchDate: dateStr),
    );
  }

  Future<void> _showMetricDetail(String? dateStr) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MetricDetailSheet(matchDate: dateStr),
    );
  }

  // ── Circle detail dialog ─────────────────────────────────────────

  void _showCircleDetail(String value) {
    final intVal = int.tryParse(value) ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Trainingsintensitaet',
          style: TextStyle(color: AppColors.text, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(10, (i) {
                final isActive = (i + 1) <= intVal;
                return Positioned.fill(
                  child: CustomPaint(
                    painter: _WheelSectorPainter(
                      sectorCount: 10,
                      sectorIndex: i,
                      isActive: isActive,
                    ),
                  ),
                );
              }),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$intVal/10',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schliessen',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showCirclesExpanded(List<ChatMessage> circles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Trainingsintensitaeten (${circles.length})',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: circles.length > 6 ? 240 : null,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: circles.map((c) {
                      final val = int.tryParse(c.text) ?? 0;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCircleDetail(c.text);
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _intensityColor(val).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _intensityColor(val).withAlpha(80),
                                width: 0.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$val',
                                style: TextStyle(
                                  color: _intensityColor(val),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '/10',
                                style: TextStyle(
                                  color: _intensityColor(val).withAlpha(150),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _intensityColor(int val) {
    if (val <= 3) return AppColors.green;
    if (val <= 6) return const Color(0xFFFFA726);
    return AppColors.red;
  }

  // ── Build methods ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesFor(widget.trainerId);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.text, size: 18),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(46),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _trainerInitials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trainerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getStatusText(messages),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.muted),
            onPressed: _refresh,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: AppColors.muted.withAlpha(100), size: 56),
                        const SizedBox(height: 16),
                        const Text('Noch keine Nachrichten',
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        const Text(
                            'Schreibe die erste Nachricht oder teile Daten',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _buildGroupedWidgets(messages).length,
                    itemBuilder: (_, i) => _buildGroupedWidgets(messages)[i],
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedWidgets(List<ChatMessage> messages) {
    final widgets = <Widget>[];
    int i = 0;
    while (i < messages.length) {
      final msg = messages[i];
      // Date separator
      if (i == 0 ||
          (msg.createdAt != null &&
              messages[i - 1].createdAt != null &&
              msg.createdAt!.day != messages[i - 1].createdAt!.day)) {
        widgets.add(Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _formatDateHeader(msg.createdAt ?? DateTime.now()),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ));
      }

      if (msg.isCircle) {
        // Group consecutive circles
        final circles = <ChatMessage>[];
        while (i < messages.length && messages[i].isCircle) {
          circles.add(messages[i]);
          i++;
        }
        widgets.add(_buildCircleGroup(circles));
      } else {
        widgets.add(_buildBubble(msg));
        i++;
      }
    }
    return widgets;
  }

  Widget _buildCircleGroup(List<ChatMessage> circles) {
    final values = circles.map((c) => int.tryParse(c.text) ?? 0).toList();
    final avg =
        values.isEmpty ? 0 : (values.reduce((a, b) => a + b) / values.length);
    final maxVal = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: GestureDetector(
          onTap: () => _showCirclesExpanded(circles),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withAlpha(60), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _intensityColor(avg.round()).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fitness_center,
                      size: 16, color: _intensityColor(avg.round())),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${circles.length} Trainingseinheiten',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Intensitaet: Ø ${avg.toStringAsFixed(1)}/10 · Max $maxVal/10',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isClient = msg.isFromClient;

    final isDataMsg = msg.text.startsWith('[Aufzeichnung]') ||
        msg.text.startsWith('[Performance]') ||
        msg.text.startsWith('[Messwerte]') ||
        msg.text.startsWith('[TRAINING_REPORT]');

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isClient ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isClient ? 16 : 4),
          bottomRight: Radius.circular(isClient ? 4 : 16),
        ),
        border:
            isClient ? null : Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment:
            isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isClient) ...[
            Text(
              msg.author ?? widget.trainerName,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (isDataMsg)
            _buildDataCard(msg.text, isClient)
          else
            Text(
              msg.text,
              style: TextStyle(
                color: isClient ? AppColors.white : AppColors.text,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 4),
          if (msg.createdAt != null)
            Text(
              DateFormat('HH:mm').format(msg.createdAt!),
              style: TextStyle(
                color: isClient
                    ? AppColors.white.withAlpha(150)
                    : AppColors.muted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: isDataMsg
              ? GestureDetector(onTap: () => _showDataPopup(msg.text), child: bubble)
              : bubble,
        ),
      ),
    );
  }

  Widget _buildDataCard(String text, bool isClient) {
    final lines = text.split('\n');
    final header = lines.isNotEmpty ? lines[0] : '';
    final details = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    IconData icon = Icons.info_outline;
    Color tagColor = AppColors.blue;
    String tagLabel = '';
    if (header.startsWith('[TRAINING_REPORT]')) {
      icon = Icons.fitness_center;
      tagColor = const Color(0xFFFFA726);
      tagLabel = header.replaceFirst('[TRAINING_REPORT] ', '');
    } else if (header.startsWith('[Aufzeichnung]')) {
      icon = Icons.monitor_heart;
      tagColor = AppColors.red;
      tagLabel = header.replaceFirst('[Aufzeichnung] ', '');
    } else if (header.startsWith('[Performance]')) {
      icon = Icons.show_chart;
      tagColor = AppColors.green;
      tagLabel = header.replaceFirst('[Performance] ', '');
    } else if (header.startsWith('[Messwerte]')) {
      icon = Icons.monitor_weight_outlined;
      tagColor = AppColors.blue;
      tagLabel = header.replaceFirst('[Messwerte] ', '');
    }

    final textColor = isClient ? AppColors.white : AppColors.text;
    final mutedColor = isClient ? Colors.white70 : AppColors.muted;

    return Column(
      crossAxisAlignment:
          isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tagColor.withAlpha(isClient ? 60 : 30),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon,
                  size: 15, color: isClient ? AppColors.white : tagColor),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tagLabel,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(details,
              style: TextStyle(color: mutedColor, fontSize: 12, height: 1.4)),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 11, color: mutedColor),
            const SizedBox(width: 3),
            Text('Antippen fuer Details',
                style: TextStyle(color: mutedColor, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attach button
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primary, size: 24),
            onPressed: _showAttachMenu,
            tooltip: 'Daten teilen',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Nachricht schreiben...',
                  hintStyle:
                      const TextStyle(color: AppColors.muted, fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: AppColors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ���─ Attach option tile ─────────────────────────────────────────────

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title:
          Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      onTap: onTap,
    );
  }
}

// ── Wheel sector painter ───────────────────────────────────────────

class _WheelSectorPainter extends CustomPainter {
  final int sectorCount;
  final int sectorIndex;
  final bool isActive;

  _WheelSectorPainter({
    required this.sectorCount,
    required this.sectorIndex,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive
          ? Color.lerp(const Color(0xFF4CAF50), const Color(0xFFB71C1C),
              sectorIndex / (sectorCount - 1))!
          : AppColors.border
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final innerRadius = radius * 0.35;
    const gapAngle = 0.04;
    final sweepAngle = (2 * math.pi / sectorCount) - gapAngle;
    final startAngle =
        -math.pi / 2 + sectorIndex * (2 * math.pi / sectorCount) + gapAngle / 2;

    final path = Path()
      ..moveTo(center.dx + innerRadius * math.cos(startAngle),
          center.dy + innerRadius * math.sin(startAngle))
      ..lineTo(center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle))
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..lineTo(center.dx + innerRadius * math.cos(startAngle + sweepAngle),
          center.dy + innerRadius * math.sin(startAngle + sweepAngle))
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WheelSectorPainter old) =>
      old.isActive != isActive || old.sectorIndex != sectorIndex;
}

// =====================================================================
// DETAIL SHEETS
// =====================================================================

bool _dateMatches(String? rawDbDate, String? ddMMyyyy) {
  if (rawDbDate == null || ddMMyyyy == null) return false;
  try {
    final db = DateTime.parse(rawDbDate);
    final formatted = DateFormat('dd.MM.yyyy').format(db);
    return formatted == ddMMyyyy;
  } catch (_) {
    return rawDbDate.contains(ddMMyyyy);
  }
}

// ─── Review detail (Aufzeichnung) ──────────────────────────────────

class _ReviewDetailSheet extends StatefulWidget {
  final String? matchDate;
  const _ReviewDetailSheet({this.matchDate});

  @override
  State<_ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<_ReviewDetailSheet> {
  bool _loading = true;
  Map<String, dynamic>? _review;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final clientId = auth.clientId;
      if (clientId == null) throw Exception('Nicht angemeldet');

      final data = await apiClient.get('api/client/reviews/$clientId');
      if (data is List && data.isNotEmpty) {
        Map<String, dynamic>? match;
        for (final item in data) {
          final training = item['training'] as Map<String, dynamic>?;
          final tDate = training?['date']?.toString();
          if (_dateMatches(tDate, widget.matchDate)) {
            match = item as Map<String, dynamic>;
            break;
          }
        }
        match ??= data.first as Map<String, dynamic>;
        _review = match;
      }
    } catch (e) {
      _error = 'Daten konnten nicht geladen werden';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.70,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.muted)))
              : _review == null
                  ? const Center(
                      child: Text('Nicht gefunden',
                          style: TextStyle(color: AppColors.muted)))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final r = _review!;
    final training = r['training'] as Map<String, dynamic>?;
    final type = r['training_type']?.toString();
    final date = training?['date']?.toString();
    final time = training?['starttime']?.toString();
    final hr = r['heart_rate'];
    final duration = r['duration']?.toString() ?? '--';
    final kcal = r['kcal'];
    final speed = r['speed'];
    final distance = r['distance'];

    String dateLabel = '--';
    if (date != null) {
      try {
        final dt = DateTime.parse(date);
        dateLabel = DateFormat('dd.MM.yyyy').format(dt);
        if (time != null) dateLabel += '  $time';
      } catch (_) {
        dateLabel = date;
      }
    }

    const typeLabels = {
      'cardio': 'Cardio',
      'endurance': 'Ausdauer',
      'strenght': 'Kraft',
      'speed': 'Schnelligkeit',
      'coordination': 'Koordination',
      'free': 'Freies Training',
      'running': 'Laufen',
      'fitness': 'Fitness Level',
      'interval': 'Intervall',
    };
    final typeLabel = typeLabels[type] ?? type ?? 'Training';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_heart,
                  color: AppColors.red, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeLabel,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(dateLabel,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            if (hr != null) ...[
              const Icon(Icons.favorite, color: AppColors.red, size: 16),
              const SizedBox(width: 4),
              Text('${_toNum(hr).round()} bpm',
                  style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildStatCard(
                Icons.timer_outlined, 'Dauer', duration, AppColors.blue),
            const SizedBox(width: 10),
            _buildStatCard(Icons.local_fire_department, 'Kcal',
                '${kcal ?? "--"}', const Color(0xFFFFA726)),
            if (distance != null && _toNum(distance) > 0) ...[
              const SizedBox(width: 10),
              _buildStatCard(Icons.straighten, 'Distanz',
                  '${_toNum(distance).toStringAsFixed(0)} m', AppColors.green),
            ],
            if (speed != null && _toNum(speed) > 0) ...[
              const SizedBox(width: 10),
              _buildStatCard(Icons.speed, 'Speed',
                  '${_toNum(speed).toStringAsFixed(1)} km/h', AppColors.blue),
            ],
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  double _toNum(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ─── Performance test detail ───────────────────────────────────────

class _PerformanceDetailSheet extends StatefulWidget {
  final String? matchDate;
  const _PerformanceDetailSheet({this.matchDate});

  @override
  State<_PerformanceDetailSheet> createState() =>
      _PerformanceDetailSheetState();
}

class _PerformanceDetailSheetState extends State<_PerformanceDetailSheet> {
  bool _loading = true;
  Map<String, dynamic>? _test;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final clientId = auth.clientId;
      if (clientId == null) throw Exception('Nicht angemeldet');

      final data = await apiClient.get('api/client/tests/$clientId');
      if (data is List && data.isNotEmpty) {
        Map<String, dynamic>? match;
        for (final item in data) {
          if (_dateMatches(item['date']?.toString(), widget.matchDate)) {
            match = item as Map<String, dynamic>;
            break;
          }
        }
        match ??= (data.last as Map<String, dynamic>);
        _test = match;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _test == null
              ? const Center(
                  child: Text('Nicht gefunden',
                      style: TextStyle(color: AppColors.muted)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = _test!;
    String dateLabel = '--';
    try {
      dateLabel = DateFormat('dd.MM.yyyy')
          .format(DateTime.parse(t['date'].toString()));
    } catch (_) {
      dateLabel = t['date']?.toString() ?? '--';
    }

    final fields = <_PerfField>[
      _PerfField('Punkte', t['points'], Icons.star, AppColors.primary),
      _PerfField(
          'Liegestuetz', t['pushups'], Icons.fitness_center, AppColors.blue),
      _PerfField(
          'Klimmzuege', t['pullups'], Icons.fitness_center, AppColors.green),
      _PerfField('Unterarmstuetz', t['forearm_support'], Icons.timer,
          const Color(0xFFFFA726)),
      _PerfField('Seitstuetz', t['side_support'], Icons.timer,
          const Color(0xFFFFA726)),
      _PerfField(
          'Kniebeuge', t['squat_on_wall'], Icons.accessibility, AppColors.blue),
      _PerfField('Rumpfbeuge', t['trunk_bending'], Icons.accessibility,
          AppColors.green),
      _PerfField('Sensomotorik', t['sensomotoric'], Icons.psychology,
          AppColors.blue),
      _PerfField('Symmetrie', t['symmetry'], Icons.balance, AppColors.green),
      _PerfField('Reaktion', t['reaction'], Icons.flash_on,
          const Color(0xFFFFA726)),
      _PerfField(
          'CMJ', t['counter_movement_jump'], Icons.arrow_upward, AppColors.red),
      _PerfField('Tapping', t['tapping'], Icons.touch_app, AppColors.blue),
      _PerfField('Sprint 10m', t['sprint_10'], Icons.directions_run,
          AppColors.green),
      _PerfField('Sprint 20m', t['sprint_20'], Icons.directions_run,
          AppColors.green),
      _PerfField('Sprint 30m', t['sprint_30'], Icons.directions_run,
          AppColors.green),
    ];

    final active =
        fields.where((f) => f.value != null && f.value != 0).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.show_chart,
                  color: AppColors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Performance Test',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Text(dateLabel,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...active.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(f.icon, color: f.color, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(f.label,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14)),
                  ),
                  Text('${f.value}',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PerfField {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  const _PerfField(this.label, this.value, this.icon, this.color);
}

// ─── Metric detail ─────────────────────────────────────────────────

class _MetricDetailSheet extends StatefulWidget {
  final String? matchDate;
  const _MetricDetailSheet({this.matchDate});

  @override
  State<_MetricDetailSheet> createState() => _MetricDetailSheetState();
}

class _MetricDetailSheetState extends State<_MetricDetailSheet> {
  bool _loading = true;
  Map<String, dynamic>? _metric;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final clientId = auth.clientId;
      if (clientId == null) throw Exception('Nicht angemeldet');

      final data = await apiClient.get('api/client/profile/$clientId');
      // Profile may contain metrics data nested
      if (data is Map<String, dynamic>) {
        _metric = data;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _metric == null
              ? const Center(
                  child: Text('Nicht gefunden',
                      style: TextStyle(color: AppColors.muted)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final m = _metric!;

    final fields = <_PerfField>[
      _PerfField('Gewicht', m['weight'] ?? m['gewicht'], Icons.monitor_weight,
          AppColors.blue),
      _PerfField('BMI', m['bmi'], Icons.speed, AppColors.green),
      _PerfField(
          'Koerperfett %',
          m['body_fat'] ?? m['body_fat_percent'],
          Icons.water_drop,
          const Color(0xFFFFA726)),
      _PerfField(
          'Ruhepuls', m['calm_pulse'], Icons.favorite, AppColors.red),
    ];

    final active =
        fields.where((f) => f.value != null && f.value != 0).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_weight_outlined,
                  color: AppColors.blue, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Koerperwerte',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (active.isEmpty)
          const Center(
            child: Text('Keine Messwerte vorhanden',
                style: TextStyle(color: AppColors.muted)),
          )
        else
          ...active.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(f.icon, color: f.color, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(f.label,
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 14)),
                    ),
                    Text('${f.value}',
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        const SizedBox(height: 20),
      ],
    );
  }
}
