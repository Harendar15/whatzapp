import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import '../../crypto/media_e2e_helper.dart';
import '../../models/chat_contact_model.dart';
import '../../models/community.dart';
import '../../models/group.dart';
import '../../helpers/local_storage.dart';
import '../../models/message.dart';
import '../../models/message_model.dart';
import '../../models/message_reply_model.dart';
import '../../models/user_model.dart';
import 'package:flutter/foundation.dart'; // ✅ REQUIRED
import 'package:path/path.dart' as p;

import '../notification/push_notification_controller.dart';
import '../storage/common_firebase_storage_repository.dart';

import '../../crypto/identity_key_manager.dart';
import '../../crypto/key_manager.dart';
import '../../crypto/session_manager.dart' as sm;

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  ),
);

class ChatRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Set<String> _sessionCache = {};


  ChatRepository({
    required this.firestore,
    required this.auth,
  });

  final _push = Get.put(PushNotificationController());

  User? get currentUser => auth.currentUser;

  // ============================================================
  // 🔐 SESSION (STRICT – NO FALLBACK)
  // ============================================================
   Future<void> _ensureSession({
    required String myUid,
    required String peerUid,
  }) async {
    final deviceId = LocalStorage.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw Exception('❌ DeviceId missing');
    }

    final sessionId = sm.canonicalPeer(myUid, peerUid);
    final cacheKey = '$sessionId-$deviceId';

    if (_sessionCache.contains(cacheKey)) return;

    final existing = await sm.loadSession(myUid, peerUid, deviceId);
    if (existing != null) {
      _sessionCache.add(cacheKey);
      return;
    }

    final identity = IdentityKeyManager(firestore: firestore);
    final keyManager = KeyManager(firestore: firestore);

    // 1️⃣ Ensure my identity exists
    await identity.loadOrCreateIdentityKey(myUid, deviceId);

    // 2️⃣ Load my DH keypair
    final SimpleKeyPair myKeyPair =
        await keyManager.loadLocalKeyPair(
      uid: myUid,
      deviceId: deviceId,
    );

        final deviceSnap = await firestore
          .collection('userKeys')
          .doc(peerUid)
          .collection('devices')
          .limit(1)
          .get();

      if (deviceSnap.docs.isEmpty) {
        throw Exception('❌ Peer has no registered device');
      }

      final deviceDoc = deviceSnap.docs.first;
      final peerDeviceId = deviceDoc.id;

      final peerPub = SimplePublicKey(
        base64Decode(deviceDoc['pubKey']),
        type: KeyPairType.x25519,
      );


      await sm.initSession(
        myUid: myUid,
        peerId: peerUid,
        myKeyPair: myKeyPair,
        deviceId: deviceId,
        peerDeviceId: peerDeviceId, // ✅ ADD
        peerPub: peerPub,
      );


    final verify = await sm.loadSession(myUid, peerUid, deviceId);
    if (verify == null) {
      throw Exception('❌ Session init failed');
    }

    _sessionCache.add(cacheKey);
  }


  /// ============================================================
  /// 🔓 DECRYPT MESSAGE (CLIENT ONLY)
  /// ============================================================
  Future<String?> decryptMessageForMe(Message m) async {
    if (m.ciphertext == null || m.iv == null || m.mac == null) return null;

    final myUid = currentUser?.uid;
    if (myUid == null) return null;

    final peerUid =
        m.senderId == myUid ? m.recieverid : m.senderId;

    try {
      await _ensureSession(
        myUid: myUid,
        peerUid: peerUid,
      );

     final identity = IdentityKeyManager(firestore: firestore);

// 🔐 fetch peer identity key
final SimplePublicKey? peerIdentityPub =
    await identity.fetchDevicePublicKey(
      peerUid,
      m.senderDeviceId, // ✅ MUST COME FROM MESSAGE
    );


if (peerIdentityPub == null) {
  throw Exception('❌ Peer identity key missing');
}

final plain = await sm.decryptMessage(
  myUid,
  peerUid,
  LocalStorage.getDeviceId()!,
  peerIdentityPub, // ✅ ADD THIS
  {
    'ciphertext': m.ciphertext!,
    'iv': m.iv!,
    'mac': m.mac!,
  },
);


      return utf8.decode(plain);
    } catch (e) {
  debugPrint('❌ Decrypt failed: $e');
  return null;
}

    }

  // ============================================================
  // 📡 STREAMS
  // ============================================================
  Stream<List<Message>> getChatStream(String otherUid) {
  final uid = currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return firestore
      .collection('users')
      .doc(uid)
      .collection('chats')
      .doc(otherUid)
      .collection('messages')
      .orderBy('timeSent')
      .snapshots()
      .asyncMap((snap) async {
        final out = <Message>[];

        for (final d in snap.docs) {
          final m = Message.fromMap(d.data());

          if (m.senderId == uid) {
            // ✅ OWN MESSAGE → show normally
            out.add(m);
          } else {
            // 🔐 RECEIVED MESSAGE → decrypt
            final plain = await decryptMessageForMe(m);
            out.add(
              plain != null ? m.copyWith(text: plain) : m,
            );
          }
        }
        return out;
      });
}


  Stream<List<Message>> getGroupChatStream(String groupId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('chats')
        .orderBy('timeSent')
        .snapshots()
        .map((s) => s.docs.map((d) => Message.fromMap(d.data())).toList());
  }

  Stream<List<Message>> getCommunityChats(String id) {
    return firestore
        .collection('community')
        .doc(id)
        .collection('chats')
        .orderBy('timeSent')
        .snapshots()
        .map((s) => s.docs.map((d) => Message.fromMap(d.data())).toList());
  }

  // ============================================================
  // 🚫 HARD BLOCK: NO PLAINTEXT IN 1-TO-1
  // ============================================================
  void _assertE2E({
    required bool isGroupChat,
    required bool isCommunityChat,
    required Map<String, String>? e2eEnvelope,
  }) {
    if (!isGroupChat && !isCommunityChat && e2eEnvelope == null) {
      throw Exception('❌ PLAINTEXT 1-TO-1 BLOCKED');
    }
  }

  // ============================================================
  // 💬 SAVE MESSAGE (STRICT)
  // ============================================================
 Future<void> _saveMessage({
  required String receiverId,
  required UserModel sender,
  required MessageModel type,
  required DateTime timeSent,
  required String messageId,
  required bool isGroupChat,
  required bool isCommunityChat,
  Map<String, String>? e2eEnvelope,
  String? fileUrl,
}) async {
  _assertE2E(
    isGroupChat: isGroupChat,
    isCommunityChat: isCommunityChat,
    e2eEnvelope: e2eEnvelope,
  );

  final map = {
    'senderId': sender.uid,
    'recieverid': receiverId,
    'text': '[encrypted]',
    'type': type.type,
    'timeSent': timeSent.millisecondsSinceEpoch,
    'messageId': messageId,
    'isSeen': false,
    'ciphertext': e2eEnvelope?['ciphertext'],
    'iv': e2eEnvelope?['iv'],
    'mac': e2eEnvelope?['mac'],
    'senderDeviceId': LocalStorage.getDeviceId(),

    'sessionId': e2eEnvelope?['sessionId'],
    'fileUrl': fileUrl,
    'deleted': false,
    'edited': false,
    'reactions': {},
  };


  final me = sender.uid;

  final batch = firestore.batch();

  final myRef = firestore
      .collection('users')
      .doc(me)
      .collection('chats')
      .doc(receiverId)
      .collection('messages')
      .doc(messageId);

  final peerRef = firestore
      .collection('users')
      .doc(receiverId)
      .collection('chats')
      .doc(me)
      .collection('messages')
      .doc(messageId);

  batch.set(myRef, map);
  batch.set(peerRef, map);

  await batch.commit();
}

  // ============================================================
  // 🔐 SAVE CHAT PREVIEW (NO LEAK)
  // ============================================================
  Future<void> _saveContactRows({
    required UserModel sender,
    required UserModel? receiver,
    required String receiverId,
    required DateTime timeSent,
    required bool isGroupChat,
  }) async {
    if (isGroupChat) return;

    final senderChat = ChatContactModel(
      name: receiver?.name ?? '',
      profilePic: receiver?.profilePic ?? '',
      contactId: receiverId,
      timeSent: timeSent,
      lastMessage: '[encrypted]',
      isHideChat: false,
    );

    final receiverChat = ChatContactModel(
      name: sender.name,
      profilePic: sender.profilePic,
      contactId: sender.uid,
      timeSent: timeSent,
      lastMessage: '[encrypted]',
      isHideChat: false,
    );

    await firestore
        .collection('users')
        .doc(sender.uid)
        .collection('chats')
        .doc(receiverId)
        .set(senderChat.toMap(), SetOptions(merge: true));

    await firestore
        .collection('users')
        .doc(receiverId)
        .collection('chats')
        .doc(sender.uid)
        .set(receiverChat.toMap(), SetOptions(merge: true));
  }

  // ============================================================
  // 🔐 SEND TEXT (1-TO-1 ONLY)
  // ============================================================
  Future<void> sendTextMessage({
    required BuildContext context,
    required String text,
    required String recieverUserId,
    required UserModel senderUser,
    required MessageReply? messageReply,
    required bool isGroupChat,
    required bool isCommunityChat,
  }) async {
    if (text.trim().isEmpty) return;

    if (isGroupChat || isCommunityChat) {
      throw Exception('Use group/community repo');
    }

    final myUid = senderUser.uid;
    final now = DateTime.now();
    final messageId = const Uuid().v1();

    await _ensureSession(
      myUid: myUid,
      peerUid: recieverUserId,
    );

    final payload = await sm.encryptMessage(
      myUid,
      recieverUserId,
      LocalStorage.getDeviceId()!,

      Uint8List.fromList(utf8.encode(text)),
    );
    final e2e = {
      'ciphertext': payload['ciphertext']!,
      'iv': payload['iv']!,
      'mac': payload['mac']!,
      'sessionId': sm.canonicalPeer(myUid, recieverUserId),

    };

    _assertE2E(
      isGroupChat: false,
      isCommunityChat: false,
      e2eEnvelope: e2e,
    );

    // final map = {
    //   'senderId': myUid,
    //   'recieverid': recieverUserId,
    //   'text': '[encrypted]',
    //   'type': MessageModel.text.type,
    //   'timeSent': now.millisecondsSinceEpoch,
    //   'messageId': messageId,
    //   'isSeen': false,
    //   ...e2e,
    //   'deleted': false,
    //   'edited': false,
    //   'reactions': {},
    // };


    await _saveMessage(
      receiverId: recieverUserId,
      sender: senderUser,
      type: MessageModel.text,
      timeSent: now,
      messageId: messageId,
      isGroupChat: false,
      isCommunityChat: false,
      e2eEnvelope: e2e,
    );

    await _saveContactRows(
      sender: senderUser,
      receiver: null,
      receiverId: recieverUserId,
      timeSent: now,
      isGroupChat: false,
    );

   await _push.sendChatPush(
  uid: recieverUserId,
  title: senderUser.name,
  body: 'New message',
  data: {
    'type': 'chat',
    'senderUid': senderUser.uid,
  },
);

  }
  void clearSessionCacheFor(String peerUid) {
  _sessionCache.removeWhere((k) => k.contains(peerUid));
}

  // ============================================================
  // 📎 SEND FILE (NOT E2E YET – STORED SAFELY)
  // ============================================================
  Future<void> sendFileMessage({
  required BuildContext context,
  required File file,
  required String recieverUserId,
  required UserModel senderUserData,
  required Ref ref,
  required MessageModel messageEnum,
  required MessageReply? messageReply,
  required bool isGroupChat,
  required bool isCommunityChat,
    }) async {
      if (!isGroupChat && !isCommunityChat) {
      final myUid = senderUserData.uid;
      final now = DateTime.now();
      final messageId = const Uuid().v1();
      

      await _ensureSession(
        myUid: myUid,
        peerUid: recieverUserId,
      );

      // 1️⃣ Read file
      final bytes = await file.readAsBytes();

      // 2️⃣ Encrypt media
      final enc = await MediaE2eHelper.encryptBytes(
        plainBytes: bytes,
      );

      // 3️⃣ Encrypt mediaKey using E2E
      final wrappedKey = await sm.encryptMediaKey(
        myUid,
        recieverUserId,
        LocalStorage.getDeviceId()!,
        base64Decode(enc['mediaKeyB64']!),
      );

      // 4️⃣ Upload encrypted bytes
      final storage = ref.read(commonFirebaseStorageRepositoryProvider);
      final url = await storage.storeBytesToFirebase(
        'chatMedia/$myUid/$messageId.enc',
        base64Decode(enc['cipherBytesB64']!),
      );

      // 5️⃣ Save message (NO PLAINTEXT)
      await _saveMessage(
        receiverId: recieverUserId,
        sender: senderUserData,
        type: messageEnum,
        timeSent: now,
        messageId: messageId,
        isGroupChat: false,
        isCommunityChat: false,
        e2eEnvelope: {
          'ciphertext': wrappedKey['ciphertext']!,
          'iv': wrappedKey['iv']!,
          'mac': wrappedKey['mac']!,
          'mediaNonceB64': enc['mediaNonceB64']!,
        },
        fileUrl: url,
      );
      await _saveContactRows(
        sender: senderUserData,
        receiver: null,
        receiverId: recieverUserId,
        timeSent: now,
        isGroupChat: false,
      );
      await _push.sendChatPush(
      uid: recieverUserId,
      title: senderUserData.name,
      body: 'Sent you a file',
      data: {
        'type': 'chat',
        'senderUid': senderUserData.uid,
      },
    );


      
    }
    }
    
  // ============================================================
  // 👀 SEEN
  // ============================================================
  Future<void> setChatMessageSeen(
      BuildContext? context, String otherUid, String messageId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    await firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(otherUid)
        .collection('messages')
        .doc(messageId)
        .update({'isSeen': true});

    await firestore
        .collection('users')
        .doc(otherUid)
        .collection('chats')
        .doc(uid)
        .collection('messages')
        .doc(messageId)
        .update({'isSeen': true});
  }
  
  // ============================================================
  // 😀 REACTIONS (SAFE)
  // ============================================================
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String uid,
  }) async {
    final me = auth.currentUser?.uid;
    if (me == null) return;

    final doc = firestore
        .collection('users')
        .doc(me)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snap = await doc.get();
    if (!snap.exists) return;

    final reactions =
        Map<String, dynamic>.from(snap.data()?['reactions'] ?? {});
    final list = List<String>.from(reactions[emoji] ?? []);

    await doc.update({
      'reactions.$emoji': list.contains(uid)
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid])
    });

    await firestore
        .collection('users')
        .doc(chatId)
        .collection('chats')
        .doc(me)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$emoji': list.contains(uid)
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid])
    });
  }

  // ============================================================
  // 🗑 DELETE (NO PLAINTEXT)
  // ============================================================
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    bool isGroup = false,
  }) async {
    final me = auth.currentUser?.uid;
    if (me == null) return;

    final update = {'deleted': true, 'text': '[deleted]'};

    await firestore
        .collection('users')
        .doc(me)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update(update);

    await firestore
        .collection('users')
        .doc(chatId)
        .collection('chats')
        .doc(me)
        .collection('messages')
        .doc(messageId)
        .update(update);
  }

  // ============================================================
  // 🚫 EDIT = RE-ENCRYPT
  // ============================================================
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
    required String otherUid,
    bool isGroup = false,
  }) async {
    if (isGroup) return;

    final myUid = auth.currentUser!.uid;

    await _ensureSession(
      myUid: myUid,
      peerUid: otherUid,
    );

    final payload = await sm.encryptMessage(
      myUid,
      otherUid,
      LocalStorage.getDeviceId()!,
      Uint8List.fromList(utf8.encode(newText)),
    );

    final update = {
      'text': '[encrypted]',
      'ciphertext': payload['ciphertext'],
      'iv': payload['iv'],
      'mac': payload['mac'],
      'edited': true,
    };

    await firestore
        .collection('users')
        .doc(myUid)
        .collection('chats')
        .doc(otherUid)
        .collection('messages')
        .doc(messageId)
        .update(update);

    await firestore
        .collection('users')
        .doc(otherUid)
        .collection('chats')
        .doc(myUid)
        .collection('messages')
        .doc(messageId)
        .update(update);
  }

