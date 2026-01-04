import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class MediaE2eHelper {
  static final AesGcm _algo = AesGcm.with256bits();

  /// 🔐 Encrypt media bytes
  static Future<Map<String, String>> encryptBytes({
    required Uint8List plainBytes,
  }) async {
    // 1️⃣ Random 256-bit media key
    final secretKey = await _algo.newSecretKey();
    final mediaKeyBytes = await secretKey.extractBytes();

    // 2️⃣ Random nonce
    final nonce = _algo.newNonce();

    // 3️⃣ Encrypt
    final box = await _algo.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 4️⃣ Combine cipherText + MAC
    final combined = Uint8List.fromList(
      [...box.cipherText, ...box.mac.bytes],
    );

    return {
      'cipherBytesB64': base64Encode(combined),
      'mediaKeyB64': base64Encode(mediaKeyBytes),   // ✅ STRING
      'mediaNonceB64': base64Encode(nonce),         // ✅ STRING
    };
  }

  /// 🔓 Decrypt media bytes
  static Future<Uint8List> decryptBytes({
    required Uint8List encryptedBytes,
    required Uint8List mediaKey,
    required Uint8List nonce,
  }) async {
    if (encryptedBytes.length < 16) {
      throw Exception('Encrypted media too short');
    }

    final cipherText =
        encryptedBytes.sublist(0, encryptedBytes.length - 16);
    final macBytes =
        encryptedBytes.sublist(encryptedBytes.length - 16);

    final box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final plain = await _algo.decrypt(
      box,
      secretKey: SecretKey(mediaKey),
    );

    return Uint8List.fromList(plain);
  }
}
