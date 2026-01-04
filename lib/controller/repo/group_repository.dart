// lib/controller/repo/group_repository.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/group.dart';
import '../../models/group_message_model.dart';
import '../../crypto/group_sender_key_manager.dart';
import '../../crypto/identity_key_manager.dart';
import '../../crypto/message_encryptor.dart';
import '../../crypto/media_helper.dart';
import '../../models/message_model.dart';
import '../storage/common_firebase_storage_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:adchat/models/user_model.dart';
import 'package:adchat/helpers/local_storage.dart';

final groupRepositoryProvider = Provider((ref) {
  return GroupRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

class GroupRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  final GroupSenderKeyManager _gskManager;
  final IdentityKeyManager _identity;
  final MessageEncryptor _encryptor;
  final MediaHelper _mediaHelper;

  GroupRepository({
    required this.firestore,
    required this.auth,
  })  : _gskManager = GroupSenderKeyManager(firestore: firestore),
        _identity = IdentityKeyManager(firestore: firestore),
        _encryptor = MessageEncryptor(),
        _mediaHelper = MediaHelper();

 Future<String> createGroup({
  required String name,
  required File? groupImage,
  required List<String> membersUid,
  required String creatorUid,
  String description = "",

  String? communityId,
  bool isAnnouncementGroup = false,
  }) async {
    if (membersUid.isEmpty) {
    throw Exception("membersUid cannot be empty");
  }

  final groupId = const Uuid().v1();

  // 🔥 Upload group image if provided
  String groupPicUrl = "";
  if (groupImage != null) {
    final storage = CommonFirebaseStorageRepository(
      firebaseStorage: FirebaseStorage.instance,
    );
    groupPicUrl = await storage.uploadGroupImage(groupId, groupImage);
  }
  final uniqueMembers = membersUid.toSet().toList();

  final group = {
    'senderId': creatorUid,
    'name': name,
    'groupId': groupId,
    'creatorUid': creatorUid,
    'groupPic': groupPicUrl.isEmpty 
      ? "https://i.ibb.co/2M4d1j6/user.png"  // default
      : groupPicUrl,        // ⭐ NOW REAL PIC
    'lastMessage': '',
    'membersUid': uniqueMembers,
    'timeSent': DateTime.now().millisecondsSinceEpoch,
    'admins': [creatorUid],
    'communityId': communityId,
    'description': description,
    'isAnnouncementGroup': isAnnouncementGroup,
  };

  await firestore.collection('groups').doc(groupId).set(group);

  // -------------------
  // 🔐 SENDER KEY SETUP
  // -------------------
  final senderKey = await _gskManager.generateSenderKey32();
  final keyId = const Uuid().v4();

  await firestore
      .collection('groups')
      .doc(groupId)
      .collection('meta')
      .doc('metaDoc')
      .set({
    'senderKeyId': keyId,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // distribute wrapped key to members
  for (final uid in membersUid) {
    final deviceMap = await _identity.fetchAllDevicePubMap(uid);
    if (deviceMap.isEmpty) {
      await firestore
          .collection('groups')
          .doc(groupId)
          .collection('senderKeys')
          .doc('wrapped')
          .collection(uid)
          .doc('pending')
          .set({
        'status': 'pending',
        'keyId': keyId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      continue;
    }

    final devId = deviceMap.keys.first;
    final devPub = deviceMap[devId]!;

    final wrapped = await _gskManager.wrapForRecipient(
      senderKey: senderKey,
      remoteDevicePubB64: devPub,
    );

    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('senderKeys')
        .doc('wrapped')
        .collection(uid)
        .doc(devId)
        .set({
      'status': 'ok',
      'keyId': keyId,
      'wrapped': wrapped['wrapped'],
      'nonce': wrapped['nonce'],
      'ephemeralPub': wrapped['ephemeralPub'],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  await _gskManager.cacheSenderKeyLocally(
    groupId: groupId,
    keyId: keyId,
    senderKey: senderKey,
  );

  return groupId;
}
Future<List<UserModel>> fetchGroupMembers(List<String> memberIds) async {
  List<UserModel> out = [];
  for (final uid in memberIds) {
    final snap = await firestore.collection("users").doc(uid).get();
    if (snap.exists) out.add(UserModel.fromMap(snap.data()!));
  }
  return out;
}

Future<void> promoteAdmin(String groupId, String uid) async {
  await firestore.collection("groups").doc(groupId).update({
    "admins": FieldValue.arrayUnion([uid])
  });
}

Future<void> demoteAdmin(String groupId, String uid) async {
  await firestore.collection("groups").doc(groupId).update({
    "admins": FieldValue.arrayRemove([uid])
  });
}

Future<void> exitGroup(String groupId) async {
  final myUid = auth.currentUser!.uid;

  await firestore.collection("groups").doc(groupId).update({
    "membersUid": FieldValue.arrayRemove([myUid]),
    "admins": FieldValue.arrayRemove([myUid]),
  });
}

Future<void> deleteGroup({
  required String groupId,
  required String myUid,
}) async {
  final ref = firestore.collection('groups').doc(groupId);
  final snap = await ref.get();

  if (!snap.exists) {
    throw Exception("Group not found");
  }

  final data = snap.data()!;
  final admins = List<String>.from(data['admins'] ?? []);

  // 🔐 ADMIN CHECK
  if (!admins.contains(myUid)) {
    throw Exception("Only admin can delete group");
  }

  // 🔥 DELETE GROUP (subcollections auto-clean recommended via Cloud Function)
  await ref.delete();
}


Future<void> addMemberWithE2E({
  required String groupId,
  required String newMemberUid,
 
}) async {
   String deviceId = LocalStorage.getDeviceId()!;
  // Step 1 — add to Firestore group membersUid[]
  final ref = firestore.collection('groups').doc(groupId);
  await ref.update({
    'membersUid': FieldValue.arrayUnion([newMemberUid]),
  });

  // Step 2 — load senderKey from local or wrapped copy
  final keySnap = await firestore
      .collection('groups')
      .doc(groupId)
      .collection('meta')
      .doc('metaDoc')
      .get();

  final metaData = keySnap.data();
if (metaData == null || metaData['senderKeyId'] == null) {
  throw Exception("Group sender key not initialized");
}
final keyId = metaData['senderKeyId'];

  if (keyId == null) throw Exception("No senderKeyId found");

  final myUid = auth.currentUser?.uid;
  if (myUid == null) {
    throw Exception("User not logged in");
  }


  final senderKey = await ensureSenderKeyCached(groupId, myUid, deviceId);
  if (senderKey == null) throw Exception("No senderKey available to wrap");

  // Step 3 — distribute to new member
  await _gskManager.distributeSenderKeyToNewMember(
    keyId: keyId,
    groupId: groupId,
    newMemberUid: newMemberUid,
    senderKey: senderKey,
  );
}


  Future<Uint8List?> ensureSenderKeyCached(
      String groupId, String myUid, String deviceId) async {
    final metaSnap = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc')
        .get();
    final meta = metaSnap.data();
    final keyId = meta?['senderKeyId'] as String?;
    if (keyId == null) return null;

    final cached =
        await _gskManager.readCachedSenderKey(groupId: groupId, keyId: keyId);
    if (cached != null) return cached;

    final doc = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('senderKeys')
        .doc('wrapped')
        .collection(myUid)
        .doc(deviceId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['wrapped'] == null) return null;

    final wrappedMap = {
      'wrapped': data['wrapped'],
      'nonce': data['nonce'],
      'ephemeralPub': data['ephemeralPub'],
    };

    final kp = await _identity.loadOrCreateIdentityKey(myUid, deviceId);
    final senderKey =
        await _gskManager.unwrapForRecipient(recipientKeyPair: kp, wrappedMap: wrappedMap);
    await _gskManager.cacheSenderKeyLocally(
      groupId: groupId,
      keyId: keyId,
      senderKey: senderKey,
    );
    return senderKey;
  }

  Future<void> sendTextMessage({
    required String groupId,
    required String message,
    required String senderName,
    required String senderDeviceId,

    // 🔹 optional reply metadata
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToTextPreview,
    String? replyToType,
  }) async {
    final uid = auth.currentUser!.uid;
    final senderKey =
        await ensureSenderKeyCached(groupId, uid, senderDeviceId);
    if (senderKey == null) throw Exception('senderKey missing');
    final deviceId = senderDeviceId.isNotEmpty
    ? senderDeviceId
    : LocalStorage.getDeviceId();

      if (deviceId == null) {
        throw Exception("DeviceId missing");
      }

 final enc = await _encryptor.encryptText(
  senderKey: senderKey,
  plaintext: message,
  aad: utf8.encode(groupId),
);


    final metaSnap = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc')
        .get();
    final meta = metaSnap.data();
    final keyId = meta?['senderKeyId'] ?? '';

    final messageId = const Uuid().v1();

    final gm = GroupMessage(
  messageId: messageId,
  groupId: groupId,
  senderId: uid,
  senderDeviceId: senderDeviceId,
  senderName: senderName,
  type: MessageModel.text, // FIXED ENUM
  ciphertext: enc['ciphertext'] ?? '',
  nonce: enc['nonce'] ?? '',
  mac: enc['mac'] ?? '',
  fileUrl: '',
  wrappedContentKey: '',
  wrappedContentKeyNonce: '',
  contentNonce: '',
  keyId: keyId,
  timeSent: DateTime.now().millisecondsSinceEpoch,
  seenBy: [],
  reactions: {},
  edited: false,
  deleted: false,

  // reply
  replyToMessageId: replyToMessageId,
  replyToSenderName: replyToSenderName,
  replyToTextPreview: replyToTextPreview,
  replyToType: replyToType?.toMessageModel(), // FIXED ENUM
);


    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .set(gm.toMap());

    await firestore.collection('groups').doc(groupId).update({
      'lastMessage': replyToMessageId == null ? '[encrypted]' : '↪ Reply',
      'timeSent': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // 🔥 decrypt helper (you already added this – kept as-is)
  Future<String> decryptTextMessage({
    required GroupMessage message,
    required String myUid,
    required String deviceId,
  }) async {
    try {
      final senderKey = await ensureSenderKeyCached(
        message.groupId,
        myUid,
        deviceId,
      );

      if (senderKey == null ||
          message.ciphertext.isEmpty ||
          message.nonce.isEmpty) {
        return "[encrypted]";
      }

      final plain = await _encryptor.decryptText(
  senderKey: senderKey,
  ciphertext: message.ciphertext,
  iv: message.nonce,
  mac: message.mac,
  aad: utf8.encode(message.groupId),
);



      return plain;
    } catch (e) {
      return "[failed to decrypt]";
    }
  }

  Future<void> sendMediaMessage({
    required String groupId,
    required File file,
    required String senderName,
    required MessageModel type,
    required String senderDeviceId,

    // 🔹 optional reply metadata
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToTextPreview,
    String? replyToType,
  }) async {
    final uid = auth.currentUser!.uid;
    final senderKey =
        await ensureSenderKeyCached(groupId, uid, senderDeviceId);
    if (senderKey == null) throw Exception('senderKey missing');
    final deviceId = senderDeviceId.isNotEmpty
    ? senderDeviceId
    : LocalStorage.getDeviceId();

    if (deviceId == null) {
      throw Exception("DeviceId missing");
    }

    final encryptedMedia = await _mediaHelper.encryptAndUpload(
      file: file,
      senderKey: senderKey,
      groupId: groupId,
      folder: type.type,
    );

    final messageId = const Uuid().v1();

    final metaSnap = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc')
        .get();
    final meta = metaSnap.data();
    final keyId = meta?['senderKeyId'] ?? '';
    final ext = file.path.split('.').last.toLowerCase();


    final gm = GroupMessage(
  messageId: messageId,
  groupId: groupId,
  senderId: uid,
  senderDeviceId: senderDeviceId,
  senderName: senderName,

  type: type, // FIXED ENUM
  mediaExt: ext,
  ciphertext: '',
  nonce: '',
  mac:  '',
  fileUrl: encryptedMedia['url'] ?? '',
  wrappedContentKey: encryptedMedia['wrappedContentKey'] ?? '',
  wrappedContentKeyNonce: encryptedMedia['wrappedContentKeyNonce'] ?? '',
  contentNonce: encryptedMedia['contentNonce'] ?? '',
  keyId: keyId,
  timeSent: DateTime.now().millisecondsSinceEpoch,
  seenBy: [],
  reactions: {},
  edited: false,
  deleted: false,

  replyToMessageId: replyToMessageId,
  replyToSenderName: replyToSenderName,
  replyToTextPreview: replyToTextPreview,
  replyToType: replyToType?.toMessageModel(), // FIXED ENUM
);


    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .set(gm.toMap());

    await firestore.collection('groups').doc(groupId).update({
      'lastMessage':
          replyToMessageId == null ? '[encrypted media]' : '↪ Reply',
      'timeSent': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<List<GroupMessage>> groupMessagesStream(String groupId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timeSent', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        return GroupMessage.fromMap(m);
      }).toList();
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> metaStream(String groupId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc')
        .snapshots();
  }

  Future<void> markMessageSeen({
    required String groupId,
    required String messageId,
    required String uid,
  }) async {
    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({'seenBy': FieldValue.arrayUnion([uid])});
  }

  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String uid,
  }) async {
    final ref = firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final existing = List<String>.from(reactions[emoji] ?? []);
    if (existing.contains(uid)) {
      await ref.update({
        'reactions.$emoji': FieldValue.arrayRemove([uid])
      });
    } else {
      await ref.update({
        'reactions.$emoji': FieldValue.arrayUnion([uid])
      });
    }
  }

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({'deleted': true, 'message': '[deleted]', 'fileUrl': ''});
  }

  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newText,
  }) async {
    final uid = auth.currentUser!.uid;
    final deviceId = LocalStorage.getDeviceId();
if (deviceId == null) throw Exception("DeviceId missing");
    final senderKey =
        await ensureSenderKeyCached(groupId, uid, deviceId);
    if (senderKey == null) throw Exception('senderKey missing');

    final enc =
        await _encryptor.encryptText(senderKey: senderKey, plaintext: newText);

    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'ciphertext': enc['ciphertext'],
      'nonce': enc['nonce'],
      'mac': enc['mac'], 
      'edited': true,
    });
  }

  Future<void> markNeedsRotation(String groupId, bool needs) async {
    final metaRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc');
    await metaRef.set({'needsRotation': needs}, SetOptions(merge: true));
  }

  Future<void> setAdmins(String groupId, List<String> admins) async {
    final metaRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc');
    await metaRef.set({'admins': admins}, SetOptions(merge: true));
  }

  Future<void> removeMember(String groupId, String memberUid) async {
    final groupRef = firestore.collection('groups').doc(groupId);
    final doc = await groupRef.get();
    if (!doc.exists) throw Exception('Group not found');

    final members = List<String>.from(doc.data()!['membersUid'] ?? []);
    members.remove(memberUid);

    await groupRef.update({'membersUid': members});

    // Remove their encrypted group key
    await firestore
  .collection('groups')
  .doc(groupId)
  .collection('senderKeys')
  .doc('wrapped')
  .collection(memberUid)
  .get()
  .then((snap) async {
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  });


    // mark that group key must be rotated
    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('meta')
        .doc('metaDoc')
        .set({'needsRotation': true}, SetOptions(merge: true));
  }
}
