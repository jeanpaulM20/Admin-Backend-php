import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show EventSource, MessageEvent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

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
  html.EventSource? _eventSource;
  StreamSubscription<html.MessageEvent>? _esSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeFirebase();
  }

  void _subscribeFirebase() {
    try {
      const dbUrl =
          'https://sihltraining-3ce40-default-rtdb.europe-west1.firebasedatabase.app';
      final url = '$dbUrl/chat_pings/client_${widget.client.id}.json';
      _eventSource = html.EventSource(url);
      _esSubscription =
          _eventSource!.onMessage.cast<html.MessageEvent>().listen((_) {
        if (mounted && !_loading) _loadMessages();
      });
    } catch (_) {}
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
    for (final msg in _messages) {
      if (msg.id > 0 && !msg.readTrainer) {
        try {
          await _apiService.post('${ApiConfig.feedback}/${msg.id}/read');
        } catch (_) {}
      }
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
        title: 'Aufzeichnung waehlen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final type = _trainingTypeLabel(item['training_type']?.toString());
          final training = item['training'] as Map<String, dynamic>?;
          final date = training?['date']?.toString() ?? '';
          return '$type${date.isNotEmpty ? " -- $date" : ""}';
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
          final date = training?['date']?.toString() ?? '';
          _textCtrl.text =
              '[Aufzeichnung] $type ($date)\nDauer: $duration | Kcal: $kcal | HR: ${hr ?? "--"} bpm';
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
        title: 'Performance Test waehlen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final date = item['date']?.toString() ?? '--';
          final points = item['points'] ?? 0;
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
          final date = item['date']?.toString() ?? '--';
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
        title: 'Messwerte waehlen',
        items: data.cast<Map<String, dynamic>>(),
        titleBuilder: (item) {
          final date = item['date']?.toString() ?? '--';
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
          final date = item['date']?.toString() ?? '--';
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
                      '${items.length} Eintraege',
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
    _esSubscription?.cancel();
    _eventSource?.close();
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
        msg.text.startsWith('[Messwerte]');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isTrainer ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
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
                  _buildDataMessage(msg.text, isTrainer)
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
          ),
        ),
      ),
    );
  }

  /// Render data messages with special formatting
  Widget _buildDataMessage(String text, bool isTrainer) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment:
          isTrainer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final line = entry.value;
        final isHeader = entry.key == 0;
        return Padding(
          padding: EdgeInsets.only(bottom: isHeader ? 4 : 0),
          child: Text(
            line,
            style: TextStyle(
              color: isTrainer ? Colors.white : AppColors.text,
              fontSize: isHeader ? 14 : 13,
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
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
