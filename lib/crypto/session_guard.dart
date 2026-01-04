import 'dart:async'; // ✅ REQUIRED for Completer

class SessionGuard {
  static final Map<String, Completer<void>> _locks = {};

  static Future<void> run({
    required String key,
    required Future<void> Function() action,
  }) async {
    // If already locked → wait
    if (_locks.containsKey(key)) {
      await _locks[key]!.future;
      return;
    }

    final completer = Completer<void>();
    _locks[key] = completer;

    try {
      await action();
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _locks.remove(key);
    }
  }
}
