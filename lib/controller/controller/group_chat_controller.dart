// lib/controller/group_chat_controller.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message_model.dart';
import '../repo/group_repository.dart';
import '../../crypto/message_encryptor.dart';
import '../../crypto/media_helper.dart';
import 'package:adchat/helpers/local_storage.dart';
import '../../models/group_message_model.dart';
import 'package:adchat/utils/save_to_gallery.dart';
final groupChatControllerProvider = Provider<GroupChatController>((ref) {
  final repo = ref.read(groupRepositoryProvider);
  return GroupChatController(ref: ref, repo: repo);
});

class GroupChatController {
  final Ref ref;
  final GroupRepository repo;

  final MessageEncryptor _encryptor = MessageEncryptor();
  final MediaHelper _mediaHelper = MediaHelper();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Uint8List> _senderKeyCache = {};

  GroupChatController({
    required this.ref,
    required this.repo,
  });

  String get _uid => _auth.currentUser!.uid;

  Stream<List<GroupMessage>> messagesStream(String groupId) {
    return repo.groupMessagesStream(groupId);
  }

Future<Uint8List?> _loadSenderKey(String groupId) async {
  if (_senderKeyCache.containsKey(groupId)) {
    return _senderKeyCache[groupId];
  }

  final deviceId = LocalStorage.getDeviceId()!;
  final key = await repo.ensureSenderKeyCached(groupId, _uid, deviceId);

    if (key != null) {
      _senderKeyCache[groupId] = key;
    }
    return key;
  }


  Future<String> decryptMessageText(GroupMessage m, String groupId) async {
  try {
    final key = await _loadSenderKey(groupId);

    if (key == null || m.ciphertext.isEmpty) {
      return "[encrypted]";
    }

    return await _encryptor.decryptText(
      senderKey: key,
      ciphertext: m.ciphertext,
      iv: m.nonce,
      mac: m.mac,
      aad: utf8.encode(groupId),
    );
  } catch (_) {
    return "[failed to decrypt]";
  }
}


  Future<File> decryptMedia(GroupMessage m, String groupId) async {
    final key = await _loadSenderKey(groupId);

    if (key == null ||
        m.fileUrl.isEmpty ||
        m.wrappedContentKey.isEmpty ||
        m.wrappedContentKeyNonce.isEmpty ||
        m.contentNonce.isEmpty) {
      throw Exception('Missing media encryption info');
    }

    final file = await  _mediaHelper.decryptAndSave(
      encryptedUrl: m.fileUrl,
      senderKey: key,
      wrappedKey: m.wrappedContentKey,
      wrappedNonce: m.wrappedContentKeyNonce,
      contentNonce: m.contentNonce,
       mediaExt: m.mediaExt,
    );
    // 🔥 AUTO-SAVE RECEIVED MEDIA (ONLY ONCE)
    if (!m.isSavedToGallery) {
      await saveToGallery(file, m.type);

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(m.messageId)
          .update({
            'isSavedToGallery': true,
          });
    }

    if (!file.existsSync()) {
      throw Exception("Decrypted media file missing");
    }
    return file;
  }

  Future<void> sendText({
    required String groupId,
    required String message,
    required String senderName,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToTextPreview,
    String? replyToType,
  }) async {
    return repo.sendTextMessage(
      groupId: groupId,
      message: message,
      senderName: senderName,
      senderDeviceId: LocalStorage.getDeviceId()!,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToTextPreview: replyToTextPreview,
      replyToType: replyToType,
    );
  }

  Future<void> sendMedia({
    required String groupId,
    required File file,
    required String senderName,
    required MessageModel type,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToTextPreview,
    String? replyToType,
  }) async {
    return repo.sendMediaMessage(
      groupId: groupId,
      file: file,
      senderName: senderName,
      type: type,
      senderDeviceId: LocalStorage.getDeviceId()!,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToTextPreview: replyToTextPreview,
      replyToType: replyToType,
    );
  }

  Future<void> markSeen({
    required String groupId,
    required String messageId,
  }) {
    return repo.markMessageSeen(
      groupId: groupId,
      messageId: messageId,
      uid: _uid,
    );
  }

  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String emoji,
  }) {
    return repo.toggleReaction(
      groupId: groupId,
      messageId: messageId,
      emoji: emoji,
      uid: _uid,
    );
  }

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) {
    return repo.deleteMessage(
      groupId: groupId,
      messageId: messageId,
    );
  }

  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newText,
  }) {
    return repo.editMessage(
      groupId: groupId,
      messageId: messageId,
      newText: newText,
    );
  }
}
