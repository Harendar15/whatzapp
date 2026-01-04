import 'dart:typed_data';
import '../media_e2e_helper.dart';

class MediaEncryptParams {
  final Uint8List plainBytes;

  MediaEncryptParams({required this.plainBytes});
}

Future<Map<String, String>> mediaEncryptIsolate(
  MediaEncryptParams p,
) async {
  return MediaE2eHelper.encryptBytes(
    plainBytes: p.plainBytes,
  );
}
