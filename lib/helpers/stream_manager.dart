import 'dart:async';

class StreamManager {
  static final List<StreamSubscription> _subscriptions = [];

  static void add(StreamSubscription sub) {
    _subscriptions.add(sub);
  }

  static Future<void> cancelAll() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
