// lib/crypto/decrypt_worker.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

/// args map (all strings):
/// {
///   'contentKeyB64': base64(contentKeyBytes),
///   'encryptedB64': base64(ciphertext||mac),
///   'nonceB64': base64(nonce),
///   'outExt': 'jpg' // optional
/// }
///
/// Returns: String path to written decrypted file.
Future<String> decryptInIsolate(Map<String, String> args) async {
  final contentKeyB64 = args['contentKeyB64'] ?? '';
  final encryptedB64 = args['encryptedB64'] ?? '';
  final nonceB64 = args['nonceB64'] ?? '';
  final outExt = args['outExt'] ?? 'jpg';

  final contentKey = base64Decode(contentKeyB64);
  final mediaEnc = base64Decode(encryptedB64);
  final nonce = base64Decode(nonceB64);

  if (mediaEnc.length < 16) {
    throw Exception('Encrypted payload too short');
  }

  final macBytes = mediaEnc.sublist(mediaEnc.length - 16);
  final cipherBytes = mediaEnc.sublist(0, mediaEnc.length - 16);

  final box = SecretBox(cipherBytes, nonce: nonce, mac: Mac(macBytes));
  final aes = AesGcm.with256bits();

  final plain = await aes.decrypt(box, secretKey: SecretKey(contentKey));

  final dir = await getTemporaryDirectory();
  final outFile = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$outExt');
  await outFile.writeAsBytes(plain, flush: true);
  return outFile.path;
}
