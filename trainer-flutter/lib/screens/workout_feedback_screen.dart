import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../config/api_config.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_colors.dart';
import '../models/review.dart';

class _FeedbackMessage {
  final int id;
  final String text;
  final String? author;
  final String? align; // 'right' = trainer, 'left' = client
  final bool isCircle;
  final bool readTrainer;

  const _FeedbackMessage({
    required this.id,
    required this.text,
    this.author,
    this.align,
    this.isCircle = false,
    this.readTrainer = false,
  });

  bool get isTrainer => align == 'right';

  factory _FeedbackMessage.fromJson(Map<String, dynamic> json) {
    final readTrainer =
        json['read_trainer'] == true ||
        json['read_trainer'] == 1 ||
        json['read_trainer'] == '1';
    final readClient =
        json['read_client'] == true ||
        json['read_client'] == 1 ||
        json['read_client'] == '1';
    String? align = json['align']?.toString();
    if (align == null && json.containsKey('read_client')) {
      align = (readTrainer && !readClient) ? 'right' : 'left';
    }
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return _FeedbackMessage(
      id: id,
      text: json['text']?.toString() ??
          json['message']?.toString() ??
          json['comment']?.toString() ??
          '',
      author: json['author']?.toString(),
      align: align,
      isCircle: (json['is_circle'] is int
              ? json['is_circle']
              : int.tryParse(json['is_circle']?.toString() ?? '0') ?? 0) ==
          1,
      readTrainer: readTrainer,
    );
  }
}

class WorkoutFeedbackScreen extends StatefulWidget {
  final Client client;

  const WorkoutFeedbackScreen({super.key, required this.client});

  @override
  State<WorkoutFeedbackScreen> createState() => _WorkoutFeedbackScreenState();
}

