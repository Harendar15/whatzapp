import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final X25519 _x25519 = X25519();
final FlutterSecureStorage _secure = const FlutterSecureStorage();

class KeyManager {
  final FirebaseFirestore firestore;
  KeyManager({required this.firestore});

  // ===============================
  // Storage keys
  // ===============================
  String _idPrivKey(String uid, String deviceId) => 'id_priv_${uid}_$deviceId';
  String _idPubKey(String uid, String deviceId) => 'id_pub_${uid}_$deviceId';
  String _dhKey(String uid, String deviceId) => 'dh_keypair_${uid}_$deviceId';

  // ===============================
  // IDENTITY KEY (LONG-TERM)
  // ===============================
  Future<void> generateIdentityKeypair({
    required String uid,
    required String deviceId,
  }) async {
    final keyPair = await _x25519.newKeyPair();

    final privBytes = await keyPair.extractPrivateKeyBytes();
    final pubKey = await keyPair.extractPublicKey();

    await _secure.write(
      key: _idPrivKey(uid, deviceId),
      value: base64Encode(privBytes),
    );

    await _secure.write(
      key: _idPubKey(uid, deviceId),
      value: base64Encode(pubKey.bytes),
    );
  }

  Future<SimplePublicKey?> getIdentityPublicKey({
    required String uid,
    required String deviceId,
  }) async {
    final b64 = await _secure.read(key: _idPubKey(uid, deviceId));
    if (b64 == null) return null;

    return SimplePublicKey(
      base64Decode(b64),
      type: KeyPairType.x25519,
    );
  }

  // ===============================
  // DH KEYPAIR (SESSION / RATCHET)
  // ===============================
  Future<SimpleKeyPairData> loadLocalKeyPair({
    required String uid,
    required String deviceId,
  }) async {
    final raw = await _secure.read(key: _dhKey(uid, deviceId));

    if (raw != null) {
      final map = jsonDecode(raw);
      return SimpleKeyPairData(
        base64Decode(map['private']),
        publicKey: SimplePublicKey(
          base64Decode(map['public']),
          type: KeyPairType.x25519,
        ),
        type: KeyPairType.x25519,
      );
    }

    // 🔐 Generate fresh DH keypair
    final keyPair = await _x25519.newKeyPair();
    final privBytes = await keyPair.extractPrivateKeyBytes();
    final pubKey = await keyPair.extractPublicKey();

    final data = SimpleKeyPairData(
      privBytes,
      publicKey: pubKey,
      type: KeyPairType.x25519,
    );

    await _secure.write(
      key: _dhKey(uid, deviceId),
      value: jsonEncode({
        'private': base64Encode(privBytes),
        'public': base64Encode(pubKey.bytes),
      }),
    );

    return data;
  }

  // ===============================
  // FIRESTORE PUBLISH
  // ===============================
  Future<void> publishPublicKeyToFirestore({
    required String uid,
    required String deviceId,
    String? platform,
    String? name,
  }) async {
    final pubKey = await getIdentityPublicKey(uid: uid, deviceId: deviceId);
    if (pubKey == null) {
      throw Exception('Identity key missing');
    }

    await firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'deviceId': deviceId,
      'publicKey': base64Encode(pubKey.bytes),
      'platform': platform ?? 'unknown',
      'name': name ?? deviceId,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
