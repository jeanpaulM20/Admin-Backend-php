import 'dart:async';
import 'dart:convert';
import 'dart:html' as html show EventSource, MessageEvent;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// Subscribes to the backend Server-Sent-Events stream and calls [onEvent]
/// with each event type ('plan_updated', 'plan_comment', 'chat', …).
/// Replaces the old (dead) Firebase RTDB EventSource. Auto-reconnects.
class RealtimeService {
  final String channel; // e.g. 'client_42'
  final String token;
  final void Function(String type) onEvent;

  html.EventSource? _es;
  StreamSubscription<html.MessageEvent>? _sub;
  bool _closed = false;

  RealtimeService({
    required this.channel,
    required this.token,
    required this.onEvent,
  });

  void connect() {
    _closed = false;
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl
          : '${ApiConfig.baseUrl}/';
      final url =
          '${base}api/events/stream?channel=$channel&token=${Uri.encodeComponent(token)}';
      _es = html.EventSource(url);
      _sub = _es!.onMessage.cast<html.MessageEvent>().listen((e) {
        try {
          final decoded = jsonDecode(e.data as String);
          final type = decoded is Map ? decoded['type']?.toString() : null;
          if (type != null && type != 'ping') onEvent(type);
        } catch (_) {/* ignore malformed */}
      });
      _es!.onError.listen((_) {
        _sub?.cancel();
        _es?.close();
        if (!_closed) {
          debugPrint('[Realtime] SSE lost, reconnecting in 5s…');
          Future.delayed(const Duration(seconds: 5), () {
            if (!_closed) connect();
          });
        }
      });
    } catch (e) {
      debugPrint('[Realtime] init failed: $e');
    }
  }

  void dispose() {
    _closed = true;
    _sub?.cancel();
    _es?.close();
  }
}
