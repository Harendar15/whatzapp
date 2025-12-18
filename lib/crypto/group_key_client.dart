// lib/crypto/group_key_client.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert'; // ✅ REQUIRED for base64Encode

import 'group_sender_key_manager.dart';
import 'identity_key_manager.dart';

class GroupKeyClient {
  final FirebaseFirestore firestore;
  final GroupSenderKeyManager _gsk;
  final IdentityKeyManager _identity;

  GroupKeyClient({required this.firestore})
      : _gsk = GroupSenderKeyManager(firestore: firestore),
        _identity = IdentityKeyManager(firestore: firestore);

  Future<void> rotateGroupKeyAndPush({
    required String groupId,
    required String myUid,
    required Map<String, List<String>> member, // 🔐 TRUSTED ONLY
  }) async {
    final senderKey = await _gsk.generateSenderKey32();
    final keyId = const Uuid().v4();

    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc')
        .set({
      'senderKeyId': keyId,
      'rotatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final entry in member.entries) {
      final uid = entry.key;

      for (final deviceId in entry.value) {
        final pub = await _identity.fetchDevicePublicKey(uid, deviceId);
        if (pub == null) continue;

        final wrapped = await _gsk.wrapForRecipient(
          senderKey: senderKey,
          remoteDevicePubB64: base64Encode(pub.bytes),
        );

        await firestore
            .collection('groups')
            .doc(groupId)
            .collection('senderKeys')
            .doc('wrapped')
            .collection(uid)
            .doc(deviceId)
            .set({
          'keyId': keyId,
          'wrapped': wrapped['wrapped'],
          'nonce': wrapped['nonce'],
          'ephemeralPub': wrapped['ephemeralPub'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await _gsk.cacheSenderKeyLocally(
      groupId: groupId,
      keyId: keyId,
      senderKey: senderKey,
    );
  }
}
