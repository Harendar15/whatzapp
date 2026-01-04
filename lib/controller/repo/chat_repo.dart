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
import '../../crypto/ensure_session_for_peer.dart';
import '../../crypto/session_guard.dart';
import '../notification/push_notification_controller.dart';
import '../storage/common_firebase_storage_repository.dart';
import '../../crypto/identity_key_manager.dart';
import '../../crypto/session_manager.dart' as sm;
import '../../crypto/message_queue.dart';
import '../../crypto/isolate/text_encrypt_isolate.dart';
import '../../crypto/isolate/text_decrypt_isolate.dart';
import '../../crypto/isolate/media_encrypt_isolate.dart';
import '../../crypto/isolate/media_decrypt_isolate.dart';
import '../../crypto/decrypt_queue.dart';

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  ),
);

class ChatRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Map<String, String> _decryptedCache = {};
  final Set<String> _decryptInProgress = {};
  final Set<String> _sessionEnsured = {};
  final MessageQueue _sendQueue = MessageQueue();
  final DecryptQueue _decryptQueue = DecryptQueue();





  ChatRepository({
    required this.firestore,
    required this.auth,
  });

  final _push = Get.put(PushNotificationController());

  User? get currentUser => auth.currentUser;
  bool _disposed = false;

    String getChatId(String a, String b) {
      return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
    }

  // ============================================================
  // 🔐 SESSION (STRICT – NO FALLBACK)
  // ============================================================
// Future<void> _ensureSession({
//   required String myUid,
//   required String peerUid,
// }) async {
//   final myDeviceId = LocalStorage.getDeviceId();
//   if (myDeviceId == null || myDeviceId.isEmpty) {
//     debugPrint('❌ DeviceId missing');
//     return;
//   }

 
  
//   // 2️⃣ Persistent session check
//   final existing = await sm.loadSession(myUid, peerUid, myDeviceId);
//   if (existing != null) {
  
//     debugPrint('✅ Existing session loaded with $peerUid');
//     return;
//   }

//   // 🚫 DO NOT CREATE SESSION HERE
//   debugPrint('⏳ No secure session yet with $peerUid');
//   return;
// }
  // ============================================================
// 📡 1-to-1 CHAT STREAM (WITH DECRYPT)
// ============================================================
Stream<List<Message>> getChatStream(String otherUid) {
  final user = auth.currentUser;
  if (user == null) return const Stream.empty();

  final myUid = user.uid;
  final chatId = getChatId(myUid, otherUid);

  return firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timeSent')
      .snapshots()
      .asyncMap((snap) async {
        final out = <Message>[];

        for (final d in snap.docs) {
          final m = Message.fromMap(d.data());

          // sender side → no decrypt
          if (m.senderId == myUid) {
            out.add(m);
            continue;
          }

          // receiver side → decrypt once
          if (!_decryptedCache.containsKey(m.messageId) &&
              !_decryptInProgress.contains(m.messageId)) {

            _decryptInProgress.add(m.messageId);

            _decryptQueue.enqueue(() async {
              if (_disposed) return;

              final plain = await decryptMessageForMe(m);
              if (plain != null) {
                _decryptedCache[m.messageId] = plain;
              }

              _decryptInProgress.remove(m.messageId);
            });
          }

          out.add(
            _decryptedCache.containsKey(m.messageId)
                ? m.copyWith(text: _decryptedCache[m.messageId]!)
                : m,
          );
        }

        return out;
      });
}


void clearE2ECaches() {
  _decryptedCache.clear();
  _decryptInProgress.clear();
  _sessionEnsured.clear();
}

void clearQueues() {
  _sendQueue.clear();
}

// void clearDecryptQueue() {
//   _decryptInProgress.clear();
//   _sessionEnsured.clear();
// }

