// lib/widget/chat/chat_list_widget.dart
// FIXED — SafeImage applied, stable media rendering, reaction sheet, reply, scroll

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../controller/controller/chat_controller.dart';
import '../../../../models/message.dart';
import '../../../../models/message_model.dart';
import '../../../../models/message_reply_model.dart';
import '../custom_loader.dart';
import 'my_text_card.dart';
import 'sender_message_card.dart';
import 'package:adchat/controller/repo/chat_repo.dart';
import 'package:adchat/views/chat/message_info_screen.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:adchat/utils/save_to_gallery.dart';
import 'package:adchat/utils/gallery_permission.dart';

class ChatList extends ConsumerStatefulWidget {
  final String recieverUserId;
  final bool isGroupChat;
  final bool isCommunityChat;

  const ChatList({
    super.key,
    required this.recieverUserId,
    required this.isGroupChat,
    required this.isCommunityChat,
  });

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  final ScrollController messageController = ScrollController();

  @override
  void dispose() {
    messageController.dispose();
   
    super.dispose();
  }

  // Swipe reply
  void messageSwipe(String preview, bool isMe, MessageModel msgType) {
    ref.read(messageReplyProvider.state).update(
          (state) => MessageReply(preview, isMe, msgType),
        );
  }

  // Message actions bottom sheet
  void _showMessageActionsSheet(
    BuildContext context,
    Message messageData,
    bool isMyMessage,
  ) {
    if (widget.isCommunityChat) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final chatController = ref.read(chatControllerProvider);
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis
                      .map((e) => InkWell(
                            onTap: () async {
                              Navigator.pop(ctx);
                              await chatController.toggleReaction(
                                chatId: widget.recieverUserId,
                                messageId: messageData.messageId,
                                emoji: e,
                                uid: currentUid,
                              );
                            },
                            child: Text(e, style: const TextStyle(fontSize: 26)),
                          ))
                      .toList(),
                ),
              ),
              const Divider(height: 1),

              // Reply
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  final preview = messageData.type.isText
                      ? messageData.text
                      : "[${messageData.type.type}]";
                  messageSwipe(preview, isMyMessage, messageData.type);
                },
              ),
              if (messageData.type.isImage || messageData.type.isVideo)
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text("Save to gallery"),
                  onTap: () async {
                    Navigator.pop(context);

                    await requestGalleryPermission();
                    final file = await chatController.decryptMediaForMe(messageData);

                    await saveToGallery(file, messageData.type);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Saved to gallery")),
                    );
                  },
                ),

              // Message info
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Message info'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MessageInfoScreen(message: messageData),
                    ),
                  );
                },
              ),

              // Delete
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await chatController.deleteMessage(
                    chatId: widget.recieverUserId,
                    messageId: messageData.messageId,
                    isGroup: widget.isGroupChat,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override

Widget build(BuildContext context) {
  final chatController = ref.read(chatControllerProvider);
final Stream<List<Message>> stream = widget.isCommunityChat
    ? chatController.communityChatStream(widget.recieverUserId)
    : widget.isGroupChat
        ? chatController.groupChatStream(widget.recieverUserId)
        : ref
            .read(chatRepositoryProvider)
            .getChatStream(widget.recieverUserId);


  return StreamBuilder<bool>(
    stream: ref
        .read(chatRepositoryProvider)
        .isBlocked(widget.recieverUserId),
    builder: (context, blockSnap) {
      final isBlocked = blockSnap.data ?? false;

      return StreamBuilder<List<Message>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CustomLoader();
          }

          final messages = snapshot.data ?? [];

          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (messageController.hasClients) {
              try {
                messageController.animateTo(
                  messageController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              } catch (_) {}
            }
          });

          if (messages.isEmpty) {
            return const Center(child: Text("No messages yet"));
          }

          return ListView.builder(
            controller: messageController,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final currentUid = FirebaseAuth.instance.currentUser!.uid;
              final isMyMessage = msg.senderId == currentUid;

              final timeSent = DateFormat.jm().format(msg.timeSent);

              // ✅ SAFE SEEN LOGIC (NO await here)
              if (!isBlocked &&
                  !msg.isSeen &&
                  msg.recieverid == currentUid &&
                  !widget.isGroupChat &&
                  !widget.isCommunityChat) {
                chatController.setChatMessageSeen(
                  context,
                  widget.recieverUserId,
                  msg.messageId,
                );
              }

              if (msg.deleted) {
                return Center(
                  child: Text(
                    isMyMessage
                        ? "You deleted this message"
                        : "This message was deleted",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
            final displayText = msg.type.isText  ? (msg.text == '[encrypted]' ? 'Decrypting...' : msg.text): '';



              if (isMyMessage) {
                return GestureDetector(
                  onLongPress: () =>
                      _showMessageActionsSheet(context, msg, true),
                  child: MyTextCard(
                    message: displayText,
                    date: timeSent,
                    type: msg.type,
                    repliedText: msg.repliedMessage,
                    username: msg.repliedTo,
                    repliedMessageType: msg.repliedMessageType,
                    isSeen: msg.isSeen,
                    reactions: msg.reactions,
                    onLeftSwipe: (_) {
                      final preview = msg.type.isText
                          ? displayText
                          : "[${msg.type.type}]";
                      messageSwipe(preview, true, msg.type);
                    },
                  ),
                );
              } else {
                return GestureDetector(
                  onLongPress: () =>
                      _showMessageActionsSheet(context, msg, false),
                  child: SenderTextCard(
                    message: displayText,
                    date: timeSent,
                    type: msg.type,
                    username: msg.repliedTo,
                    repliedMessageType: msg.repliedMessageType,
                    repliedText: msg.repliedMessage,
                    reactions: msg.reactions,
                    onRightSwipe: (_) {
                      final preview = msg.type.isText
                          ? displayText
                          : "[${msg.type.type}]";
                      messageSwipe(preview, false, msg.type);
                    },
                  ),
                );
              }
            },
          );
        },
      );
    },
  );
}
}