import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../models/call_model.dart';
import '../../models/user_model.dart';

class CallHistoryController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Used by no_data_widget & select_contacts_group
  final RxList<String> uidWhoCanSee = <String>[].obs;
  final RxList<String> userNumberList = <String>[].obs;

  User? get _user => _auth.currentUser;

  /// 🔥 Call history stream – per user:
  ///   users/{uid}/callLogs/{callId}
  Stream<List<CallModel>> getCallHistory() {
    final uid = _user?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('callLogs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => CallModel.fromMap(d.data())).toList(),
        );
  }

  /// 🔥 Contact list – all users except me (for no_data & group select)
  Stream<List<UserModel>> getContactList() {
    final uid = _user?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore.collection('users').snapshots().map((snap) {
      return snap.docs
          .map((d) => UserModel.fromMap(d.data()))
          .where((u) => u.uid != uid)
          .toList();
    });
  }

  // ------------------- LOG WRITERS -------------------

  /// Called when a call is accepted
  Future<void> onCallAccepted(CallModel call) async {
    await _writeLog(call, status: 'accepted');
  }

  /// Called when call ends (wasAnswered = false → missed)
  Future<void> onCallEnded(
    CallModel call, {
    required bool wasAnswered,
  }) async {
    final status = wasAnswered ? 'ended' : 'missed';
    await _writeLog(call, status: status);
  }

  /// Write/update logs for both participants under:
  /// users/{uid}/callLogs/{callId}
  Future<void> _writeLog(
    CallModel call, {
    required String status,
  }) async {
    final data = call.toMap();
    data['status'] = status;

    final batch = _firestore.batch();

    for (final uid in call.members) {
      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('callLogs')
          .doc(call.callId);

      batch.set(ref, data, SetOptions(merge: true));
    }

    try {
   await batch.commit();
      } catch (e) {
        
      }

  }
}