Future<File> decryptMediaForMe(Message m) async {
  if (m.senderDeviceId.isEmpty) {
    throw Exception('❌ senderDeviceId missing');
  }

  if (m.fileUrl == null ||
      m.ciphertext == null ||
      m.iv == null ||
      m.mac == null ||
      m.mediaNonceB64 == null) {
    throw Exception('❌ Invalid encrypted media message');
  }

  final myUid = currentUser!.uid;
  final peerUid =
      m.senderId == myUid ? m.recieverid : m.senderId;

  // 🔐 ensure session
  final existing =
      await sm.loadSession(myUid, peerUid, LocalStorage.getDeviceId()!);

  if (existing == null) {
    await _ensureSession(myUid: myUid, peerUid: peerUid);
  }

  // 🔑 decrypt media key
  final peerPub = await IdentityKeyManager(firestore: firestore)
      .fetchDevicePublicKey(peerUid, m.senderDeviceId);

  final mediaKey = await sm.decryptMediaKey(
    myUid,
    peerUid,
    LocalStorage.getDeviceId()!,
    peerPub!,
    {
      'ciphertext': m.ciphertext!,
      'iv': m.iv!,
      'mac': m.mac!,
    },
  );

  // 📥 download encrypted bytes
  final req = await HttpClient().getUrl(Uri.parse(m.fileUrl!));
  final res = await req.close();
  final encryptedBytes =
      await consolidateHttpClientResponseBytes(res);

  // 🔓 decrypt media bytes
      final Uint8List plainBytes = await MediaE2eHelper.decryptBytes(
        encryptedBytes: encryptedBytes,
        mediaKey: mediaKey,
        nonce: base64Decode(m.mediaNonceB64!),
      );


  // 📁 SAVE AS TEMP FILE
  final dir = await getTemporaryDirectory();

  final ext = m.type.isImage
      ? 'jpg'
      : m.type.isVideo
          ? 'mp4'
          : m.type.isAudio
              ? 'aac'
              : 'bin';

  final file = File(
    '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$ext',
  );

  await file.writeAsBytes(plainBytes, flush: true);

  // ✅ RETURN FILE (IMPORTANT)
  return file;
}

  // ============================================================
  // 🔒 BLOCK
  // ============================================================
  Future<void> blockUser(String targetUid) async {
    final myUid = auth.currentUser!.uid;
    await firestore
      .collection('users')
      .doc(myUid)
      .collection('blocked')
      .doc(targetUid)
      .set({'at': FieldValue.serverTimestamp()});

  }

  Future<void> unblockUser(String targetUid) async {
    final myUid = auth.currentUser!.uid;
    await firestore.collection('users').doc(myUid).update({
      'blocked': FieldValue.arrayRemove([targetUid])
    });
  }

  Stream<bool> isBlocked(String targetUid) {
    final myUid = auth.currentUser!.uid;
    return firestore.collection('users').doc(myUid).snapshots().map((s) {
      final list = List<String>.from(s.data()?['blocked'] ?? []);
      return list.contains(targetUid);
    });
  }

  // ============================================================
  // 📚 CHAT LISTS
  // ============================================================
  Stream<List<ChatContactModel>> getChatContacts() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy("timeSent", descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatContactModel> contacts = [];
      for (var doc in snapshot.docs) {
        final chatContact = ChatContactModel.fromMap(doc.data());
        final userSnap =
            await firestore.collection('users').doc(chatContact.contactId).get();
        if (!userSnap.exists) continue;
        final user = UserModel.fromMap(userSnap.data()!);
        contacts.add(chatContact.copyWith(
          name: user.name,
          profilePic: user.profilePic,
        ));
      }
      return contacts;
    });
  }

Stream<List<Group>> getChatGroups() {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  return FirebaseFirestore.instance
      .collection('groups')
      .where('membersUid', arrayContains: uid) // 🔐 MAIN FIX
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) {
        return snap.docs.map((d) {
          return Group.fromMap(d.data());
        }).toList();
      });
}


  Stream<List<Group>> getChatGroupsId(List<String> ids) {
    if (ids.isEmpty) return const Stream.empty();
    return firestore
        .collection('groups')
        .where('groupId', whereIn: ids)
        .snapshots()
        .map((s) => s.docs.map((d) => Group.fromMap(d.data())).toList());
  }

  Stream<List<Community>> getCommunity() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return firestore
        .collection('community')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Community.fromMap(d.data()))
            .where((c) => c.membersUid.contains(uid))
            .toList());
  }

  Stream<List<Community>> getCommunityById() {
    final id = LocalStorage.getCommunityID();
    if (id.isEmpty) return const Stream.empty();

    return firestore
        .collection('community')
        .where('communityId', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => Community.fromMap(d.data())).toList());
  }
}
