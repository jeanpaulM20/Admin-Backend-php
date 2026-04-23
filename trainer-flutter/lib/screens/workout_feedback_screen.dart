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
  final String text;
  final String? author;
  final String? align; // 'right' = trainer, 'left' = client
  final bool isCircle;
  final bool readTrainer;

  const _FeedbackMessage({
    required this.text,
    this.author,
    this.align,
    this.isCircle = false,
    this.readTrainer = false,
  });

  bool get isTrainer => align == 'right';

  factory _FeedbackMessage.fromJson(Map<String, dynamic> json) {
    final readTrainer = json['read_trainer'] == true || json['read_trainer'] == 1 || json['read_trainer'] == '1';
    final readClient  = json['read_client']  == true || json['read_client']  == 1 || json['read_client']  == '1';
    // Determine align: prefer explicit 'align' field (new server).
    // Fallback: read_trainer=true AND read_client=false → trainer sent it.
    String? align = json['align']?.toString();
    if (align == null && json.containsKey('read_client')) {
      align = (readTrainer && !readClient) ? 'right' : 'left';
    }
    return _FeedbackMessage(
      text: json['text']?.toString() ?? json['comment']?.toString() ?? '',
      author: json['author']?.toString(),
      align: align,
      isCircle: (json['is_circle'] is int ? json['is_circle'] : int.tryParse(json['is_circle']?.toString() ?? '0') ?? 0) == 1,
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
      // Firebase Realtime DB SSE-Stream — kein SDK nötig, nur REST
      const dbUrl = 'https://sihltraining-3ce40-default-rtdb.europe-west1.firebasedatabase.app';
      final url = '$dbUrl/chat_pings/client_${widget.client.id}.json';
      _eventSource = html.EventSource(url);
      _esSubscription = _eventSource!.onMessage
          .cast<html.MessageEvent>()
          .listen((_) {
        if (mounted && !_loading) _loadMessages();
      });
    } catch (_) {
      // Echtzeit nicht verfügbar — manuelles Refresh weiterhin möglich
    }
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
      // Mark all client messages as read for this trainer
      _markAllRead();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load messages';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.postForm(
        ApiConfig.markTrainerFeedback,
        body: {'client_id': widget.client.id.toString()},
      );
    } catch (_) {
      // Silently ignore — marking read is best-effort
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
      await _apiService.postForm(ApiConfig.feedback, body: {
        'client_id': widget.client.id.toString(),
        'trainer_id': trainerId.toString(),
        'text': text,
        'align': 'right',
        'read_trainer': '1',
        'read_client': '0',
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

  void _showCircleDetail(String value) {
    final intVal = int.tryParse(value) ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 260,
          height: 260,
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
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$intVal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
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
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
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
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
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
              child: Text(
                widget.client.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _buildMessages(),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadMessages, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, color: AppColors.muted, size: 56),
            SizedBox(height: 16),
            Text('No messages yet',
                style: TextStyle(color: AppColors.muted, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_FeedbackMessage msg) {
    final isTrainer = msg.isTrainer;

    if (msg.isCircle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: GestureDetector(
            onTap: () => _showCircleDetail(msg.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radio_button_checked,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Workout intensity: ${msg.text}/10',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(width: 6),
                  const Icon(Icons.info_outline,
                      color: AppColors.muted, size: 14),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isTrainer ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isTrainer
                  ? AppColors.primary
                  : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isTrainer ? 16 : 4),
                bottomRight: Radius.circular(isTrainer ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: isTrainer
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (msg.author != null && !isTrainer) ...[
                  Text(msg.author!,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                ],
                Text(
                  msg.text,
                  style: TextStyle(
                    color: isTrainer ? Colors.white : const Color(0xFFDDDDDD),
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

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Write a message…',
                hintStyle: const TextStyle(color: AppColors.muted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(21),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final startAngle =
        -3.14159 / 2 + sectorIndex * (2 * 3.14159 / sectorCount) + gapAngle / 2;

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
    // dart:math import-free approximation via inline computation
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
