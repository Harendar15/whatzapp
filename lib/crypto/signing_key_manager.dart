// lib/crypto/signing_key_manager.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SigningKeyManager {
  static const _privKeyPrefix = 'sign_sk_'; // sign_sk_{uid}_{deviceId}
  static const _pubKeyPrefix = 'sign_pk_'; // sign_pk_{uid}_{deviceId}

  final FlutterSecureStorage _storage;
  final Ed25519 _algo = Ed25519();

  SigningKeyManager({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage();

  String _privKeyName(String uid, String deviceId) => '$_privKeyPrefix${uid}_$deviceId';
  String _pubKeyName(String uid, String deviceId) => '$_pubKeyPrefix${uid}_$deviceId';

  Future<SimpleKeyPair> loadOrCreateSigningKey(String uid, String deviceId) async {
    final privKeyName = _privKeyName(uid, deviceId);
    final pubKeyName = _pubKeyName(uid, deviceId);

    final existingPriv = await _storage.read(key: privKeyName);
    final existingPub = await _storage.read(key: pubKeyName);

    if (existingPriv != null && existingPub != null) {
      final privBytes = base64Decode(existingPriv);
      final pubBytes = base64Decode(existingPub);

      return SimpleKeyPairData(
        Uint8List.fromList(privBytes),
        publicKey: SimplePublicKey(
          Uint8List.fromList(pubBytes),
          type: KeyPairType.ed25519,
        ),
        type: KeyPairType.ed25519,
      );
    }

    final kp = await _algo.newKeyPair();
    final privBytes = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    final bytes = pub.bytes;

    await _storage.write(key: privKeyName, value: base64Encode(privBytes));
    await _storage.write(key: pubKeyName, value: base64Encode(bytes));

    return SimpleKeyPairData(
      Uint8List.fromList(privBytes),
      publicKey: SimplePublicKey(
        Uint8List.fromList(bytes),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
  }

  Future<Uint8List> getPublicKeyBytes(String uid, String deviceId) async {
    final pubKeyName = _pubKeyName(uid, deviceId);
    final existingPub = await _storage.read(key: pubKeyName);
    if (existingPub != null) {
      return Uint8List.fromList(base64Decode(existingPub));
    }
    final kp = await loadOrCreateSigningKey(uid, deviceId);
    final pub = await kp.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }
}
