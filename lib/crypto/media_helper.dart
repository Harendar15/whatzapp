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

  Future<Directory> _getTempDir() async => getTemporaryDirectory();

  /// Generate random 32-byte content key
  Future<Uint8List> generateRandomContentKey() async {
    final key = await _aes.newSecretKey();
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Encrypt file using provided AES key
  Future<Map<String, dynamic>> encryptFileWithKey({
    required File file,
    required Uint8List contentKey,
    String? targetFilenamePrefix,
  }) async {
    final bytes = await file.readAsBytes();
    final nonce = _aes.newNonce();

    final encrypted = await _aes.encrypt(
      bytes,
      secretKey: SecretKeyData(contentKey), // ✅ FIX
      nonce: nonce,
    );

    final combined = Uint8List.fromList([
      ...encrypted.cipherText,
      ...encrypted.mac.bytes,
    ]);

    final dir = await _getTempDir();
    final out = File(
      '${dir.path}/${targetFilenamePrefix ?? 'enc'}_${DateTime.now().millisecondsSinceEpoch}.enc',
    );

    await out.writeAsBytes(combined, flush: true);

    return {
      'cipherFile': out,
      'contentNonce': base64Encode(nonce),
      'encryptedBytes': combined,
    };
  }

  /// Decrypt encrypted file
  Future<File> decryptFileWithKey({
    required File cipherFile,
    required Uint8List contentKey,
    required String contentNonce,
    String? outExtension,
  }) async {
    final encBytes = await cipherFile.readAsBytes();

    if (encBytes.length <= 16) {
      throw Exception('Invalid encrypted payload');
    }

    final macBytes = encBytes.sublist(encBytes.length - 16);
    final cipherBytes = encBytes.sublist(0, encBytes.length - 16);

    final box = SecretBox(
      cipherBytes,
      nonce: base64Decode(contentNonce),
      mac: Mac(macBytes),
    );

    final plain = await _aes.decrypt(
      box,
      secretKey: SecretKeyData(contentKey), // ✅ FIX
    );

    final dir = await _getTempDir();
    final out = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.${outExtension ?? 'bin'}',
    );

    await out.writeAsBytes(plain, flush: true);
    return out;
  }

  /// Download encrypted file to temp
  Future<File> downloadFileFromUrlToTemp(String url, {String? outName}) async {
    try {
      final ref = _storage.refFromURL(url);
      final dir = await _getTempDir();
      final out = File('${dir.path}/${outName ?? DateTime.now().millisecondsSinceEpoch}.enc');
      await ref.writeToFile(out);
      return out;
    } catch (_) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
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

  // 1️⃣ Generate per-file content key
  final contentKey = await _aes.newSecretKey();
  final contentKeyBytes = Uint8List.fromList(await contentKey.extractBytes());
  final contentNonce = _aes.newNonce();

  // 2️⃣ Encrypt media
  final encMediaBox = await _aes.encrypt(
    bytes,
    secretKey: SecretKeyData(contentKeyBytes), // ✅ FIX
    nonce: contentNonce,
  );

  final mediaCombined = Uint8List.fromList([
    ...encMediaBox.cipherText,
    ...encMediaBox.mac.bytes,
  ]);

  // 3️⃣ Upload encrypted bytes
  final path =
      'groupsEncrypted/$groupId/$folder/${DateTime.now().millisecondsSinceEpoch}.enc';
  final uploadResult = await _storage.ref(path).putData(mediaCombined);
  final encUrl = await uploadResult.ref.getDownloadURL();

  // 4️⃣ Wrap content key using senderKey
  final wrapNonce = _aes.newNonce();
  final wrapBox = await _aes.encrypt(
    contentKeyBytes,
    secretKey: SecretKeyData(senderKey), // ✅ FIX
    nonce: wrapNonce,
  );

  final wrappedCombined = Uint8List.fromList([
    ...wrapBox.cipherText,
    ...wrapBox.mac.bytes,
  ]);

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
  // 1️⃣ Unwrap content key
  final wrappedBytes = base64Decode(wrappedKey);
  if (wrappedBytes.length <= 16) {
    throw Exception('Invalid wrapped key');
  }

  final macBytes = wrappedBytes.sublist(wrappedBytes.length - 16);
  final cipherBytes = wrappedBytes.sublist(0, wrappedBytes.length - 16);

  final wrapBox = SecretBox(
    cipherBytes,
    nonce: base64Decode(wrappedNonce),
    mac: Mac(macBytes),
  );

  final contentKeyBytes = await _aes.decrypt(
    wrapBox,
    secretKey: SecretKeyData(senderKey), // ✅ FIX
  );

  // 2️⃣ Download encrypted media
  Uint8List mediaEnc;
  try {
    final ref = _storage.refFromURL(encryptedUrl);
    mediaEnc = (await ref.getData(50 * 1024 * 1024))!;
  } catch (_) {
    final res = await http.get(Uri.parse(encryptedUrl));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    mediaEnc = res.bodyBytes;
  }

  if (mediaEnc.length <= 16) {
    throw Exception('Invalid encrypted media');
  }

  // 3️⃣ Decrypt media
  final mediaMacBytes = mediaEnc.sublist(mediaEnc.length - 16);
  final mediaCipherBytes = mediaEnc.sublist(0, mediaEnc.length - 16);

  final mediaBox = SecretBox(
    mediaCipherBytes,
    nonce: base64Decode(contentNonce),
    mac: Mac(mediaMacBytes),
  );

  final plain = await _aes.decrypt(
    mediaBox,
    secretKey: SecretKeyData(contentKeyBytes), // ✅ FIX
  );

  // 4️⃣ Save file
  final dir = await _getTempDir();
  final outFile = File(
    '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$mediaExt',
  );

  await outFile.writeAsBytes(plain, flush: true);
  return outFile;
}

}