class _WorkoutFeedbackScreenState extends State<WorkoutFeedbackScreen> {
  final _apiService = ApiService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<_FeedbackMessage> _messages = [];
  RealtimeService? _realtime;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final token = _apiService.authToken;
    if (token == null || token.isEmpty) return;
    _realtime = RealtimeService(
      channel: 'client_${widget.client.id}',
      token: token,
      onEvent: (type) {
        if (mounted && !_loading && type == 'chat') _loadMessages();
      },
    )..connect();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _apiService.get(
        ApiConfig.feedback,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      List<dynamic> list = [];
      if (resp is List) {
        list = resp;
      } else if (resp is Map && resp['data'] is List) {
        list = resp['data'] as List;
      }
      _messages = list
          .map((e) => _FeedbackMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      _markAllRead();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Nachrichten konnten nicht geladen werden';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _markAllRead() async {
    // Single batch request instead of N+1 individual calls
    final hasUnread = _messages.any((m) => m.id > 0 && !m.readTrainer);
    if (!hasUnread) return;
    try {
      await _apiService.post(
        '${ApiConfig.feedback}/read-all?client_id=${widget.client.id}',
      );
    } catch (e) {
      debugPrint('[TrainerChat] markAllRead failed: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final trainerId = context.read<AuthProvider>().trainer?.id ?? 0;
      await _apiService.post(ApiConfig.feedback, body: {
        'clientId': widget.client.id,
        'trainerId': trainerId,
        'message': text,
        'readTrainer': 1,
        'readClient': 0,
      });
      _textCtrl.clear();
      await _loadMessages();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Share data card: send a special message with data info
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              _AttachOption(
                icon: Icons.monitor_heart,
                label: 'Letzte Herzfrequenz',
                subtitle: 'Training-Aufzeichnung teilen',
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
              _AttachOption(
                icon: Icons.monitor_weight_outlined,
                label: 'Körperwerte',
                subtitle: 'Aktuelle Messwerte teilen',
                color: AppColors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _shareMetricData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareReviewData() async {
    try {
      final data = await _apiService.get(
        ApiConfig.review,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      if (data is! List || data.isEmpty) {
        _showSnack('Keine Aufzeichnungen vorhanden');
        return;
      }
      if (!mounted) return;
      _showPickerSheet(
        title: 'Aufzeichnung wählen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final type = _trainingTypeLabel(item['training_type']?.toString());
          final training = item['training'] as Map<String, dynamic>?;
          final date = _fmtDate(training?['date']?.toString());
          return '$type -- $date';
        },
        subtitleBuilder: (item) {
          final duration = item['duration'] ?? '--';
          final hr = item['heart_rate'];
          return 'Dauer: $duration | HR: ${hr ?? "--"} bpm';
        },
        iconBuilder: (_) => Icons.monitor_heart,
        colorBuilder: (_) => AppColors.red,
        onSelect: (item) {
          final type = _trainingTypeLabel(item['training_type']?.toString());
          final duration = item['duration'] ?? '--';
          final hr = item['heart_rate'];
          final training = item['training'] as Map<String, dynamic>?;
          final date = _fmtDate(training?['date']?.toString());
          _textCtrl.text =
              '[Aufzeichnung] $type ($date)\nDauer: $duration | HR: ${hr ?? "--"} bpm';
        },
      );
    } catch (e) {
      _showSnack('Daten konnten nicht geladen werden');
    }
  }

  Future<void> _sharePerformanceData() async {
    try {
      final data = await _apiService.get(
        ApiConfig.performance,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      if (data is! List || data.isEmpty) {
        _showSnack('Keine Performance-Daten vorhanden');
        return;
      }
      if (!mounted) return;
      _showPickerSheet(
        title: 'Performance Test wählen',
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
          _textCtrl.text = '[Performance] Test ($date)\n${parts.join(" | ")}';
        },
      );
    } catch (e) {
      _showSnack('Daten konnten nicht geladen werden');
    }
  }

  Future<void> _shareMetricData() async {
    try {
      final data = await _apiService.get(
        ApiConfig.metric,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      if (data is! List || data.isEmpty) {
        _showSnack('Keine Messwerte vorhanden');
        return;
      }
      if (!mounted) return;
      _showPickerSheet(
        title: 'Messwerte wählen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final date = _fmtDate(item['date']?.toString());
          return 'Messung vom $date';
        },
        subtitleBuilder: (item) {
          final parts = <String>[];
          final weight = item['weight'] ?? item['gewicht'];
          final bmi = item['bmi'];
          if (weight != null) parts.add('$weight kg');
          if (bmi != null) parts.add('BMI $bmi');
          return parts.isEmpty ? '--' : parts.join(' | ');
        },
        iconBuilder: (_) => Icons.monitor_weight_outlined,
        colorBuilder: (_) => AppColors.blue,
        onSelect: (item) {
          final weight = item['weight'] ?? item['gewicht'];
          final bmi = item['bmi'];
          final bodyFat = item['body_fat'] ?? item['body_fat_percent'];
          final date = _fmtDate(item['date']?.toString());
          final calmPulse = item['calm_pulse'];
          final parts = <String>[];
          if (weight != null) parts.add('Gewicht: $weight kg');
          if (bmi != null) parts.add('BMI: $bmi');
          if (bodyFat != null) parts.add('KFA: $bodyFat%');
          if (calmPulse != null) parts.add('Ruhepuls: $calmPulse');
          _textCtrl.text = '[Messwerte] $date\n${parts.join(" | ")}';
        },
      );
    } catch (e) {
      _showSnack('Daten konnten nicht geladen werden');
    }
  }

  /// Generic picker bottom sheet for selecting an item from a list
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
              // Handle
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} Einträge',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
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
                    // Show newest first
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
                      title: Text(
                        titleBuilder(item),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        subtitleBuilder(item),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  /// Format any date string (ISO, yyyy-MM-dd, etc.) to dd.MM.yyyy
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

  void _showCircleDetail(String value) {
    final intVal = int.tryParse(value) ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Trainingsintensität',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(10, (i) {
                final sector = i + 1;
                final isActive = sector <= intVal;
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
                      color: Colors.white,
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

  @override
  void dispose() {
    _realtime?.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
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
                  widget.client.initials,
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
                    widget.client.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getStatusText(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadMessages,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : _error != null
                    ? _buildError()
                    : _buildMessages(),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  String _getStatusText() {
    final msgCount = _messages.where((m) => !m.isCircle).length;
    final circleCount = _messages.where((m) => m.isCircle).length;
    final parts = <String>[];
    if (msgCount > 0) parts.add('$msgCount Nachrichten');
    if (circleCount > 0) parts.add('$circleCount Workouts');
    return parts.isEmpty ? 'Chat' : parts.join(' · ');
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMessages,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                color: AppColors.muted.withAlpha(100), size: 56),
            const SizedBox(height: 16),
            const Text('Noch keine Nachrichten',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('Starte eine Unterhaltung oder teile Daten',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      );
    }

    // Group consecutive circles together
    final grouped = _groupMessages(_messages);

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: grouped.length,
      itemBuilder: (_, i) => grouped[i],
    );
  }

  List<Widget> _groupMessages(List<_FeedbackMessage> messages) {
    final widgets = <Widget>[];
    int i = 0;
    while (i < messages.length) {
      if (messages[i].isCircle) {
        // Collect consecutive circles
        final circles = <_FeedbackMessage>[];
        while (i < messages.length && messages[i].isCircle) {
          circles.add(messages[i]);
          i++;
        }
        widgets.add(_buildCircleGroup(circles));
      } else {
        widgets.add(_buildBubble(messages[i]));
        i++;
      }
    }
    return widgets;
  }

  /// Collapsed group of consecutive workout intensity circles
  Widget _buildCircleGroup(List<_FeedbackMessage> circles) {
    // Show a compact summary
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
              border: Border.all(
                  color: AppColors.primary.withAlpha(60), width: 0.5),
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
                  child: Icon(
                    Icons.fitness_center,
                    size: 16,
                    color: _intensityColor(avg.round()),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${circles.length} Trainingseinheiten',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Intensität: Ø ${avg.toStringAsFixed(1)}/10 · Max ${maxVal}/10',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: AppColors.muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCirclesExpanded(List<_FeedbackMessage> circles) {
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
                    'Trainingsintensitäten (${circles.length})',
                    style: const TextStyle(
                      color: Colors.white,
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
                                  color:
                                      _intensityColor(val).withAlpha(150),
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

  Widget _buildBubble(_FeedbackMessage msg) {
    final isTrainer = msg.isTrainer;

    // Detect data messages (starts with [Tag])
    final isDataMsg = msg.text.startsWith('[Aufzeichnung]') ||
        msg.text.startsWith('[Performance]') ||
        msg.text.startsWith('[Messwerte]') ||
        msg.text.startsWith('[TRAINING_REPORT]');

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isTrainer ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isTrainer ? 16 : 4),
          bottomRight: Radius.circular(isTrainer ? 4 : 16),
        ),
        border: isTrainer
            ? null
            : Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment:
            isTrainer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isTrainer) ...[
            Text(
              msg.author ?? widget.client.name,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (isDataMsg)
            _buildDataCard(msg.text, isTrainer)
          else
            Text(
              msg.text,
              style: TextStyle(
                color: isTrainer ? Colors.white : AppColors.text,
                fontSize: 14,
                height: 1.4,
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isTrainer ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: isDataMsg
              ? GestureDetector(
                  onTap: () => _showDataPopup(msg.text),
                  child: bubble,
                )
              : bubble,
        ),
      ),
    );
  }

  /// Compact inline data card inside a chat bubble
  Widget _buildDataCard(String text, bool isTrainer) {
    final lines = text.split('\n');
    final header = lines.isNotEmpty ? lines[0] : '';
    final details = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    // Determine icon and color from tag
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

    final textColor = isTrainer ? Colors.white : AppColors.text;
    final mutedColor = isTrainer ? Colors.white70 : AppColors.muted;

    return Column(
      crossAxisAlignment:
          isTrainer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tagColor.withAlpha(isTrainer ? 60 : 30),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: isTrainer ? Colors.white : tagColor),
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
          Text(
            details,
            style: TextStyle(color: mutedColor, fontSize: 12, height: 1.4),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 11, color: mutedColor),
            const SizedBox(width: 3),
            Text(
              'Antippen fuer Details',
              style: TextStyle(color: mutedColor, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  /// Extract date string (dd.MM.yyyy) from message text
  String? _extractDate(String text) {
    final match = RegExp(r'(\d{2}\.\d{2}\.\d{4})').firstMatch(text);
    return match?.group(1);
  }

  /// Show the specific data entry that was shared in the chat
  void _showDataPopup(String text) {
    final header = text.split('\n').first;
    final dateStr = _extractDate(text);

    if (header.startsWith('[TRAINING_REPORT]')) {
      _showReviewDetail(dateStr);
    } else if (header.startsWith('[Aufzeichnung]')) {
      _showReviewDetail(dateStr);
    } else if (header.startsWith('[Performance]')) {
      _showPerformanceDetail(dateStr);
    } else if (header.startsWith('[Messwerte]')) {
      _showMetricDetail(dateStr);
    }
  }

  /// Show single review with HR chart in a bottom sheet
  Future<void> _showReviewDetail(String? dateStr) async {
    if (!mounted) return;
    // Show loading sheet immediately
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewDetailSheet(
        client: widget.client,
        matchDate: dateStr,
      ),
    );
  }

  /// Show single performance test detail
  Future<void> _showPerformanceDetail(String? dateStr) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PerformanceDetailSheet(
        clientId: widget.client.id,
        matchDate: dateStr,
      ),
    );
  }

  /// Show single metric detail
  Future<void> _showMetricDetail(String? dateStr) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MetricDetailSheet(
        clientId: widget.client.id,
        matchDate: dateStr,
      ),
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
                controller: _textCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Nachricht schreiben...',
                  hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attach option tile ─────────────────────────────────────────────
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
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      onTap: onTap,
    );
  }
}

// ─── Wheel sector painter ───────────────────────────────────────────
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
    final sweepAngle = (2 * 3.14159 / sectorCount) - gapAngle;
    final startAngle = -3.14159 / 2 +
        sectorIndex * (2 * 3.14159 / sectorCount) +
        gapAngle / 2;

    final path = Path()
      ..moveTo(center.dx + innerRadius * _cos(startAngle),
          center.dy + innerRadius * _sin(startAngle))
      ..lineTo(center.dx + radius * _cos(startAngle),
          center.dy + radius * _sin(startAngle))
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..lineTo(center.dx + innerRadius * _cos(startAngle + sweepAngle),
          center.dy + innerRadius * _sin(startAngle + sweepAngle))
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  double _cos(double angle) => _cosine(angle);
  double _sin(double angle) => _sine(angle);

  static double _cosine(double a) {
    double x = a % (2 * 3.14159265);
    double result = 1.0;
    double term = 1.0;
    for (int n = 1; n <= 8; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      result += term;
    }
    return result;
  }

  static double _sine(double a) {
    double x = a % (2 * 3.14159265);
    double result = x;
    double term = x;
    for (int n = 1; n <= 8; n++) {
      term *= -x * x / ((2 * n) * (2 * n + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(_WheelSectorPainter old) =>
      old.isActive != isActive || old.sectorIndex != sectorIndex;
}

// =====================================================================
// DETAIL SHEETS — show a single data entry from the chat
// =====================================================================

/// Match a dd.MM.yyyy date string against a raw ISO/yyyy-MM-dd value
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

// ─── Review detail (Aufzeichnung with HR chart) ─────────────────────
class _ReviewDetailSheet extends StatefulWidget {
  final Client client;
  final String? matchDate;

  const _ReviewDetailSheet({required this.client, this.matchDate});

  @override
  State<_ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<_ReviewDetailSheet> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _review;
  List<HeartRatePoint> _timeseries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(
        ApiConfig.review,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      if (data is List && data.isNotEmpty) {
        // Find matching entry by date
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

        // Load timeseries
        final reviewId = match['id'];
        if (reviewId != null) {
          try {
            final tsData =
                await _api.get('${ApiConfig.review}/$reviewId/timeseries');
            if (tsData is List) {
              _timeseries = tsData
                  .map((e) =>
                      HeartRatePoint.fromJson(e as Map<String, dynamic>))
                  .toList();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _error = 'Daten konnten nicht geladen werden';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
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
    final speed = r['speed'];
    final distance = r['distance'];

    // Calculate Training Load (Edwards TRIMP) — pass duration for timestamp-less data
    final clientHrMax = widget.client.maxHeartRate ?? 220;
    final trimp = Review.edwardsTrimp(_timeseries, clientHrMax, duration);
    final feedbackClient = r['feedback_client']?.toString();
    final feedbackTrainer = r['feedback_trainer']?.toString();
    final intensity = r['type']?.toString();

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
        // Handle bar
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
        // Header
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
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(dateLabel,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
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
        // Stats row
        Row(
          children: [
            _buildStatCard(Icons.timer_outlined, 'Dauer', duration,
                AppColors.blue),
            const SizedBox(width: 10),
            _buildTrimpCard(trimp),
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
        // Heart rate chart
        _buildHrChart(),
        // Details
        if (intensity != null) ...[
          const SizedBox(height: 16),
          _buildInfoRow('Intensitaet', _intensityLabel(intensity)),
        ],
        if (feedbackClient != null && feedbackClient.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow('Kunden-Feedback', feedbackClient),
        ],
        if (feedbackTrainer != null && feedbackTrainer.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow('Trainer-Feedback', feedbackTrainer),
        ],
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
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimpCard(double? trimp) {
    final value = trimp != null ? '${trimp.round()}' : '--';
    final rating = trimp != null ? Review.trimpRating(trimp) : '';
    final c = trimp != null
        ? Color(Review.trimpColorValue(trimp))
        : const Color(0xFFFFA726);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.fitness_center, color: c, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Text('Load',
                style: TextStyle(color: AppColors.muted, fontSize: 11)),
            if (rating.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(rating,
                  style: TextStyle(
                      color: c, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: AppColors.text, fontSize: 13)),
        ),
      ],
    );
  }

  String _intensityLabel(String type) {
    const m = {
      'maximum': 'Maximal',
      'hard': 'Intensiv',
      'moderate': 'Moderat',
      'light': 'Leicht',
      'very_light': 'Sehr Leicht',
    };
    return m[type] ?? type;
  }

  double _toNum(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  Widget _buildHrChart() {
    if (_timeseries.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: const Text('Keine Herzfrequenz-Daten vorhanden',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );
    }

    final validPts =
        _timeseries.where((p) => p.value != null && p.value! > 0).toList();
    if (validPts.isEmpty) return const SizedBox.shrink();

    final spots = validPts
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value!))
        .toList();

    final minHr =
        validPts.map((p) => p.value!).reduce((a, b) => a < b ? a : b);
    final maxHr =
        validPts.map((p) => p.value!).reduce((a, b) => a > b ? a : b);

    final clientMaxHr = widget.client.maxHeartRate?.toDouble();
    final clientMinHr = widget.client.minHeartRate?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.monitor_heart, color: AppColors.red, size: 16),
            const SizedBox(width: 6),
            const Text('Herzfrequenz',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('Min ${minHr.round()}  /  Max ${maxHr.round()} bpm',
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              backgroundColor: Colors.transparent,
              minY: (minHr - 10).clamp(40, double.infinity),
              maxY: maxHr + 10,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border, strokeWidth: 0.5),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 20,
                    getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 10)),
                  ),
                ),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (clientMaxHr != null)
                    HorizontalLine(
                      y: clientMaxHr,
                      color: const Color(0xFFC2234D),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        style: const TextStyle(
                            color: Color(0xFFC2234D), fontSize: 10),
                        labelResolver: (_) => 'Max',
                      ),
                    ),
                  if (clientMinHr != null)
                    HorizontalLine(
                      y: clientMinHr,
                      color: const Color(0xFF03A4B6),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        style: const TextStyle(
                            color: Color(0xFF03A4B6), fontSize: 10),
                        labelResolver: (_) => 'Min',
                      ),
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface2,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem('${s.y.round()} bpm',
                          const TextStyle(color: Colors.white, fontSize: 12)))
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  preventCurveOverShooting: true,
                  color: AppColors.red,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.red.withAlpha(60),
                        AppColors.red.withAlpha(0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Zone legend
        if (clientMaxHr != null && clientMinHr != null) ...[
          const SizedBox(height: 10),
          _buildZoneLegend(clientMinHr, clientMaxHr),
        ],
      ],
    );
  }

  Widget _buildZoneLegend(double minHr, double maxHr) {
    final step = ((maxHr - minHr) * 0.25).toInt();
    final zones = [
      ('Maximal', const Color(0xFFC2234D), maxHr.round()),
      ('Intensiv', const Color(0xFFD18B37), (maxHr - step).round()),
      ('Moderat', const Color(0xFF839C4D), (maxHr - step * 2).round()),
      ('Leicht', const Color(0xFF03A4B6), (maxHr - step * 3).round()),
      ('Sehr Leicht', const Color(0xFF9E9E9E), (maxHr - step * 4).round()),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: zones
          .map((z) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: z.$2, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${z.$1} (${z.$3}+)',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10)),
                ],
              ))
          .toList(),
    );
  }
}

// ─── Performance test detail ────────────────────────────────────────
class _PerformanceDetailSheet extends StatefulWidget {
  final int clientId;
  final String? matchDate;

  const _PerformanceDetailSheet({required this.clientId, this.matchDate});

  @override
  State<_PerformanceDetailSheet> createState() =>
      _PerformanceDetailSheetState();
}

class _PerformanceDetailSheetState extends State<_PerformanceDetailSheet> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _test;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(ApiConfig.performance,
          queryParams: {'client_id': widget.clientId.toString()});
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
      dateLabel =
          DateFormat('dd.MM.yyyy').format(DateTime.parse(t['date'].toString()));
    } catch (_) {
      dateLabel = t['date']?.toString() ?? '--';
    }

    // All test fields
    final fields = <_PerfField>[
      _PerfField('Punkte', t['points'], Icons.star, AppColors.primary),
      _PerfField(
          'Liegestuetz', t['pushups'], Icons.fitness_center, AppColors.blue),
      _PerfField('Klimmzuege', t['pullups'], Icons.fitness_center,
          AppColors.green),
      _PerfField('Unterarmstuetz', t['forearm_support'], Icons.timer,
          const Color(0xFFFFA726)),
      _PerfField('Seitstuetz', t['side_support'], Icons.timer,
          const Color(0xFFFFA726)),
      _PerfField(
          'Kniebeuge', t['squat_on_wall'], Icons.accessibility, AppColors.blue),
      _PerfField('Rumpfbeuge', t['trunk_bending'], Icons.accessibility,
          AppColors.green),
      _PerfField('Hamstrings', t['hamstrings'], Icons.accessibility,
          const Color(0xFF9C27B0)),
      _PerfField('Waden', t['calfs'], Icons.accessibility,
          const Color(0xFF9C27B0)),
      _PerfField('Adduktoren', t['adductors'], Icons.accessibility,
          const Color(0xFF9C27B0)),
      _PerfField('Oberschenkel', t['straight_thigh_extensors'],
          Icons.accessibility, const Color(0xFF9C27B0)),
      _PerfField(
          'Sensomotorik', t['sensomotoric'], Icons.psychology, AppColors.blue),
      _PerfField(
          'Symmetrie', t['symmetry'], Icons.balance, AppColors.green),
      _PerfField(
          'Reaktion', t['reaction'], Icons.flash_on, const Color(0xFFFFA726)),
      _PerfField('CMJ', t['counter_movement_jump'], Icons.arrow_upward,
          AppColors.red),
      _PerfField('Tapping', t['tapping'], Icons.touch_app, AppColors.blue),
      _PerfField('Sprint 10m', t['sprint_10'], Icons.directions_run,
          AppColors.green),
      _PerfField('Sprint 20m', t['sprint_20'], Icons.directions_run,
          AppColors.green),
      _PerfField('Sprint 30m', t['sprint_30'], Icons.directions_run,
          AppColors.green),
    ];

    // Only show fields with values
    final active = fields.where((f) => f.value != null && f.value != 0).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(80),
              borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.show_chart,
                  color: AppColors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Performance Test',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Text(dateLabel,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13)),
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
                          color: Colors.white,
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

// ─── Metric detail ──────────────────────────────────────────────────
class _MetricDetailSheet extends StatefulWidget {
  final int clientId;
  final String? matchDate;

  const _MetricDetailSheet({required this.clientId, this.matchDate});

  @override
  State<_MetricDetailSheet> createState() => _MetricDetailSheetState();
}

class _MetricDetailSheetState extends State<_MetricDetailSheet> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _metric;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(ApiConfig.metric,
          queryParams: {'client_id': widget.clientId.toString()});
      if (data is List && data.isNotEmpty) {
        Map<String, dynamic>? match;
        for (final item in data) {
          if (_dateMatches(item['date']?.toString(), widget.matchDate)) {
            match = item as Map<String, dynamic>;
            break;
          }
        }
        match ??= (data.last as Map<String, dynamic>);
        _metric = match;
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
    String dateLabel = '--';
    try {
      dateLabel =
          DateFormat('dd.MM.yyyy').format(DateTime.parse(m['date'].toString()));
    } catch (_) {
      dateLabel = m['date']?.toString() ?? '--';
    }

    final fields = <_PerfField>[
      _PerfField('Gewicht', m['weight'] ?? m['gewicht'], Icons.monitor_weight,
          AppColors.blue),
      _PerfField('BMI', m['bmi'], Icons.speed, AppColors.green),
      _PerfField('Koerperfett %', m['body_fat'] ?? m['body_fat_percent'],
          Icons.water_drop, const Color(0xFFFFA726)),
      _PerfField(
          'Koerperfett kg',
          m['body_fat_kg'],
          Icons.water_drop,
          const Color(0xFFFFA726)),
      _PerfField('Ruhepuls', m['calm_pulse'], Icons.favorite, AppColors.red),
      _PerfField('Blutdruck sys', m['blood_pressure_sys'],
          Icons.monitor_heart, AppColors.red),
      _PerfField('Blutdruck dia', m['blood_pressure_dia'],
          Icons.monitor_heart, AppColors.red),
      _PerfField('Bauchumfang', m['belly'], Icons.straighten, AppColors.blue),
      _PerfField('Brustumfang', m['chest'], Icons.straighten, AppColors.blue),
      _PerfField('Huefte', m['hip'], Icons.straighten, AppColors.blue),
      _PerfField('Oberschenkel', m['thigh'], Icons.straighten, AppColors.blue),
      _PerfField('Oberarm', m['arm'], Icons.straighten, AppColors.blue),
    ];

    final active = fields.where((f) => f.value != null && f.value != 0).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(80),
              borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.monitor_weight_outlined,
                  color: AppColors.blue, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Koerperwerte',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Text(dateLabel,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13)),
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
                          color: Colors.white,
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
