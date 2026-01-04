// lib/crypto/group_key_helper.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

import 'crypto_utils.dart' as utils;
import 'aead.dart';
import 'identity_key_manager.dart';

Uint8List _u8(List<int> l) => Uint8List.fromList(l);

class GroupKeyHelper {
  final FirebaseFirestore firestore;

  GroupKeyHelper({
    required this.firestore,

  });

  /// Generate 32-byte AES key
 // Generate 32-byte AES key using Random.secure()
Uint8List generateGroupKey() {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
}


  /// Fetch member’s first device public key


Future<SimplePublicKey?> fetchFirstDevicePublicKey(String uid) async {
  final identity = IdentityKeyManager(firestore: firestore);
  return await identity.fetchAnyDevicePublicKey(uid);
}


  /// Encrypt group key for member
  Future<Map<String, dynamic>> encryptKeyForMember({
  required Uint8List groupKey,
  required KeyPair myPrivateKeyPair,
  required SimplePublicKey memberPublic,
}) async {
  // 1. Compute shared secret
  final shared = await utils.x25519SharedSecret(
    myKeyPair: myPrivateKeyPair,
    theirPublic: memberPublic,
  );

  // 2. HKDF root key (AES key)
  final derived = await utils.hkdfRootAndChain(shared);
  final aesKey = derived['root']!;

  // 3. Encrypt the group key
  final encrypted = await encryptAesGcm(aesKey, groupKey);

  // 4. Extract sender public key safely
  final extractedPub = await myPrivateKeyPair.extractPublicKey();

  Uint8List pubBytes;

  // SimplePublicKey branch
  if (extractedPub is SimplePublicKey) {
    pubBytes = Uint8List.fromList(extractedPub.bytes);
  }
  // Dynamic fallback (rare)
  else if ((extractedPub as dynamic).bytes != null) {
    pubBytes = Uint8List.fromList((extractedPub as dynamic).bytes);
  } 
  else {
    throw Exception("Unable to extract public key bytes");
  }

  // 5. Return encrypted blob + sender public key
  return {
    "encrypted": encrypted,
    "senderPub": base64Encode(pubBytes),
  };
}


  /// Decrypt the stored group key for *this device*
  Future<Uint8List> decryptGroupKeyForMe({
    required Map encryptedDoc,
    required KeyPair myKeyPair,
  }) async {
    try {
      final senderPub = SimplePublicKey(
        base64Decode(encryptedDoc["senderPub"]),
        type: KeyPairType.x25519,
      );

      // Shared secret
      final shared = await utils.x25519SharedSecret(
        myKeyPair: myKeyPair,
        theirPublic: senderPub,
      );

      final derived = await utils.hkdfRootAndChain(shared);
      final aesKey = derived['root']!;

      final enc = encryptedDoc["encrypted"];

      final plain = await decryptAesGcm(
        aesKey,
        enc["ciphertext"],
        enc["iv"],
        enc["mac"],
      );

      return Uint8List.fromList(plain);
    } catch (e) {
      throw Exception("Group key decrypt ERROR → $e");
    }
  }
}
