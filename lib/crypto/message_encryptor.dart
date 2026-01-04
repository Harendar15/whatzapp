import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class MessageEncryptor {
  final _algo = AesGcm.with256bits();

  Future<Map<String, String>> encryptText({
    required Uint8List senderKey,
    required String plaintext,
    Uint8List? aad,
  }) async {
    final secretKey = SecretKey(senderKey);
    final nonce = _algo.newNonce();

    final box = await _algo.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
      aad: aad ?? Uint8List(0),
    );

    return {
      'ciphertext': base64Encode(box.cipherText),
      'iv': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<String> decryptText({
    required Uint8List senderKey,
    required String ciphertext,
    required String iv,
    required String mac,
    Uint8List? aad,
  }) async {
    final box = SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(iv),
      mac: Mac(base64Decode(mac)),
    );

    final plain = await _algo.decrypt(
      box,
      secretKey: SecretKey(senderKey),
      aad: aad ?? Uint8List(0),
    );

    return utf8.decode(plain);
  }
}
