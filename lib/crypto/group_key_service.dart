// lib/crypto/group_key_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'group_key_helper.dart';
import 'identity_key_manager.dart';


final _secure = const FlutterSecureStorage();

String _groupKeyStorageKey(String groupId, String uid) =>
    'group_key_${groupId}_$uid';
Uint8List _u8(List<int> l) => Uint8List.fromList(l);

class GroupKeyService {
  final FirebaseFirestore firestore;

  final GroupKeyHelper helper;

  GroupKeyService({
    required this.firestore,
    GroupKeyHelper? helper,
  })  : helper = GroupKeyHelper(firestore: firestore);

  Future<Uint8List?> getCachedGroupKey(String groupId, String myUid) async {
    final keyB64 =
        await _secure.read(key: _groupKeyStorageKey(groupId, myUid));
    if (keyB64 == null) return null;
    try {
      return _u8(base64Decode(keyB64));
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheGroupKey(
      String groupId, String myUid, Uint8List key) async {
    await _secure.write(
      key: _groupKeyStorageKey(groupId, myUid),
      value: base64Encode(key),
    );
  }

  Future<void> removeCachedGroupKey(String groupId, String myUid) async {
    await _secure.delete(key: _groupKeyStorageKey(groupId, myUid));
  }

  Future<Uint8List> fetchAndDecryptGroupKey(
    String groupId,
    String myUid, {
    String deviceId = 'LocalStorage.getDeviceId()',
  }) async {
    final docRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('keys')
        .doc(myUid);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('No key document for this user in group.');
    }
    final data = snap.data()!;
    final encrypted = data['encrypted'];
    if (encrypted == null) {
      throw Exception('Key entry is pending (encrypted == null).');
    }

    final identity = IdentityKeyManager(firestore: firestore);

final localKeyPair =
    await identity.loadOrCreateIdentityKey(myUid, deviceId);


    final plaintext = await helper.decryptGroupKeyForMe(
      encryptedDoc: data,
      myKeyPair: localKeyPair,
    );

    await cacheGroupKey(groupId, myUid, plaintext);
    return plaintext;
  }

  Future<Uint8List> getOrFetchGroupKey(
    String groupId,
    String myUid, {
    String deviceId = 'LocalStorage.getDeviceId()',
  }) async {
    final cached = await getCachedGroupKey(groupId, myUid);
    if (cached != null) return cached;
    return await fetchAndDecryptGroupKey(
      groupId,
      myUid,
      deviceId: deviceId,
    );
  }
}
