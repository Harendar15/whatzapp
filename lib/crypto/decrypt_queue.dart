import 'dart:async';
import 'package:flutter/foundation.dart';

typedef DecryptJob = Future<void> Function();

class DecryptQueue {
  final List<DecryptJob> _queue = [];
  bool _processing = false;
  bool _disposed = false;

  void enqueue(DecryptJob job) {
    if (_disposed) return;
    _queue.add(job);
    _process();
  }

  void clear() {
    _queue.clear();
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
  }

  Future<void> _process() async {
    if (_processing) return;
    _processing = true;

    while (_queue.isNotEmpty && !_disposed) {
      final job = _queue.removeAt(0);

      // 🔥 UI breathe (ANTI-ANR)
      await Future.delayed(Duration.zero);

      try {
        await job();
      } catch (e, st) {
        debugPrint('❌ DecryptQueue error: $e\n$st');
      }
    }

    _processing = false;
  }
}
