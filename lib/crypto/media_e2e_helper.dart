import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class MediaE2eHelper {
  static final AesGcm _algo = AesGcm.with256bits();

  /// ------------------------------------------------------------
  /// 🔐 Encrypt raw media bytes (image / video)
  /// ------------------------------------------------------------
static Future<Map<String, dynamic>> encryptBytes({
  required Uint8List plainBytes,
}) async {

    // 1️⃣ random 256-bit media key
    final keyBytes = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    );
    final secretKey = SecretKey(Uint8List.fromList(keyBytes));

    // 2️⃣ random nonce
    final nonce = _algo.newNonce();

    // 3️⃣ AES-GCM encrypt
    final box = await _algo.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 4️⃣ store cipherText + MAC together (like WhatsApp)
    final combined = Uint8List.fromList(
      [...box.cipherText, ...box.mac.bytes],
    );

   return {
  'cipherBytesB64': base64Encode(combined),
  'mediaKey': Uint8List.fromList(await secretKey.extractBytes()), // 🔒 local only
  'mediaNonceB64': base64Encode(nonce),
};

  }

  /// ------------------------------------------------------------
  /// 🔓 Decrypt encrypted media bytes
  /// ------------------------------------------------------------
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
