// lib/crypto/message_encryptor.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Simple AES-GCM helper for encrypting/decrypting group text
class MessageEncryptor {
  final AesGcm _algo = AesGcm.with256bits();

  /// Encrypt a UTF-8 text string using the given 32-byte senderKey.
  /// Returns base64(ciphertext) and base64(nonce).
  Future<Map<String, String>> encryptText({
    required Uint8List senderKey,
    required String plaintext,
  }) async {
    final secretKey = SecretKey(senderKey);
    final nonce = _algo.newNonce();
    final plainBytes = utf8.encode(plaintext);

    final box = await _algo.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
      'nonce': base64Encode(nonce),
    };
  }

  /// Decrypt text previously encrypted with [encryptText].
  Future<String> decryptText({
    required Uint8List senderKey,
    required String ciphertextB64,
    required String nonceB64,
  }) async {
    final cipherBytes = base64Decode(ciphertextB64);
    final nonce = base64Decode(nonceB64);

    if (cipherBytes.length < 16) {
      throw Exception('Ciphertext too short');
    }

    final macBytes = cipherBytes.sublist(cipherBytes.length - 16);
    final realCipher = cipherBytes.sublist(0, cipherBytes.length - 16);

    final secretKey = SecretKey(senderKey);

    final box = SecretBox(
      realCipher,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final plainBytes = await _algo.decrypt(
      box,
      secretKey: secretKey,
    );

    return utf8.decode(plainBytes);
  }
}
