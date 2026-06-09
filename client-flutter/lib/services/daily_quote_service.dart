import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_quote.dart';
import 'api_client.dart';

/// Fetches the AI-generated daily quote with two-tier caching:
///   1. In-memory (survives tab switches within a session)
///   2. SharedPreferences (survives app restarts on the same calendar day)
class DailyQuoteService {
  static DailyQuote? _memQuote;
  static String? _memDate;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<DailyQuote?> fetch() async {
    final today = _today();

    // ── 1. In-memory cache ──────────────────────────────────────────────────
    if (_memQuote != null && _memDate == today) return _memQuote;

    // ── 2. SharedPreferences cache ──────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('dq_date') == today) {
      final text   = prefs.getString('dq_text');
      final author = prefs.getString('dq_author');
      if (text != null && author != null && text.isNotEmpty) {
        _memQuote = DailyQuote(text: text, author: author);
        _memDate  = today;
        return _memQuote;
      }
    }

    // ── 3. API call ─────────────────────────────────────────────────────────
    final data = await apiClient.get('api/daily-quote');
    if (data is Map<String, dynamic>) {
      final q = DailyQuote.fromJson(data);
      if (q.text.isNotEmpty) {
        _memQuote = q;
        _memDate  = today;
        await prefs.setString('dq_date',   today);
        await prefs.setString('dq_text',   q.text);
        await prefs.setString('dq_author', q.author);
        return q;
      }
    }
    return null;
  }
}
