import 'session_manager.dart' as sm;
import 'identity_key_manager.dart';
import '../helpers/local_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_guard.dart';
import 'package:flutter/foundation.dart';

Future<void> ensureSessionForPeer({
  required FirebaseFirestore firestore,
  required String myUid,
  required String peerUid,
  required String peerDeviceId,
}) async {
  final deviceId = LocalStorage.getDeviceId();
  if (deviceId == null || deviceId.isEmpty) {
    throw Exception('DeviceId missing');
  }

  // 🔒 SESSION LOCK (ISSUE-4 FIX)
  await SessionGuard.run(
    key: '$myUid-$peerUid-$peerDeviceId',
    action: () async {
      final session = await sm.loadSession(
      myUid,
      peerUid,
      deviceId,
      peerDeviceId,
    );


      // ✅ Correct session already exists
      if (session != null && session.peerDeviceId == peerDeviceId) {
        return;
      }

      // 🔥 Delete stale session
      if (session != null) {
        await sm.deleteSession(
          myUid,
          peerUid,
          deviceId,
          peerDeviceId,
        );

      }

      // 🔐 Recreate session
      final identity = IdentityKeyManager(firestore: firestore);
     final peerPub = await identity.fetchDevicePublicKey(peerUid, peerDeviceId);
      if (peerPub == null) {
        debugPrint(
          '⛔ Peer device key missing in Firestore '
          'peerUid=$peerUid device=$peerDeviceId',
        );
        return; // 🔥 DO NOT TRY SESSION
      }


      // 🔑 THIS IS YOUR IDENTITY KEYPAIR
      final myKeyPair = await identity.loadOrCreateIdentityKey(
        myUid,
        deviceId,
      );

      await sm.initSession(
        myUid: myUid,
        peerId: peerUid,
        myIdentityKeyPair: myKeyPair,
        deviceId: deviceId,
        peerDeviceId: peerDeviceId,
        peerIdentityPub: peerPub,
      );

    },
  );
}
