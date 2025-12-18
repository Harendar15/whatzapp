// lib/crypto/group_sender_key_manager.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_key_manager.dart';  // 🔥 ADD THIS

/// Manages group sender keys (WhatsApp-style):
///  - generate 32-byte senderKey
///  - wrap for each device using X25519 + AES-GCM
///  - cache locally using secure storage
class GroupSenderKeyManager {
  final FirebaseFirestore firestore;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 🔥 NEW: to fetch device public keys
  final IdentityKeyManager _identity;

  GroupSenderKeyManager({required this.firestore}): _identity = IdentityKeyManager(firestore: firestore);

  /// Generate random 32-byte sender key
  Future<Uint8List> generateSenderKey32() async {
    final rand = AesGcm.with256bits();
    final secret = await rand.newSecretKey();
    return Uint8List.fromList(await secret.extractBytes());
  }

  /// Local cache key name
  String _localKey(String groupId, String keyId) => 'gsk::$groupId::$keyId';

  /// Cache sender key locally (per groupId + keyId)
  Future<void> cacheSenderKeyLocally({
    required String groupId,
    required String keyId,
    required Uint8List senderKey,
  }) async {
    await _storage.write(
      key: _localKey(groupId, keyId),
      value: base64Encode(senderKey),
    );
  }
  Future<void> distributeSenderKeyToNewMember({
  required String keyId,
  required String groupId,
  required String newMemberUid,
  required Uint8List senderKey,
}) async {
  final deviceMap =
      await IdentityKeyManager(firestore: firestore)
          .fetchAllDevicePubMap(newMemberUid);

  if (deviceMap.isEmpty) {
    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('senderKeys')
        .doc('wrapped')
        .collection(newMemberUid)
        .doc('pending')
        .set({
      'status': 'pending',
      'keyId': keyId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return;
  }

  for (final entry in deviceMap.entries) {
    final deviceId = entry.key;
    final devicePub = entry.value;

    final wrapped = await wrapForRecipient(
      senderKey: senderKey,
      remoteDevicePubB64: devicePub,
    );

    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('senderKeys')
        .doc('wrapped')
        .collection(newMemberUid)
        .doc(deviceId)
        .set({
      'status': 'ok',
      'keyId': keyId,
      'wrapped': wrapped['wrapped'],
      'nonce': wrapped['nonce'],
      'ephemeralPub': wrapped['ephemeralPub'],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  /// Read sender key from local cache; return null if missing
  Future<Uint8List?> readCachedSenderKey({
    required String groupId,
    required String keyId,
  }) async {
    final v = await _storage.read(key: _localKey(groupId, keyId));
    if (v == null) return null;
    return Uint8List.fromList(base64Decode(v));
  }

  /// Wrap senderKey for recipient device using X25519 + AES-GCM.
  ///  - recipientPubB64 is base64(X25519 public key)
  /// Returns map { wrapped, nonce, ephemeralPub } all base64.
  Future<Map<String, String>> wrapForRecipient({
    required Uint8List senderKey,
    required String remoteDevicePubB64,
  }) async {
    final x25519 = X25519();

    // recipient public key
    final remotePub = SimplePublicKey(
      base64Decode(remoteDevicePubB64),
      type: KeyPairType.x25519,
    );

    // ephemeral keypair
    final eph = await x25519.newKeyPair();
    final ephPub = await eph.extractPublicKey();

    // shared secret
    final shared = await x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: remotePub,
    );
    final sharedBytes = await shared.extractBytes();

    // derive AES key from shared secret
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      info: utf8.encode('group-sender-key-wrap'),
    );
    final derivedBytes = await derived.extractBytes();

    final aes = AesGcm.with256bits();
    final nonce = aes.newNonce();

    final box = await aes.encrypt(
      senderKey,
      secretKey: SecretKey(derivedBytes),
      nonce: nonce,
    );

    final combined = Uint8List.fromList([
      ...box.cipherText,
      ...box.mac.bytes,
    ]);

    return {
      'wrapped': base64Encode(combined),
      'nonce': base64Encode(nonce),
      'ephemeralPub': base64Encode(await ephPub.bytes),
    };
  }

  /// Unwrap senderKey for recipient using their identity keypair.
  /// wrappedMap: { wrapped, nonce, ephemeralPub } (base64)
  Future<Uint8List> unwrapForRecipient({
    required KeyPair recipientKeyPair,
    required Map<String, dynamic> wrappedMap,
  }) async {
    final wrappedB64 = wrappedMap['wrapped'] as String;
    final nonceB64 = wrappedMap['nonce'] as String;
    final ephPubB64 = wrappedMap['ephemeralPub'] as String;

    final wrappedBytes = base64Decode(wrappedB64);
    final nonceBytes = base64Decode(nonceB64);
    final ephPubBytes = base64Decode(ephPubB64);

    final x25519 = X25519();
    final ephPub = SimplePublicKey(
      ephPubBytes,
      type: KeyPairType.x25519,
    );

    final shared = await x25519.sharedSecretKey(
      keyPair: recipientKeyPair,
      remotePublicKey: ephPub,
    );
    final sharedBytes = await shared.extractBytes();

    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      info: utf8.encode('group-sender-key-wrap'),
    );
    final derivedBytes = await derived.extractBytes();

    if (wrappedBytes.length < 16) {
      throw Exception('wrapped too short');
    }
    final macBytes = wrappedBytes.sublist(wrappedBytes.length - 16);
    final cipher = wrappedBytes.sublist(0, wrappedBytes.length - 16);

    final aes = AesGcm.with256bits();
    final box = SecretBox(
      cipher,
      nonce: nonceBytes,
      mac: Mac(macBytes),
    );

    final senderKeyBytes = await aes.decrypt(
      box,
      secretKey: SecretKey(derivedBytes),
    );

    return Uint8List.fromList(senderKeyBytes);
  }

  // 🔥 NEW — push existing senderKey to ONE new member (all their devices)
  
}
