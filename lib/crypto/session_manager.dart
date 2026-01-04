import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'aead.dart';

final _secure = const FlutterSecureStorage();
final _x25519 = X25519();
final Map<String, SessionRecord> _sessionCache = {};


void clearSessionCache() {
  _sessionCache.clear();
}

String _b64(Uint8List b) => base64Encode(b);
Uint8List _fromB64(String s) => Uint8List.fromList(base64Decode(s));

String canonicalPeer(String a, String b) =>
    a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';

Future<Uint8List> deriveMessageKey(Uint8List rootKey) async {
  final hmac = Hmac.sha256();

  final mac = await hmac.calculateMac(
    utf8.encode('msg'),
    secretKey: SecretKey(rootKey),
  );

  return Uint8List.fromList(mac.bytes);
}

class SessionRecord {
  final String myUid;
  final String peerId;
  final String myDeviceId;
  final String rootKeyB64;
  final String peerDeviceId;
  final int createdAt;



  SessionRecord({
    required this.myUid,
    required this.peerId,
    required this.myDeviceId,
    required this.rootKeyB64,
    required this.peerDeviceId,
    required this.createdAt,
  });

Map<String, dynamic> toJson() => {
  'myUid': myUid,
  'peerId': peerId,
  'myDeviceId': myDeviceId, // ✅ FIX
  'rootKey': rootKeyB64,
  'peerDeviceId': peerDeviceId,
  'createdAt': createdAt,
};

static SessionRecord fromJson(Map<String, dynamic> m) {
  final myUid = m['myUid'];
  final peerId = m['peerId'];
  final myDeviceId = m['myDeviceId'];
  final rootKey = m['rootKey'];
  final peerDeviceId = m['peerDeviceId'];
  final createdAt = m['createdAt'];
if (createdAt == null) throw const FormatException('Missing createdAt');


  if (myUid == null ||
      peerId == null ||
      myDeviceId == null ||
      rootKey == null ||
      peerDeviceId == null) {
    throw const FormatException('Corrupted session record');
  }

  return SessionRecord(
    myUid: myUid as String,
    peerId: peerId as String,
    myDeviceId: myDeviceId as String,
    rootKeyB64: rootKey as String,
    peerDeviceId: peerDeviceId as String,
    createdAt: createdAt as int,
  );
}
}
// String _sessionKey(String myUid, String peerId, String deviceId) {
//   return 'session_${canonicalPeer(myUid, peerId)}_$deviceId';
// }
bool isSessionExpired(SessionRecord s) {
  final age =
      DateTime.now().millisecondsSinceEpoch - s.createdAt;
  return age > const Duration(days: 7).inMilliseconds;
}


String _sessionKey(
  String myUid,
  String peerId,
  String myDeviceId,
  String peerDeviceId,
) {
  return 'session_${canonicalPeer(myUid, peerId)}_${myDeviceId}_$peerDeviceId';
}



Future<void> storeSession(SessionRecord r) async {
  await _secure.write(
    key: _sessionKey(r.myUid, r.peerId, r.myDeviceId, r.peerDeviceId),
    value: jsonEncode(r.toJson()),
  );
}

Future<SessionRecord?> loadSession(
  String myUid,
  String peerId,
  String myDeviceId,
  String peerDeviceId,
) async {
  final key = _sessionKey(myUid, peerId, myDeviceId, peerDeviceId);

  if (_sessionCache.containsKey(key)) {
    return _sessionCache[key];
  }

  final raw = await _secure.read(key: key);
  if (raw == null) return null;

  try {
  final record = SessionRecord.fromJson(jsonDecode(raw));

if (isSessionExpired(record)) {
  // 🔥 HARD DELETE expired session
  await _secure.delete(key: key);
  _sessionCache.remove(key);
  return null;
}

_sessionCache[key] = record;
return record;

  } catch (_) {
    await _secure.delete(key: key);
    _sessionCache.remove(key);
    return null;
  }
}




Future<SessionRecord> initSession({
  required String myUid,
  required String peerId,
  required KeyPair myIdentityKeyPair,
  required String deviceId,
  required String peerDeviceId,
  required SimplePublicKey peerIdentityPub,
}) async {
  // 🔑 STATIC DH
  final shared = await _x25519.sharedSecretKey(
    keyPair: myIdentityKeyPair,
    remotePublicKey: peerIdentityPub,
  );

  final rootKey = await shared.extractBytes();

  final record = SessionRecord(
    myUid: myUid,
    peerId: peerId,
    myDeviceId: deviceId,
    rootKeyB64: _b64(Uint8List.fromList(rootKey)),
    peerDeviceId: peerDeviceId,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );

  await storeSession(record);
  return record;
}

Future<Map<String, String>> encryptMessage(
  String myUid,
  String peerId,
  String myDeviceId,
  String peerDeviceId,
  Uint8List plaintext,


) async {
  final s = await loadSession(myUid, peerId, myDeviceId, peerDeviceId);
  if (s == null) throw Exception('Session missing');

final rootKey = _fromB64(s.rootKeyB64);
final msgKey = await deriveMessageKey(rootKey);
return encryptAesGcm(msgKey, plaintext);

}

Future<Uint8List> decryptMessage(
  String myUid,
  String peerId,
  String myDeviceId,
  String peerDeviceId,
  Map<String, String> payload,
)
 async {
  try {
    // Validate payload
    // if (!payload.containsKey('ciphertext') ||
    //     !payload.containsKey('iv') ||
    //     !payload.containsKey('mac')) {
    //   throw Exception(
    //     'Incomplete payload: missing ${[
    //       if (!payload.containsKey('ciphertext')) 'ciphertext',
    //       if (!payload.containsKey('iv')) 'iv',
    //       if (!payload.containsKey('mac')) 'mac',
    //     ].join(', ')}',
    //   );
    // }

    final s = await loadSession(myUid, peerId, myDeviceId, peerDeviceId);
    if (s == null) {
      throw Exception('Session missing for $myUid <-> $peerId');
    }

    final rootKey = _fromB64(s.rootKeyB64);
    if (rootKey.length != 32) {
      throw Exception(
        'Root key has invalid length: ${rootKey.length} (expected 32)',
      );
    }


final msgKey = await  deriveMessageKey(rootKey);
return await decryptAesGcm(
  msgKey,
  payload['ciphertext']!,
  payload['iv']!,
  payload['mac']!,
);

  } catch (e) {
  
  throw Exception('Decrypt failed: $e');
}

}
Future<void> deleteSession(
  String myUid,
  String peerUid,
  String myDeviceId,
  String peerDeviceId,
) async {
  final key = _sessionKey(
    myUid,
    peerUid,
    myDeviceId,
    peerDeviceId,
  );

  await _secure.delete(key: key);
  _sessionCache.remove(key);
}


// ✅ MEDIA KEY = NORMAL MESSAGE ENCRYPTION

Future<Map<String, String>> encryptMediaKey(
  String myUid,
  String peerId,
  String deviceId,
  String peerDeviceId,
  Uint8List mediaKey,
) async {
  return encryptMessage(
    myUid,
    peerId,
    deviceId,
    peerDeviceId,
    mediaKey,
  );
}


Future<Uint8List> decryptMediaKey(
  String myUid,
  String peerId,
  String deviceId,
  String peerDeviceId,
  Map<String, String> payload,
) async {
  return decryptMessage(
    myUid,
    peerId,
    deviceId,
    peerDeviceId,
    payload,
  );
}




