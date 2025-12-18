import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';

import 'crypto_utils.dart' as utils;
import 'aead.dart';

final _secure = const FlutterSecureStorage();
final _x25519 = X25519();

String _b64(Uint8List b) => base64Encode(b);
Uint8List _fromB64(String s) => Uint8List.fromList(base64Decode(s));

String canonicalPeer(String a, String b) {
  return a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';
}

class SessionRecord {
  final String myUid;
  final String peerId;
  final String rootKeyB64;
  final String sendChainKeyB64;
  final String recvChainKeyB64;
  final String myEphemeralPubB64;
  final String peerEphemeralPubB64;
  final String peerDeviceId;
  final int sendCount;
  final int recvCount;
  final String peerIdentityFingerprintB64;


  SessionRecord({
    required this.myUid,
    required this.peerId,
    required this.rootKeyB64,
    required this.sendChainKeyB64,
    required this.recvChainKeyB64,
    required this.myEphemeralPubB64,
    required this.peerDeviceId,
    required this.peerEphemeralPubB64,
    required this.peerIdentityFingerprintB64,
    this.sendCount = 0,
    this.recvCount = 0,
  });
Map<String, dynamic> toJson() => {
  'myUid': myUid,
  'peerId': peerId,
  'rootKey': rootKeyB64,
  'sendChainKey': sendChainKeyB64,
  'recvChainKey': recvChainKeyB64,
  'peerDeviceId': peerDeviceId,
  'myEphemeralPub': myEphemeralPubB64,
  'peerEphemeralPub': peerEphemeralPubB64,
  'peerIdentityFingerprintB64': peerIdentityFingerprintB64, // ✅ ADD
  'sendCount': sendCount,
  'recvCount': recvCount,
};

  static SessionRecord fromJson(Map<String, dynamic> m) {
    return SessionRecord(
      myUid: m['myUid'],
      peerId: m['peerId'],
      rootKeyB64: m['rootKey'],
      sendChainKeyB64: m['sendChainKey'],
      recvChainKeyB64: m['recvChainKey'],
      peerDeviceId: m['peerDeviceId'],
      myEphemeralPubB64: m['myEphemeralPub'],
      peerEphemeralPubB64: m['peerEphemeralPub'],
      peerIdentityFingerprintB64 : m['peerIdentityFingerprintB64'],
      sendCount: m['sendCount'] ?? 0,
      recvCount: m['recvCount'] ?? 0,
    );
  }

  SessionRecord copyWith({
    String? sendChainKeyB64,
    String? recvChainKeyB64,
    int? sendCount,
    int? recvCount,
  }) {
    return SessionRecord(
      myUid: myUid,
      peerId: peerId,
      rootKeyB64: rootKeyB64,
      sendChainKeyB64: sendChainKeyB64 ?? this.sendChainKeyB64,
      recvChainKeyB64: recvChainKeyB64 ?? this.recvChainKeyB64,
      myEphemeralPubB64: myEphemeralPubB64,
      peerEphemeralPubB64: peerEphemeralPubB64,
      peerDeviceId: peerDeviceId,
      peerIdentityFingerprintB64 : peerIdentityFingerprintB64,
      sendCount: sendCount ?? this.sendCount,
      recvCount: recvCount ?? this.recvCount,
    );
  }
}

String _sessionKey(String myUid, String peerId, String deviceId) {
  return 'session_${canonicalPeer(myUid, peerId)}_$deviceId';
}

Future<void> storeSession(SessionRecord r, String deviceId) async {
  await _secure.write(
    key: _sessionKey(r.myUid, r.peerId, deviceId),
    value: jsonEncode(r.toJson()),
  );
}

Future<SessionRecord?> loadSession(
  String myUid,
  String peerId,
  String deviceId,
) async {
  final raw = await _secure.read(
    key: _sessionKey(myUid, peerId, deviceId),
  );
  if (raw == null) return null;
  return SessionRecord.fromJson(jsonDecode(raw));
}