void disposeRepo() {
  _disposed = true;

  _sendQueue.dispose();     // 🔥 CRITICAL
  _decryptQueue.dispose();  // 🔥 CRITICAL

  _decryptedCache.clear();
  _decryptInProgress.clear();
  _sessionEnsured.clear();
}

  /// ============================================================
  /// 🔓 DECRYPT MESSAGE (CLIENT ONLY)
  /// ============================================================
Future<String?> decryptMessageForMe(Message m) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⛔ decrypt skipped (user logged out)');
      return null;
    }

    final myUid = user.uid;
    final deviceId = LocalStorage.getDeviceId();

    if (deviceId == null || deviceId.isEmpty) {
      debugPrint('⛔ decrypt skipped (deviceId missing)');
      return null;
    }

    if (m.ciphertext == null || m.iv == null || m.mac == null) {
      debugPrint('⛔ decrypt skipped (invalid payload)');
      return null;
    }

    // base64 validation
    try {
      base64Decode(m.ciphertext!);
      base64Decode(m.iv!);
      base64Decode(m.mac!);
    } catch (_) {
      debugPrint('⛔ decrypt skipped (corrupted base64)');
      return null;
    }

    final peerUid =
        m.senderId == myUid ? (m.recieverid ?? '') : m.senderId;

    if (peerUid.isEmpty) {
      debugPrint('⛔ decrypt skipped (peerUid empty)');
      return null;
    }

    final senderDeviceId = m.senderDeviceId;
    if (senderDeviceId.isEmpty) {
      return null;
    }
    final identity = IdentityKeyManager(firestore: firestore);

    final peerPub = await identity.fetchDevicePublicKey(
      peerUid,
      senderDeviceId,
    );

    if (peerPub == null) {
      debugPrint('⛔ decrypt skipped: peer public key missing in Firestore');
      return null; // 👈 THIS IS THE FIX
    }


    final sessionKey = '$myUid-$peerUid-$senderDeviceId';

          if (!_sessionEnsured.contains(sessionKey)) {
            await SessionGuard.run(
              key: sessionKey,
              action: () async {
                await ensureSessionForPeer(
                  firestore: firestore,
                  myUid: myUid,
                  peerUid: peerUid,
                  peerDeviceId: senderDeviceId,
                );
              },
            );
            _sessionEnsured.add(sessionKey);
          }


  sm.SessionRecord? session = await sm.loadSession(
  myUid,
  peerUid,
  deviceId,
  senderDeviceId,
);

if (session == null) {
  await SessionGuard.run(
    key: 'rekey-$myUid-$peerUid-$senderDeviceId',
    action: () async {
      await ensureSessionForPeer(
        firestore: firestore,
        myUid: myUid,
        peerUid: peerUid,
        peerDeviceId: senderDeviceId,
      );
    },
  );

  session = await sm.loadSession(
    myUid,
    peerUid,
    deviceId,
    senderDeviceId,
  );
}

if (session == null) {
  debugPrint('⛔ decrypt skipped: session still missing');
  return null;
}

if (session.peerDeviceId != senderDeviceId) {
  debugPrint(
    '⛔ decrypt skipped: session-device mismatch '
    'expected=$senderDeviceId actual=${session.peerDeviceId}',
  );
  return null;
}

      if (m.senderDeviceId.isEmpty) {
  debugPrint('⛔ decrypt skipped (senderDeviceId empty)');
  return null;
}


    final plainBytes = await compute(
  decryptTextIsolate,
  TextDecryptParams(
    myUid: myUid,
    peerUid: peerUid,
    deviceId: deviceId,
    peerDeviceId: senderDeviceId,
    payload: {
      'ciphertext': m.ciphertext!,
      'iv': m.iv!,
      'mac': m.mac!,
    },
  ),
);

    if (plainBytes.isEmpty) return null;

    return utf8.decode(
      plainBytes,
      allowMalformed: true, // 🔥 CRITICAL
    );

  } catch (e) {
    debugPrint('⛔ decrypt skipped (MAC/session mismatch) :  $e');
    return null;
  }
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
  MessageReply? messageReply,
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
    'peerDeviceId': e2eEnvelope?['peerDeviceId'],
    'repliedMessage': messageReply?.message,
    'repliedTo': messageReply?.isMe == true
        ? sender.name
        : receiverId,
    'repliedMessageType': messageReply?.messageModel.type,
    'mediaNonceB64': e2eEnvelope?['mediaNonceB64'],
    'sessionId': e2eEnvelope?['sessionId'],
    'fileUrl': fileUrl,
    'deleted': false,
    'edited': false,
    'reactions': {},
  };



  final chatId = getChatId(sender.uid, receiverId);

