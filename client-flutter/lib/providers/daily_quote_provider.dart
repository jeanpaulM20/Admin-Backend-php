import 'package:flutter/foundation.dart';
import '../models/daily_quote.dart';
import '../services/daily_quote_service.dart';

class DailyQuoteProvider extends ChangeNotifier {
  final _service = DailyQuoteService();

  DailyQuote? _quote;
  bool _loading = false;

  DailyQuote? get quote    => _quote;
  bool        get isLoading => _loading;

  /// Loads today's quote. Idempotent — skips if already loaded this session.
  Future<void> load() async {
    if (_loading || _quote != null) return;
    _loading = true;
    notifyListeners();
    try {
      _quote = await _service.fetch();
    } catch (_) {
      // Silent fail — quote is non-critical UI
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
