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
import '../../crypto/ensure_session_for_peer.dart';
import 'package:adchat/helpers/local_storage.dart';
import 'package:adchat/controller/call/call_controller.dart';
import 'package:adchat/services/agora_service.dart';

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

//   Future<void> _ensureOrInitSessionForPeer({
//     required String myUid,
//     required String peerUid,
//     required String myDeviceId,
//   }) async {
//     final existing = await sm.loadSession(myUid, peerUid, myDeviceId);
//     if (existing != null) return;

//     final identity = IdentityKeyManager(firestore: _firestore);
//     final deviceMap = await identity.fetchAllDevicePubMap(peerUid);
//     if (deviceMap.isEmpty) {
//       throw Exception('No public key for peer');
//     }

//     final peerPubBytes = base64Decode(deviceMap.entries.first.value);
//     final peerPub = SimplePublicKey(
//       peerPubBytes,
//       type: KeyPairType.x25519,
//     );

//     final keyManager = KeyManager(firestore: _firestore);
//     final myPair =
//         await keyManager.loadLocalKeyPair(uid: myUid, deviceId: myDeviceId);

//     final peerDeviceId = deviceMap.keys.first;
//     final isInitiator = myUid.compareTo(peerUid) < 0;
//     final peerIdentityPub =
//           await identity.fetchDevicePublicKey(
//        peerUid,
//         peerDeviceId,
//       );

// if (peerIdentityPub == null) {
//   throw Exception('Peer identity key missing');
// }


//       await sm.initSession(
//         myUid: myUid,
//         peerId: peerUid,
//          myIdentityKeyPair: myPair,
//         deviceId: myDeviceId,
//         peerDeviceId: peerDeviceId, // ✅ ADD THIS
//         // peerPub: peerPub,
//         peerIdentityPub: peerIdentityPub,
//         // isInitiator: isInitiator,
//       );

//   }

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

  // 🔐 Ensure E2E session
  final identity = IdentityKeyManager(firestore: _firestore);
final devices = await identity.fetchAllDevicePubMap(peerUid);
if (devices.isEmpty) throw Exception('Peer has no devices');

// ensure session with ALL devices
  final peerDeviceId = devices.keys.first;

  await ensureSessionForPeer(
    firestore: _firestore,
    myUid: myUid,
    peerUid: peerUid,
    peerDeviceId: peerDeviceId,
  );



  // 🔑 Media key
    final rawKey = Uint8List(32);
    final rnd = Random.secure();
    for (var i = 0; i < 32; i++) {
      rawKey[i] = rnd.nextInt(256);
    }

    final mediaKey = base64Encode(rawKey);



  final agoraToken = await AgoraService.instance.fetchToken(
    channelName: model.channelName,
    uid: myUid.hashCode,
  );

  final payload = {
    'callerName': model.callerName,
    'callerImage': model.callerImage,
    'receiverName': model.receiverName,
    'receiverImage': model.receiverImage,
    'type': model.type,
    'mediaKey': mediaKey,
    'token': agoraToken,
    'channelName': model.channelName,
  };

  final envelope = await sm.encryptMessage(
  myUid,
  peerUid,
  deviceId,
  peerDeviceId,   // ✅ ADD THIS
  Uint8List.fromList(utf8.encode(jsonEncode(payload))),
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
    'senderDeviceId': deviceId,
    'members': [model.callerId, model.receiverId],
  });

  final encryptedModel = model.copyWith(
  mediaKey: mediaKey,
  token: agoraToken,
);

return encryptedModel;

}
// ✅ DECRYPT INCOMING CALL (USED BY CallController)
Future<CallModel?> decryptIncomingCall(
    Map<String, dynamic> data,
) async {
  try {
    if (data['ciphertext'] == null ||
        data['iv'] == null ||
        data['mac'] == null) {
      return null;
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return null;

    final peerUid =
        myUid == data['callerId'] ? data['receiverId'] : data['callerId'];

    final deviceId = LocalStorage.getDeviceId();
    if (deviceId == null) return null;
    final identity = IdentityKeyManager(firestore: _firestore);
  final devices = await identity.fetchAllDevicePubMap(peerUid);
  if (devices.isEmpty) {
    throw Exception('Peer has no devices');
  }
  final peerDeviceId = data['senderDeviceId'];
  if (peerDeviceId == null) return null;


await ensureSessionForPeer(
  firestore: _firestore,
  myUid: myUid,
  peerUid: peerUid,
  peerDeviceId: peerDeviceId,
);



   final plainBytes = await sm.decryptMessage(
  myUid,
  peerUid,
  deviceId,
  peerDeviceId,   // ✅ ADD THIS
  {
    'ciphertext': data['ciphertext'],
    'iv': data['iv'],
    'mac': data['mac'],
  },
);

    final payload = jsonDecode(utf8.decode(plainBytes));

    return CallModel(
      callId: data['callId'],
      callerId: data['callerId'],
      receiverId: data['receiverId'],
      callerName: payload['callerName'],
      callerImage: payload['callerImage'],
      receiverName: payload['receiverName'],
      receiverImage: payload['receiverImage'],
      type: payload['type'],
      channelName: payload['channelName'],
      mediaKey: payload['mediaKey'],
      token: payload['token'],
      status: data['status'],
      timestamp: data['timestamp'],
      members: List<String>.from(data['members'] ?? []),
    );
  } catch (e) {
    debugPrint('❌ decryptIncomingCall failed: $e');
    return null;
  }
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

  final peerUid =
      myUid == data['callerId'] ? data['receiverId'] : data['callerId'];

  final deviceId = LocalStorage.getDeviceId();
  if (deviceId == null) return null;

  try {
    // 🔐 Ensure correct session using senderDeviceId
    final identity = IdentityKeyManager(firestore: _firestore);
  final devices = await identity.fetchAllDevicePubMap(peerUid);
  if (devices.isEmpty) {
    throw Exception('Peer has no devices');
  }
 final peerDeviceId = data['senderDeviceId'];
  if (peerDeviceId == null) return null;

  await ensureSessionForPeer(
    firestore: _firestore,
    myUid: myUid,
    peerUid: peerUid,
    peerDeviceId: peerDeviceId,
  );

    final plain = await sm.decryptMessage(
  myUid,
  peerUid,
  deviceId,
  peerDeviceId,   // ✅ ADD THIS
  {
    'ciphertext': data['ciphertext'],
    'iv': data['iv'],
    'mac': data['mac'],
  },
);


    return jsonDecode(utf8.decode(plain));
  } catch (e) {
    debugPrint('decrypt error: $e');
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
       token: decrypted['token'] ?? '',
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
          token: decrypted['token'] ?? '',
          channelName: decrypted['channelName'] ?? '',
          members: [data['callerId'], data['receiverId']].cast<String>(),
        ));
      }
      return out;
    });
  }
}
