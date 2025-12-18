// lib/crypto/crypto_utils.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'dart:math';

final _x25519 = X25519();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

Uint8List _toU8(List<int> l) => Uint8List.fromList(l);

Uint8List secureRandomBytes(int length) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
}
Future<Uint8List> deriveChainKey(
  Uint8List rootKey,
  String info,
) async {
  final hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  final secretKey = await hkdf.deriveKey(
    secretKey: SecretKey(rootKey),
    info: utf8.encode(info),
  );

  return Uint8List.fromList(await secretKey.extractBytes());
}
Future<Uint8List> deriveNextChainKey(Uint8List chainKey) async {
  final k = await _hkdf.deriveKey(
    secretKey: SecretKey(chainKey),
    info: utf8.encode('chain_step'),
    nonce: Uint8List(0),
  );
  return Uint8List.fromList(await k.extractBytes());
}

Future<Uint8List> x25519SharedSecret({
  required KeyPair myKeyPair,
  required SimplePublicKey theirPublic,
}) async {
  final secretKey = await _x25519.sharedSecretKey(
    keyPair: myKeyPair,
    remotePublicKey: theirPublic,
  );
  final bytes = await secretKey.extractBytes();
  return _toU8(bytes);
}

/// HKDF for cryptography 2.9.0: derive two separate 32-byte outputs (root and chain)
Future<Map<String, Uint8List>> hkdfRootAndChain(
  Uint8List sharedSecret, {
  Uint8List? salt,
}) async {
  final secretKey = SecretKey(sharedSecret);
  final nonce = salt ?? Uint8List(0);

  final k1 = await _hkdf.deriveKey(secretKey: secretKey, info: utf8.encode('hkdf-root'), nonce: nonce);
  final k2 = await _hkdf.deriveKey(secretKey: secretKey, info: utf8.encode('hkdf-chain'), nonce: nonce);

  final root = Uint8List.fromList(await k1.extractBytes());
  final chain = Uint8List.fromList(await k2.extractBytes());

  return {'root': root, 'chain': chain};
}

/// derive a 32-byte message key from chain key
Future<Uint8List> deriveMessageKey(Uint8List chainKey) async {
  final d = await _hkdf.deriveKey(secretKey: SecretKey(chainKey), nonce: Uint8List(0), info: utf8.encode('msg_key'));
  final out = await d.extractBytes();
  return Uint8List.fromList(out);
}
