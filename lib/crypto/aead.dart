// lib/crypto/aead.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

final _aead = AesGcm.with256bits();

Uint8List _randomBytes(int len) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(len, (_) => rnd.nextInt(256)));
}

/// Encrypt AES-GCM (cryptography 2.9.0)
Future<Map<String, String>> encryptAesGcm(
  Uint8List key,
  Uint8List plaintext, {
  Uint8List? aad,
}) async {
  final secretKey = SecretKey(key);
  final nonce = _randomBytes(12); // 12-byte IV

  final secretBox = await _aead.encrypt(
    plaintext,
    secretKey: secretKey,
    nonce: nonce,
    aad: aad ?? Uint8List(0),
  );

  return {
    'ciphertext': base64Encode(secretBox.cipherText),
    'iv': base64Encode(secretBox.nonce),
    'mac': base64Encode(secretBox.mac.bytes),
  };
}

/// Decrypt AES-GCM
Future<Uint8List> decryptAesGcm(
  Uint8List key,
  String b64Cipher,
  String b64Iv,
  String b64Mac, {
  Uint8List? aad,
}) async {
  final box = SecretBox(
    base64Decode(b64Cipher),
    nonce: base64Decode(b64Iv),
    mac: Mac(base64Decode(b64Mac)),
  );

  final plain = await _aead.decrypt(
    box,
    secretKey: SecretKey(key),
    aad: aad ?? Uint8List(0),
  );

  return Uint8List.fromList(plain);
}
