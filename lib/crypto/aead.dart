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
  try {
    // Decode all components with validation
    final cipherBytes = base64Decode(b64Cipher);
    final nonceBytes = base64Decode(b64Iv);
    final macBytes = base64Decode(b64Mac);

    // Validate nonce length (must be 12 bytes for GCM)
    if (nonceBytes.length != 12) {
      throw Exception(
        'Invalid nonce length: ${nonceBytes.length} (expected 12)',
      );
    }

    // Validate MAC length (must be 16 bytes for AES-GCM)
    if (macBytes.length != 16) {
      throw Exception(
        'Invalid MAC length: ${macBytes.length} (expected 16). '
        'This usually means corrupted data or wrong key. '
        'b64Mac="$b64Mac", decoded=${macBytes.length} bytes',
      );
    }

    final box = SecretBox(
      cipherBytes,
      nonce: nonceBytes,
      mac: Mac(macBytes),
    );

    final plain = await _aead.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: aad ?? Uint8List(0),
    );

    return Uint8List.fromList(plain);
  } on SecretBoxAuthenticationError catch (e) {
    throw Exception(
      'SecretBox authentication failed: $e. '
      'This means the key or encrypted data is incorrect. '
      'Key length: ${key.length} bytes, '
      'Cipher length: ${base64Decode(b64Cipher).length} bytes, '
      'IV length: ${base64Decode(b64Iv).length} bytes, '
      'MAC length: ${base64Decode(b64Mac).length} bytes',
    );
  } catch (e) {
    throw Exception('Decryption error: $e');
  }
}