Future<SessionRecord> initSession({
  required String myUid,
  required String peerId,
  required KeyPair myKeyPair,
  required String deviceId,
  required String peerDeviceId,
  required SimplePublicKey peerPub,
}) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: myKeyPair,
    remotePublicKey: peerPub,
  );

  final bytes = await shared.extractBytes();
  final rc = await utils.hkdfRootAndChain(Uint8List.fromList(bytes));

  final pub = await myKeyPair.extractPublicKey() as SimplePublicKey;

 final root = rc['root']!;
final chain = rc['chain']!;

// derive two different chains from root
final sendChain = await utils.deriveChainKey(root, 'send');
final recvChain = await utils.deriveChainKey(root, 'recv');

final peerFingerprint =
    _b64(Uint8List.fromList(peerPub.bytes.sublist(0, 8)));

final record = SessionRecord(
  myUid: myUid,
  peerId: peerId,
  rootKeyB64: _b64(root),
  sendChainKeyB64: _b64(sendChain),
  recvChainKeyB64: _b64(recvChain),
  peerDeviceId: peerDeviceId,
  myEphemeralPubB64: _b64(Uint8List.fromList(pub.bytes)),
  peerEphemeralPubB64: _b64(Uint8List.fromList(peerPub.bytes)),
  peerIdentityFingerprintB64: peerFingerprint,
);



  await storeSession(record, deviceId);
  return record;
}

Future<Map<String, String>> encryptMessage(
  String myUid,
  String peerId,
  String deviceId,
  Uint8List plaintext,
) async {
  final s = await loadSession(myUid, peerId, deviceId);
  if (s == null) throw Exception('Session missing');
final chainKey = _fromB64(s.sendChainKeyB64);

final msgKey = await utils.deriveMessageKey(chainKey);
final nextChain = await utils.deriveNextChainKey(chainKey);

final payload = await encryptAesGcm(msgKey, plaintext);

await storeSession(
  s.copyWith(
    sendChainKeyB64: _b64(nextChain),
    sendCount: s.sendCount + 1,
  ),
  deviceId,
);



  return payload;
}

Future<Uint8List> decryptMessage(
  String myUid,
  String peerId,
  String deviceId,
  SimplePublicKey peerIdentityPub, // ✅ ADD THIS
  Map<String, String> payload,
) async {


  final s = await loadSession(myUid, peerId, deviceId);
  if (s == null) throw Exception('Session missing');
final chainKey = _fromB64(s.recvChainKeyB64);
final expectedFingerprint =
    _b64(Uint8List.fromList(peerIdentityPub.bytes.sublist(0, 8)));

if (s.peerIdentityFingerprintB64 != expectedFingerprint) {
  throw Exception('❌ Identity key changed — session invalid');
}

final msgKey = await utils.deriveMessageKey(chainKey);

final plain = await decryptAesGcm(
  msgKey,
  payload['ciphertext']!,
  payload['iv']!,
  payload['mac']!,
);

final nextChain = await utils.deriveNextChainKey(chainKey);

await storeSession(
  s.copyWith(
    recvChainKeyB64: _b64(nextChain),
    recvCount: s.recvCount + 1,
  ),
  deviceId,
);


  return plain;
}

Future<Map<String, String>> encryptMediaKey(
  String myUid,
  String peerId,
  String deviceId,
  Uint8List mediaKey,
) =>
    encryptMessage(myUid, peerId, deviceId, mediaKey);

Future<Uint8List> decryptMediaKey(
  String myUid,
  String peerId,
  String deviceId,
  SimplePublicKey peerIdentityPub,
  Map<String, String> payload,
) =>
    decryptMessage(
      myUid,
      peerId,
      deviceId,
      peerIdentityPub,
      payload,
    );


Future<void> clearSessionForPeer(String peerId) async {
  final keys = await _secure.readAll();
  for (final k in keys.keys) {
    if (k.contains(peerId)) {
      await _secure.delete(key: k);
    }
  }
}

