import 'dart:typed_data';
import '../session_manager.dart' as sm;

class TextDecryptParams {
  final String myUid;
  final String peerUid;
  final String deviceId;
  final String peerDeviceId;
  final Map<String, String> payload;

  TextDecryptParams({
    required this.myUid,
    required this.peerUid,
    required this.deviceId,
    required this.peerDeviceId,
    required this.payload,
  });
}

// ✅ TOP-LEVEL FUNCTION (compute-safe)
Future<Uint8List> decryptTextIsolate(TextDecryptParams p) async {
  return sm.decryptMessage(
    p.myUid,
    p.peerUid,
    p.deviceId,
    p.peerDeviceId,
    p.payload,
  );
}
