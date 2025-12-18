// lib/crypto/media_helper.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MediaHelper {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AesGcm _aes = AesGcm.with256bits();

  // -------------------------
  // helpers
  // -------------------------
  Future<Directory> _getTempDir() async => await getTemporaryDirectory();

  /// Generate a new random 32-byte content key
  Future<Uint8List> generateRandomContentKey() async {
    final k = await _aes.newSecretKey();
    final bytes = await k.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Encrypt file with provided 32-byte contentKey.
  Future<Map<String, dynamic>> encryptFileWithKey({
    required File file,
    required Uint8List contentKey,
    String? targetFilenamePrefix,
  }) async {
    final bytes = await file.readAsBytes();
    final nonce = _aes.newNonce();
    final encrypted = await _aes.encrypt(
      bytes,
      secretKey: SecretKey(contentKey),
      nonce: nonce,
    );

    final combined = Uint8List.fromList([...encrypted.cipherText, ...encrypted.mac.bytes]);
    final dir = await _getTempDir();
    final out = File('${dir.path}/${targetFilenamePrefix ?? 'enc'}_${DateTime.now().millisecondsSinceEpoch}.enc');
    await out.writeAsBytes(combined, flush: true);

    return {
      'cipherFile': out,
      'contentNonce': base64Encode(nonce),
      'encryptedBytes': combined, // optional
    };
  }

  /// Decrypt file with provided contentKey and contentNonce (base64)
  Future<File> decryptFileWithKey({
    required File cipherFile,
    required Uint8List contentKey,
    required String contentNonce, // base64
    String? outExtension,
  }) async {
    final encBytes = await cipherFile.readAsBytes();
    if (encBytes.length < 16) throw Exception('Encrypted file too short');

    final macBytes = encBytes.sublist(encBytes.length - 16);
    final cipherBytes = encBytes.sublist(0, encBytes.length - 16);
    final nonceBytes = base64Decode(contentNonce);

    final box = SecretBox(cipherBytes, nonce: nonceBytes, mac: Mac(macBytes));
    final plain = await _aes.decrypt(box, secretKey: SecretKey(contentKey));

    final dir = await _getTempDir();
    final outFile = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.${outExtension ?? 'jpg'}');
    await outFile.writeAsBytes(plain, flush: true);
    return outFile;
  }

  /// Download encrypted file from url to temp file.
  Future<File> downloadFileFromUrlToTemp(String url, {String? outName}) async {
    // Try storage ref writeToFile
    try {
      final ref = _storage.refFromURL(url);
      final dir = await _getTempDir();
      final out = File('${dir.path}/${outName ?? DateTime.now().millisecondsSinceEpoch}.enc');
      await out.create(recursive: true);
      final task = ref.writeToFile(out);
      await task.whenComplete(() => null);
      return out;
    } catch (_) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final dir = await _getTempDir();
      final out = File('${dir.path}/${outName ?? DateTime.now().millisecondsSinceEpoch}.enc');
      await out.writeAsBytes(res.bodyBytes, flush: true);
      return out;
    }
  }

  // -------------------------
  // encryptAndUpload (used by group repo)
  // -------------------------
  Future<Map<String, String>> encryptAndUpload({
    required File file,
    required Uint8List senderKey,
    required String groupId,
    required String folder,
  }) async {
    final bytes = await file.readAsBytes();
    final contentKeySecret = await _aes.newSecretKey();
    final contentKeyBytes = await contentKeySecret.extractBytes();
    final contentNonce = _aes.newNonce();

    final encMediaBox = await _aes.encrypt(
      bytes,
      secretKey: SecretKey(contentKeyBytes),
      nonce: contentNonce,
    );

    final mediaCombined = Uint8List.fromList([...encMediaBox.cipherText, ...encMediaBox.mac.bytes]);

    final path = 'groupsEncrypted/$groupId/$folder/${DateTime.now().millisecondsSinceEpoch}.enc';

    final uploadResult = await _storage.ref(path).putData(mediaCombined);
    final encUrl = await uploadResult.ref.getDownloadURL();

    final wrapNonce = _aes.newNonce();
    final wrapBox = await _aes.encrypt(
      contentKeyBytes,
      secretKey: SecretKey(senderKey),
      nonce: wrapNonce,
    );

    final wrappedCombined = Uint8List.fromList([...wrapBox.cipherText, ...wrapBox.mac.bytes]);

    return {
      'url': encUrl,
      'wrappedContentKey': base64Encode(wrappedCombined),
      'wrappedContentKeyNonce': base64Encode(wrapNonce),
      'contentNonce': base64Encode(contentNonce),
    };
  }

  // -------------------------
  // decryptAndSave (used by group chat)
  // -------------------------
  Future<File> decryptAndSave({
    required String encryptedUrl,
    required Uint8List senderKey,
    required String wrappedKey,
    required String mediaExt,
    required String wrappedNonce,
    required String contentNonce,
  }) async {
    final wrappedBytes = base64Decode(wrappedKey);
    final wrapNonceBytes = base64Decode(wrappedNonce);

    if (wrappedBytes.length < 16) throw Exception('wrapped key too short');

    final macBytes = wrappedBytes.sublist(wrappedBytes.length - 16);
    final cipherBytes = wrappedBytes.sublist(0, wrappedBytes.length - 16);

    final wrapBox = SecretBox(cipherBytes, nonce: wrapNonceBytes, mac: Mac(macBytes));
    final contentKeyBytes = await _aes.decrypt(wrapBox, secretKey: SecretKey(senderKey));

    Uint8List? mediaEnc;
    try {
      final ref = _storage.refFromURL(encryptedUrl);
      mediaEnc = await ref.getData(50 * 1024 * 1024); // 50MB
    } catch (e) {
      final res = await http.get(Uri.parse(encryptedUrl));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      mediaEnc = res.bodyBytes;
    }

    if (mediaEnc == null || mediaEnc.length < 16) throw Exception('Encrypted media invalid');

    final mediaMacBytes = mediaEnc.sublist(mediaEnc.length - 16);
    final mediaCipherBytes = mediaEnc.sublist(0, mediaEnc.length - 16);
    final mediaNonceBytes = base64Decode(contentNonce);

    final mediaBox = SecretBox(mediaCipherBytes, nonce: mediaNonceBytes, mac: Mac(mediaMacBytes));
    final plain = await _aes.decrypt(mediaBox, secretKey: SecretKey(contentKeyBytes));

    final dir = await _getTempDir();
    final outFile = File(
  '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$mediaExt',
);

    await outFile.writeAsBytes(plain, flush: true);
    return outFile;
  }
}
