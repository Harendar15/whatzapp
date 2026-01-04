import 'dart:async';
import 'package:flutter/foundation.dart';

typedef AsyncJob = Future<void> Function();

class MessageQueue {
  final List<AsyncJob> _queue = [];
  bool _processing = false;
  bool _disposed = false;

  void enqueue(AsyncJob job) {
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
    if (_processing || _disposed) return;
    _processing = true;

    while (_queue.isNotEmpty && !_disposed) {
      final job = _queue.removeAt(0);
      try {
        await job()
            .timeout(const Duration(seconds: 20)); // 🔥 HARD SAFETY
      } catch (e) {
        // ❌ NEVER crash queue
      }
    }

    _processing = false;
  }
}
