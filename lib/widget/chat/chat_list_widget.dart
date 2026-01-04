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

String getChatId(String a, String b) {
  return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
}
 
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
                              final chatId = getChatId(currentUid, widget.recieverUserId);

                            await chatController.toggleReaction(
                              chatId: chatId,
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
                  final chatId = getChatId(
                    FirebaseAuth.instance.currentUser!.uid,
                    widget.recieverUserId,
                  );

                  await chatController.deleteMessage(
                    chatId: chatId,
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
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      final chatId = getChatId(myUid, widget.recieverUserId);
   final Stream<List<Message>> stream =
    widget.isCommunityChat
        ? chatController.communityChatStream(widget.recieverUserId)
        : widget.isGroupChat
            ? chatController.groupChatStream(widget.recieverUserId)
            : ref
                .watch(chatControllerProvider)
                .chatStream(widget.recieverUserId);

  return StreamBuilder<bool>(
    stream: ref
        .read(chatRepositoryProvider)
        .isBlocked(widget.recieverUserId),
    builder: (context, blockSnap) {
      final isBlocked = blockSnap.data ?? false;

      return StreamBuilder<List<Message>>(
        stream: stream,
        builder: (context, snapshot) {
        if (!snapshot.hasData) {
            return const SizedBox(); // 👈 NO infinite loader
          }

         final myUid = FirebaseAuth.instance.currentUser!.uid;
          final chatId = getChatId(myUid, widget.recieverUserId);

          final localMessages =
              ref.watch(localMessageProvider)[chatId] ?? [];

                      final remoteMessages = snapshot.data ?? [];
                        // 🔥 Firestore sync ho gaya → local echo clear
         Future.microtask(() {
              if (!mounted) return;

              final notifier = ref.read(localMessageProvider.notifier);
              for (final m in remoteMessages) {
                notifier.removeMessage(chatId, m.messageId);
              }
            });


            // 🔥 Merge only this chat
            final map = <String, Message>{};

                    for (final m in localMessages) {
                      map[m.messageId] = m;
                    }

                    for (final m in remoteMessages) {
                      map[m.messageId] = m;
                    }

                    final messages = map.values.toList()
                      ..sort((a, b) => a.timeSent.compareTo(b.timeSent));


          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (messageController.hasClients && messageController.position.maxScrollExtent > 0) {
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
              final isFirestoreMessage =
                    msg.ciphertext != null &&
                    msg.iv != null &&
                    msg.mac != null;

          if (!isBlocked &&
              isFirestoreMessage &&        // ✅ ONLY REAL FIRESTORE MSG
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
              final displayText = msg.text;
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
                    fileUrl: msg.fileUrl,
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