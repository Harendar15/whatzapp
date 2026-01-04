import 'dart:typed_data';
import '../session_manager.dart' as sm;

/// ---------- PARAM ----------
class TextEncryptParams {
  final String myUid;
  final String peerUid;
  final String deviceId;
  final String peerDeviceId;
  final Uint8List plain;

  TextEncryptParams({
    required this.myUid,
    required this.peerUid,
    required this.deviceId,
    required this.peerDeviceId,
    required this.plain,
  });
}

/// ---------- ISOLATE ENTRY ----------
Future<Map<String, String>> encryptTextIsolate(
  TextEncryptParams params,
) async {
  return sm.encryptMessage(
    params.myUid,
    params.peerUid,
    params.deviceId,
    params.peerDeviceId,
    params.plain,
  );
}
