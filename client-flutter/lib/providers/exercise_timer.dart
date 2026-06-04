import 'dart:async';
import 'package:flutter/foundation.dart';

/// Standalone timer for exercise training — supports stopwatch + countdown modes.
///
/// Usage: create in initState, call [addListener] to trigger rebuilds,
/// dispose when the screen is disposed.
class ExerciseTimer extends ChangeNotifier {
  final Stopwatch _sw = Stopwatch();
  Timer? _tick;

  // ─── Public state ──────────────────────────────────────────────────────

  String display = '00:00';
  bool isRunning = false;
  bool isCountdown = false;
  int countdownFrom = 0;
  int countdownRemaining = 0;

  /// Which exercise is currently linked to the timer (null = stopwatch mode).
  String? activePrefix;
  int? activeIndex;
  String activeName = '';

  // ─── Controls ──────────────────────────────────────────────────────────

  void toggle() => isRunning ? pause() : start();

  void start() {
    // Finished countdown → reset instead of no-op
    if (isCountdown && countdownRemaining <= 0) {
      reset();
      return;
    }
    isRunning = true;
    if (isCountdown) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        countdownRemaining--;
        if (countdownRemaining <= 0) {
          countdownRemaining = 0;
          isRunning = false;
          _tick?.cancel();
        }
        _refreshDisplay();
        notifyListeners();
      });
    } else {
      _sw.start();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        _refreshDisplay();
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void pause() {
    _tick?.cancel();
    if (!isCountdown) _sw.stop();
    isRunning = false;
    notifyListeners();
  }

  void reset() {
    _tick?.cancel();
    _sw.stop();
    _sw.reset();
    isRunning = false;
    if (isCountdown) countdownRemaining = countdownFrom;
    _refreshDisplay();
    notifyListeners();
  }

  /// Switch to countdown mode for a specific exercise.
  void selectCountdown({
    required String prefix,
    required int index,
    required String name,
    required int seconds,
  }) {
    _tick?.cancel();
    _sw.stop();
    _sw.reset();
    isCountdown = true;
    countdownFrom = seconds;
    countdownRemaining = seconds;
    isRunning = false;
    activePrefix = prefix;
    activeIndex = index;
    activeName = name;
    _refreshDisplay();
    notifyListeners();
  }

  /// Return to stopwatch mode, clearing any exercise link.
  void switchToStopwatch() {
    _tick?.cancel();
    _sw.stop();
    _sw.reset();
    isCountdown = false;
    countdownFrom = 0;
    countdownRemaining = 0;
    isRunning = false;
    activePrefix = null;
    activeIndex = null;
    activeName = '';
    _refreshDisplay();
    notifyListeners();
  }

  /// Adjust active index after an exercise was removed.
  void onExerciseRemoved(String prefix, int removedIndex) {
    if (activePrefix != prefix) return;
    if (activeIndex == removedIndex) {
      switchToStopwatch();
    } else if (activeIndex != null && activeIndex! > removedIndex) {
      activeIndex = activeIndex! - 1;
      notifyListeners();
    }
  }

  // ─── Internal ──────────────────────────────────────────────────────────

  void _refreshDisplay() {
    if (isCountdown) {
      final m = (countdownRemaining ~/ 60).toString().padLeft(2, '0');
      final s = (countdownRemaining % 60).toString().padLeft(2, '0');
      display = '$m:$s';
    } else {
      final total = _sw.elapsed.inSeconds;
      final m = (total ~/ 60).toString().padLeft(2, '0');
      final s = (total % 60).toString().padLeft(2, '0');
      display = '$m:$s';
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
