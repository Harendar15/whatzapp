// lib/controller/controller/chat_controller.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message.dart';
import '../../models/message_model.dart';
import '../../models/message_reply_model.dart';
import '../../models/user_model.dart';
import '../repo/chat_repo.dart';
import '../../models/chat_contact_model.dart';
import '../../models/group.dart';
import '../../models/community.dart';

final chatControllerProvider = Provider<ChatController>((ref) {
  final repo = ref.read(chatRepositoryProvider);
  return ChatController(repo, ref);
});

class ChatController {
  final ChatRepository repo;
  final Ref ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatController(this.repo, this.ref);

  // Streams
  Stream<List<Message>> chatStream(String otherUid) => repo.getChatStream(otherUid);
  Stream<List<Message>> groupChatStream(String groupId) => repo.getGroupChatStream(groupId);
  Stream<List<Message>> communityChatStream(String commId) => repo.getCommunityChats(commId);

  Stream<List<ChatContactModel>> chatContacts() => repo.getChatContacts();
  Stream<List<Group>> chatGroups() => repo.getChatGroups();
  Stream<List<Community>> chatCommunities() => repo.getCommunity();
  Stream<List<Community>> selectedCommunity() => repo.getCommunityById();
  Stream<List<Group>> chatGroupsById(List<String> ids) => repo.getChatGroupsId(ids);

  // Helpers
  Future<UserModel?> _loadCurrentUserModel() async {
    final uid = repo.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!);
  }

  // Send text
 Future<void> sendTextMessage(
  BuildContext context,
  String text,
  String recieverUserId,
  bool isGroupChat,
  bool isCommunityChat, {
  MessageReply? messageReply,
}) async {
  if (text.trim().isEmpty) return;

  final senderUser = await _loadCurrentUserModel();
  if (senderUser == null) return;

  await repo.sendTextMessage(
    context: context,
    text: text,
    recieverUserId: recieverUserId,
    senderUser: senderUser,
    messageReply: messageReply,
    isGroupChat: isGroupChat,
    isCommunityChat: isCommunityChat,
  );
}

  
  // Send file
  Future<void> sendFileMessage(
    BuildContext context,
    File file,
    String recieverUserId,
    MessageModel messageEnum,
    bool isGroupChat,
    bool isCommunityChat, {
    MessageReply? messageReply,
  }) async {
    final senderUser = await _loadCurrentUserModel();
    if (senderUser == null) return;

    await repo.sendFileMessage(
      context: context,
      file: file,
      recieverUserId: recieverUserId,
      senderUserData: senderUser,
      ref: ref,
      messageEnum: messageEnum,
      messageReply: messageReply,
      isGroupChat: isGroupChat,
      isCommunityChat: isCommunityChat,
    );
  }

  // Seen (accept nullable context and forward)
  Future<void> setChatMessageSeen(
    BuildContext? context,
    String recieverUserId,
    String messageId,
  ) async {
    await repo.setChatMessageSeen(context, recieverUserId, messageId);
  }

  // Reactions
  Future<void> toggleReaction({required String chatId, required String messageId, required String emoji, required String uid}) async {
    await repo.toggleReaction(chatId: chatId, messageId: messageId, emoji: emoji, uid: uid);
  }

  // Delete
  Future<void> deleteMessage({required String chatId, required String messageId, bool isGroup = false}) async {
    await repo.deleteMessage(chatId: chatId, messageId: messageId, isGroup: isGroup);
  }
  
  // Edit
  Future<void> editMessage({required String chatId, required String messageId, required String newText, required String otherUid, bool isGroup = false}) async {
    await repo.editMessage(chatId: chatId, messageId: messageId, newText: newText, otherUid: otherUid, isGroup: isGroup);
  }
  // 🔓 Decrypt media for 1-to-1 chat (used for save to gallery)
Future<File> decryptMediaForMe(Message message) async {
  return await repo.decryptMediaForMe(message);
}

  // Decrypt
  Future<String?> decryptMessage(Message m) async {
    try {
      return await repo.decryptMessageForMe(m);
    } catch (e) {
      debugPrint("Decrypt failed: $e");
      return null;
    }

  }
}
