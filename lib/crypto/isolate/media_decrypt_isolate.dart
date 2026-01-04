import 'dart:typed_data';
import '../media_e2e_helper.dart';

class MediaDecryptParams {
  final Uint8List encryptedBytes;
  final Uint8List mediaKey;
  final Uint8List nonce;

  MediaDecryptParams({
    required this.encryptedBytes,
    required this.mediaKey,
    required this.nonce,
  });
}

Future<Uint8List> mediaDecryptIsolate(
  MediaDecryptParams p,
) async {
  return MediaE2eHelper.decryptBytes(
    encryptedBytes: p.encryptedBytes,
    mediaKey: p.mediaKey,
    nonce: p.nonce,
  );
}
