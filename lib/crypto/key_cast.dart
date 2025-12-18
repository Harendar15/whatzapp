import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

Uint8List publicKeyBytes(PublicKey pub) {
  if (pub is SimplePublicKey) {
    return Uint8List.fromList(pub.bytes);
  }
  throw Exception('Unsupported PublicKey type');
}