await firestore
  .collection('chats')
  .doc(chatId)
  .collection('messages')
  .doc(messageId)
  .set(map);



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
  required String text,
  required String recieverUserId,
  required UserModel senderUser,
}) async {

  _sendQueue.enqueue(() async {
    final myUid = senderUser.uid;
    final deviceId = LocalStorage.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw Exception("DeviceId missing");
    }

    final chatId = getChatId(myUid, recieverUserId);
    final messageId = const Uuid().v4();

    final identity = IdentityKeyManager(firestore: firestore);
    final devices = await identity.fetchAllDevicePubMap(recieverUserId);
    if (devices.isEmpty) throw Exception('Peer has no devices');

    final peerDeviceId = devices.keys.first;

    await ensureSessionForPeer(
      firestore: firestore,
      myUid: myUid,
      peerUid: recieverUserId,
      peerDeviceId: peerDeviceId,
    );
          // 🔐 EXPLICIT SESSION CHECK (CRITICAL)
      final session = await sm.loadSession(
        myUid,
        recieverUserId,
        deviceId,
        peerDeviceId,
      );

      if (session == null) {
        throw Exception('E2E session missing after ensureSessionForPeer');
      }

    final payload = await compute(
      encryptTextIsolate,
      TextEncryptParams(
        myUid: myUid,
        peerUid: recieverUserId,
        deviceId: deviceId,
        peerDeviceId: peerDeviceId,
        plain: Uint8List.fromList(utf8.encode(text)),
      ),
    );

    await firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
          'senderId': myUid,
          'recieverid': recieverUserId,
          'ciphertext': payload['ciphertext'],
          'iv': payload['iv'],
          'mac': payload['mac'],
          'senderDeviceId': deviceId,
          'peerDeviceId': peerDeviceId,
          'text': '[encrypted]',
          'timeSent': FieldValue.serverTimestamp(),
          'messageId': messageId,
          'isSeen': false,
        });
  });
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
      _sendQueue.enqueue(() async {
      if (!isGroupChat && !isCommunityChat) {
      final myUid = senderUserData.uid;
      final now = DateTime.now();
      final messageId = const Uuid().v1();
           // 1️⃣ Read file
      final bytes = await file.readAsBytes();
      final deviceId = LocalStorage.getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        debugPrint('❌ sendFileMessage aborted: deviceId missing');
        return;
      }
      final identity = IdentityKeyManager(firestore: firestore);
      final devices = await identity.fetchAllDevicePubMap(recieverUserId);
      if (devices.isEmpty) {
        throw Exception('Peer has no devices');
      }
      final peerDeviceId = devices.entries.first.key;

      await ensureSessionForPeer(
      firestore: firestore,
      myUid: myUid,
      peerUid: recieverUserId,
      peerDeviceId: peerDeviceId, // ✅ CORRECT
    );


 final peerUid = recieverUserId;

  final session = await sm.loadSession(
    myUid,
    peerUid,
    deviceId,
    peerDeviceId,
  );


// if (session == null) {
//   final identity = IdentityKeyManager(firestore: firestore);

//   final peerDoc =
//       await firestore.collection('userKeys').doc(recieverUserId).get();
//   if (!peerDoc.exists) {
//     throw Exception('Peer has no identity keys');
//   }

//   final devices = peerDoc.data()!['devices'] as Map<String, dynamic>;
//   final peerDeviceId = devices.entries.first.key;

//   final peerPub =
//       await identity.fetchDevicePublicKey(recieverUserId, peerDeviceId);
//   if (peerPub == null) {
//     throw Exception('Peer public key missing');
//   }

//   final myKeyPair = await KeyManager(firestore: firestore)
//       .loadLocalKeyPair(uid: myUid, deviceId: deviceId);

//   session = await sm.initSession(
//     myUid: myUid,
//     peerId: recieverUserId,
//     myIdentityKeyPair: myKeyPair,
//     deviceId: deviceId,
//     peerDeviceId: peerDeviceId,
//     peerIdentityPub: peerPub,
//   );
// }


      if (session == null) {
        throw Exception('❌ No E2E session – cannot send message');
      }



      // 2️⃣ Encrypt media
   final enc = await compute(
  mediaEncryptIsolate,
  MediaEncryptParams(plainBytes: bytes),
);



      // 3️⃣ Encrypt mediaKey using E2E
     final wrappedKey = await sm.encryptMediaKey(
              myUid,
              recieverUserId,
              deviceId,
              peerDeviceId,
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
          'sessionId': sm.canonicalPeer(myUid, recieverUserId),
          'peerDeviceId': session.peerDeviceId,

        },
        fileUrl: url,
        messageReply: messageReply,
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
        'chatId': getChatId(senderUserData.uid, recieverUserId),
      },
    );

    };
    });
    }
  
  // ============================================================
  // 👀 SEEN
  // ============================================================
  Future<void> setChatMessageSeen(
  BuildContext? context,
  String otherUid,
  String messageId,
) async {
  final uid = currentUser?.uid;
  if (uid == null) return;

  try {
    final chatId = getChatId(uid, otherUid);

    final ref = firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snap = await ref.get();
    if (!snap.exists) return; // ✅ SAFETY

    // ✅ ONLY ONE UPDATE (single source of truth)
    await ref.update({'isSeen': true});

  } catch (e) {
    debugPrint('⚠️ setChatMessageSeen skipped: $e');
  }
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
    .collection('chats')
    .doc(chatId)
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

  final update = {
    'deleted': true,
    'text': '[deleted]',
  };

  // ✅ SINGLE SOURCE OF TRUTH
  await firestore
      .collection('chats')
      .doc(chatId)
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

  final myUid = auth.currentUser?.uid;
  if (myUid == null) return;

  final deviceId = LocalStorage.getDeviceId();
  if (deviceId == null || deviceId.isEmpty) return;

  final identity = IdentityKeyManager(firestore: firestore);
  final devices = await identity.fetchAllDevicePubMap(otherUid);
  if (devices.isEmpty) throw Exception('Peer has no devices');

  final peerDeviceId = devices.entries.first.key;

  await ensureSessionForPeer(
    firestore: firestore,
    myUid: myUid,
    peerUid: otherUid,
    peerDeviceId: peerDeviceId,
  );

  final session = await sm.loadSession(
    myUid,
    otherUid,
    deviceId,
    peerDeviceId,
  );

  if (session == null || session.peerDeviceId != peerDeviceId) {
    throw Exception('Edit failed: session mismatch');
  }

  final payload = await sm.encryptMessage(
    myUid,
    otherUid,
    deviceId,
    peerDeviceId,
    Uint8List.fromList(utf8.encode(newText)),
  );

  final update = {
    'text': '[encrypted]',
    'ciphertext': payload['ciphertext'],
    'iv': payload['iv'],
    'mac': payload['mac'],
    'edited': true,
  };

  // ✅ SINGLE SOURCE OF TRUTH
  await firestore
      .collection('chats')
      .doc(chatId)
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

  final deviceId = LocalStorage.getDeviceId();
  if (deviceId == null || deviceId.isEmpty) {
    throw Exception('❌ deviceId missing – cannot decrypt media');
  }
await SessionGuard.run(
  key: '$myUid-$peerUid-${m.senderDeviceId}',
  action: () async {
    await ensureSessionForPeer(
      firestore: firestore,
      myUid: myUid,
      peerUid: peerUid,
      peerDeviceId: m.senderDeviceId,
    );
  },
);


  // ensure session
final session = await sm.loadSession(
  myUid,
  peerUid,
  deviceId,
  m.senderDeviceId,
);


if (session == null) {
  throw Exception("session missing after ensureSessionForPeer");
}
// if (session == null) {
//   final identity = IdentityKeyManager(firestore: firestore);

//   final peerPub =
//       await identity.fetchDevicePublicKey(peerUid, m.peerDeviceId);
//   if (peerPub == null) {
//     throw Exception('Peer public key missing');
//   }

//   final myKeyPair = await KeyManager(firestore: firestore)
//       .loadLocalKeyPair(uid: myUid, deviceId: deviceId);

//   session = await sm.initSession(
//     myUid: myUid,
//     peerId: peerUid,
//     myIdentityKeyPair: myKeyPair,
//     deviceId: deviceId,
//     peerDeviceId: m.peerDeviceId!,
//     peerIdentityPub: peerPub,
//   );
// }

  // if (existing == null) {
  //   await _ensureSession(myUid: myUid, peerUid: peerUid);
  // }

  // final peerPub = await IdentityKeyManager(firestore: firestore)
  //     .fetchDevicePublicKey(peerUid, m.peerDeviceId);



final mediaKey = await sm.decryptMediaKey(
  myUid,
  peerUid,
  deviceId,
  m.senderDeviceId,
  {
    'ciphertext': m.ciphertext!,
    'iv': m.iv!,
    'mac': m.mac!,
  },
);

  final req = await HttpClient().getUrl(Uri.parse(m.fileUrl!));
  final res = await req.close();
  final encryptedBytes =
      await consolidateHttpClientResponseBytes(res);

 final plainBytes = await compute(
  mediaDecryptIsolate,
  MediaDecryptParams(
    encryptedBytes: encryptedBytes,
    mediaKey: mediaKey,
    nonce: base64Decode(m.mediaNonceB64!),
  ),
);


      final dir = await getTemporaryDirectory();
      // derive extension safely
      final uri = Uri.parse(m.fileUrl!);
      final ext = p.extension(uri.path).replaceFirst('.', '');

      final safeExt = ext.isNotEmpty ? ext : 'bin';

      final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$safeExt',
      );


    await file.writeAsBytes(plainBytes, flush: true);
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
      .set({
    'blockedAt': FieldValue.serverTimestamp(),
  });
}


  Future<void> unblockUser(String targetUid) async {
  final myUid = auth.currentUser!.uid;

  await firestore
      .collection('users')
      .doc(myUid)
      .collection('blocked')
      .doc(targetUid)
      .delete();
}

Stream<bool> isBlocked(String targetUid) {
  final myUid = auth.currentUser!.uid;

  return firestore
      .collection('users')
      .doc(myUid)
      .collection('blocked')
      .doc(targetUid)
      .snapshots()
      .map((doc) => doc.exists);
}

Future<bool> isBlockedByPeer(String peerUid) async {
  final myUid = auth.currentUser!.uid;

  final doc = await firestore
      .collection('users')
      .doc(peerUid)
      .collection('blocked')
      .doc(myUid)
      .get();

  return doc.exists;
}

  // ============================================================
  // 📚 CHAT LISTS
  // ============================================================
 

Stream<List<ChatContactModel>> getChatContacts() async* {
  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      yield <ChatContactModel>[]; // 🔥 stops Firestore on logout
      continue;
    }

    yield* firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .orderBy("timeSent", descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final contacts = <ChatContactModel>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final isHidden = data['isHideChat'] == true;

            if (!isHidden) {
              contacts.add(ChatContactModel.fromMap(data));
            }

          }
          return contacts;
        });
  }
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
