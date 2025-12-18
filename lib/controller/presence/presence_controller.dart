import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceController with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    } else {
      _setOnline(false);
    }
  }

  Future<void> _setOnline(bool online) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;

  try {
    await _firestore.collection("users").doc(uid).update({
      "isOnline": online,
      "lastSeen": DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

}
