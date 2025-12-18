import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'crypto_utils.dart' as cu;

class IdentityKeyManager {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore firestore;

  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final AesGcm _aead = AesGcm.with256bits();

  IdentityKeyManager({required this.firestore});

  String _seedKey(String uid, String deviceId) => 'id_seed_${uid}_$deviceId';

  // =========================================================
  // 🔐 IDENTITY KEY (LONG-TERM, DEVICE-BOUND)
  // =========================================================
  Future<SimpleKeyPair> loadOrCreateIdentityKey(
    String uid,
    String deviceId,
  ) async {
    final stored = await secureStorage.read(key: _seedKey(uid, deviceId));

    final Uint8List seed =
        stored != null ? base64Decode(stored) : cu.secureRandomBytes(32);

    if (stored == null) {
      await secureStorage.write(
        key: _seedKey(uid, deviceId),
        value: base64Encode(seed),
      );
    }

    final pair = await _x25519.newKeyPairFromSeed(seed);
    final pub = await pair.extractPublicKey();

    await firestore.collection('userKeys').doc(uid).set({
      'devices': {
        deviceId: {
          'pubKey': base64Encode(pub.bytes),
          'fingerprint': base64Encode(pub.bytes.sublist(0, 8)),
          'addedAt': FieldValue.serverTimestamp(),
        }
      }
    }, SetOptions(merge: true));

    return pair;
  }

  // =========================================================
  // 🔑 FETCH PEER DEVICE PUBLIC KEY (STRICT)
  // =========================================================
  Future<SimplePublicKey?> fetchDevicePublicKey(
    String uid,
    String deviceId,
  ) async {
    final doc = await firestore.collection('userKeys').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    final dev = data['devices']?[deviceId];
    if (dev == null || dev['pubKey'] == null) return null;

    return SimplePublicKey(
      base64Decode(dev['pubKey']),
      type: KeyPairType.x25519,
    );
  }

  // =========================================================
  // 📦 MEDIA KEY WRAPPING (FOR FILES / VOICE / STATUS)
  // =========================================================
  Future<Map<String, String>> wrapSymmetricKeyForRecipient({
    required Uint8List symmetricKey,
    required String recipientDevicePubB64,
  }) async {
    final eph = await _x25519.newKeyPair();
    final ephPub = await eph.extractPublicKey();

    final peerPub = SimplePublicKey(
      base64Decode(recipientDevicePubB64),
      type: KeyPairType.x25519,
    );

    final secret = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: peerPub,
    );

    final derived = await _hkdf.deriveKey(
      secretKey: secret,
      info: utf8.encode('media-wrap'),
    );

    final nonce = _aead.newNonce();
    final box = await _aead.encrypt(
      symmetricKey,
      secretKey: derived,
      nonce: nonce,
    );

    return {
      'wrapped': base64Encode([...box.cipherText, ...box.mac.bytes]),
      'nonce': base64Encode(nonce),
      'ephemeralPub': base64Encode(ephPub.bytes),
    };
  }
  // =========================================================
// 🔑 FETCH ANY DEVICE PUBLIC KEY (FOR SESSION INIT / VERIFY)
// =========================================================
Future<SimplePublicKey?> fetchAnyDevicePublicKey(String uid) async {
  final doc = await firestore.collection('userKeys').doc(uid).get();
  final data = doc.data();
  if (data == null) return null;

  final devices = data['devices'] as Map<String, dynamic>?;
  if (devices == null || devices.isEmpty) return null;

  // Pick first available device (Signal-style)
  final first = devices.values.first;
  final pubB64 = first['pubKey'];
  if (pubB64 == null) return null;

  return SimplePublicKey(
    base64Decode(pubB64),
    type: KeyPairType.x25519,
  );
}

  Future<Map<String, String>> fetchAllDevicePubMap(String uid) async {
  final doc = await firestore.collection('userKeys').doc(uid).get();
  final data = doc.data();
  if (data == null) return {};

  final devices = data['devices'] as Map<String, dynamic>? ?? {};
  final out = <String, String>{};

  for (final e in devices.entries) {
    if (e.value['pubKey'] != null) {
      out[e.key] = e.value['pubKey'];
    }
  }
  return out;
}

  Future<Uint8List> unwrapSymmetricKeyForMe({
    required String uid,
    required String deviceId,
    required Map<String, dynamic> wrapped,
  }) async {
   final seedB64 = await secureStorage.read(key: _seedKey(uid, deviceId));
final myPair = await _x25519.newKeyPairFromSeed(base64Decode(seedB64!));


    final ephPub = SimplePublicKey(
      base64Decode(wrapped['ephemeralPub']),
      type: KeyPairType.x25519,
    );

    final secret = await _x25519.sharedSecretKey(
      keyPair: myPair,
      remotePublicKey: ephPub,
    );

    final derived = await _hkdf.deriveKey(
      secretKey: secret,
      info: utf8.encode('media-wrap'),
    );

    final data = base64Decode(wrapped['wrapped']);
    final mac = data.sublist(data.length - 16);
    final cipher = data.sublist(0, data.length - 16);

    return Uint8List.fromList(
      await _aead.decrypt(
        SecretBox(
          cipher,
          nonce: base64Decode(wrapped['nonce']),
          mac: Mac(mac),
        ),
        secretKey: derived,
      ),
    );
  }
}
