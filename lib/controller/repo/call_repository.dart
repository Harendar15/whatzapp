// lib/controller/repo/call_repository.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';

import '../../models/call_model.dart';

// E2E stubs (replace with real implementations)
import '../../crypto/session_manager.dart' as sm;
import '../../crypto/identity_key_manager.dart';
import '../../crypto/key_manager.dart';
import 'package:adchat/helpers/local_storage.dart';

class CallRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String collection = 'calls';

  String _randomKeyBase64(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) bytes[i] = rnd.nextInt(256);
    return base64Encode(bytes);
  }

  Future<void> _ensureOrInitSessionForPeer({
    required String myUid,
    required String peerUid,
    required String myDeviceId,
  }) async {
    final existing = await sm.loadSession(myUid, peerUid, myDeviceId);
    if (existing != null) return;

    final identity = IdentityKeyManager(firestore: _firestore);
    final deviceMap = await identity.fetchAllDevicePubMap(peerUid);
    if (deviceMap.isEmpty) {
      throw Exception('No public key for peer');
    }

    final peerPubBytes = base64Decode(deviceMap.entries.first.value);
    final peerPub = SimplePublicKey(
      peerPubBytes,
      type: KeyPairType.x25519,
    );

    final keyManager = KeyManager(firestore: _firestore);
    final myPair =
        await keyManager.loadLocalKeyPair(uid: myUid, deviceId: myDeviceId);

 final peerDeviceId = deviceMap.keys.first;

      await sm.initSession(
        myUid: myUid,
        peerId: peerUid,
        myKeyPair: myPair,
        deviceId: myDeviceId,
        peerDeviceId: peerDeviceId, // ✅ ADD THIS
        peerPub: peerPub,
      );

  }

  // ------------------------------------------------------

  Future<CallModel> createEncryptedCall({
    required CallModel model,
  }) async {
    final caller = _auth.currentUser;
    if (caller == null) throw Exception('Not logged in');

    final myUid = caller.uid;
    final peerUid = model.receiverId;

    final deviceId = LocalStorage.getDeviceId();
    if (deviceId == null) throw Exception("DeviceId missing");

    await _ensureOrInitSessionForPeer(
      myUid: myUid,
      peerUid: peerUid,
      myDeviceId: deviceId,
    );

    final mediaKeyB64 = _randomKeyBase64(32);

    final payload = {
      'callerName': model.callerName,
      'callerImage': model.callerImage,
      'receiverName': model.receiverName,
      'receiverImage': model.receiverImage,
      'type': model.type,
      'mediaKey': mediaKeyB64,
      'channelName': model.channelName,
    };

    final plainBytes =
        Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    final envelope = await sm.encryptMessage(
      myUid,
      peerUid,
      deviceId,
      plainBytes,
    );

    await _firestore.collection(collection).doc(model.callId).set({
      'callId': model.callId,
      'callerId': model.callerId,
      'receiverId': model.receiverId,
      'status': model.status,
      'timestamp': model.timestamp,
      'ciphertext': envelope['ciphertext'],
      'iv': envelope['iv'],
      'mac': envelope['mac'],
      'creatorUid': model.callerId,
      'members': [model.callerId, model.receiverId],

    });

    return model;
  }
  // ✅ PUBLIC method for controllers
Future<CallModel?> decryptIncomingCall(Map<String, dynamic> data) async {
  final decrypted = await _decryptCallPayload(data);
  if (decrypted == null) return null;

  return CallModel(
    callId: data['callId'] ?? '',
    callerId: data['callerId'] ?? '',
    callerName: decrypted['callerName'] ?? '',
    callerImage: decrypted['callerImage'] ?? '',
    receiverId: data['receiverId'] ?? '',
    receiverName: decrypted['receiverName'] ?? '',
    receiverImage: decrypted['receiverImage'] ?? '',
    type: decrypted['type'] ?? 'audio',
    status: data['status'] ?? '',
    timestamp: data['timestamp'] ?? 0,
    mediaKey: decrypted['mediaKey'] ?? '',
    token:  data['token'] ?? '',
    channelName: decrypted['channelName'] ?? '',
    members: List<String>.from(data['members'] ?? []),
  );
}

  // ------------------------------------------------------

  Future<Map<String, dynamic>?> _decryptCallPayload(
      Map<String, dynamic> data) async {
        if (data['ciphertext'] == null ||
    data['iv'] == null ||
    data['mac'] == null) {
  return null;
}

    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return null;

    final peerId =
        myUid == data['callerId'] ? data['receiverId'] : data['callerId'];

    final deviceId = LocalStorage.getDeviceId();
    if (deviceId == null) return null;

    try {
      await _ensureOrInitSessionForPeer(
        myUid: myUid,
        peerUid: peerId,
        myDeviceId: deviceId,
      );
      final identity = IdentityKeyManager(firestore: _firestore);
final peerPub = await identity.fetchAnyDevicePublicKey(peerId);
if (peerPub == null) throw Exception("Peer identity missing");

final plain = await sm.decryptMessage(
  myUid,
  peerId,
  deviceId,
  peerPub, // ✅ REQUIRED
  {
    'ciphertext': data['ciphertext'],
    'iv': data['iv'],
    'mac': data['mac'],
  },
);


      return jsonDecode(utf8.decode(plain));
    } catch (e) {
      debugPrint("decrypt error: $e");
      return null;
    }
      }

  Stream<CallModel?> streamCallByReceiver(String receiverId) {
    return _firestore
        .collection(collection)
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final decrypted = await _decryptCallPayload(data);
      if (decrypted == null) return null;

      return CallModel(
        callId: data['callId'] ?? '',
        callerId: data['callerId'] ?? '',
        callerName: decrypted['callerName'] ?? '',
        callerImage: decrypted['callerImage'] ?? '',
        receiverId: data['receiverId'] ?? '',
        receiverName: decrypted['receiverName'] ?? '',
        receiverImage: decrypted['receiverImage'] ?? '',
        status: data['status'] ?? '',
        type: decrypted['type'] ?? 'audio',
        timestamp: data['timestamp'] ?? 0,
        mediaKey: decrypted['mediaKey'] ?? '',
        token: ' ',
        channelName: decrypted['channelName'] ?? '',
        members: [data['callerId'], data['receiverId']].cast<String>(),
      );
    });
  }

  Future<void> updateCallStatus(String callId, String status) async {
    await _firestore.collection(collection).doc(callId).update({'status': status});
  }

  Future<void> deleteCall(String callId) async {
    await _firestore.collection(collection).doc(callId).delete();
  }

  Stream<List<CallModel>> getCallHistoryForUser(String uid) {
    return _firestore
        .collection(collection)
        .where('members', arrayContains: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final out = <CallModel>[];
      for (final d in snap.docs) {
        final data = d.data();
        final decrypted = await _decryptCallPayload(data);
        if (decrypted == null) continue;
        out.add(CallModel(
          callId: data['callId'] ?? '',
          callerId: data['callerId'] ?? '',
          callerName: decrypted['callerName'] ?? '',
          callerImage: decrypted['callerImage'] ?? '',
          receiverId: data['receiverId'] ?? '',
          receiverName: decrypted['receiverName'] ?? '',
          receiverImage: decrypted['receiverImage'] ?? '',
          status: data['status'] ?? '',
          type: decrypted['type'] ?? 'audio',
          timestamp: data['timestamp'] ?? 0,
          mediaKey: decrypted['mediaKey'] ?? '',
          token: ' ',
          channelName: decrypted['channelName'] ?? '',
          members: [data['callerId'], data['receiverId']].cast<String>(),
        ));
      }
      return out;
    });
  }
}
