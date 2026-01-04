import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Safely extract raw bytes from a PublicKey
Uint8List publicKeyBytes(PublicKey pub) {
  // ✅ Most common case
  if (pub is SimplePublicKey) {
    return Uint8List.fromList(pub.bytes);
  }

  // ✅ Fallback for dynamic implementations
  try {
    final dynamic d = pub;
    if (d.bytes != null) {
      return Uint8List.fromList(d.bytes as List<int>);
    }
  } catch (_) {}

  throw Exception(
    'Unsupported PublicKey type: ${pub.runtimeType}',
  );
}
