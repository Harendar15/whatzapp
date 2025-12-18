import 'dart:io';

import 'package:adchat/controller/controller/group_chat_controller.dart';
import 'package:adchat/controller/repo/group_repository.dart';
import 'package:adchat/models/group_message_model.dart';
import 'package:adchat/models/message_model.dart';
import 'package:adchat/views/group/group_message_info_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:adchat/utils/save_to_gallery.dart';
import 'package:adchat/utils/gallery_permission.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class GroupChatList extends ConsumerStatefulWidget {
  final String groupId;
  final String myName;
  final void Function(GroupMessage message, String preview, bool isMe)? onReply;

  const GroupChatList({
    super.key,
    required this.groupId,
    required this.myName,
    this.onReply,
  });

  @override
  ConsumerState<GroupChatList> createState() => _GroupChatListState();
}

class _GroupChatListState extends ConsumerState<GroupChatList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------

  String _formatTime(dynamic timeSent) {
    DateTime t;
    if (timeSent is Timestamp) {
      t = timeSent.toDate();
    } else if (timeSent is int) {
      t = DateTime.fromMillisecondsSinceEpoch(timeSent);
    } else {
      t = DateTime.now();
    }
    return DateFormat.jm().format(t);
  }

  String _previewTextForMessage(GroupMessage m) {
    if (m.type.isText) return '[text]';
    if (m.type.isImage) return 'Photo';
    if (m.type.isVideo) return 'Video';
    if (m.type.isAudio) return 'Audio';
    if (m.type.isGif) return 'GIF';
    return 'Attachment';
  }

  Map<String, int> _aggregateReactions(Map<String, dynamic>? raw) {
    if (raw == null) return {};
    final Map<String, int> out = {};
    raw.forEach((k, v) {
      if (v is List) out[k] = v.length;
    });
    return out;
  }

  Widget _buildReactionsBar(
    GroupMessage m,
    bool isMe,
    String currentUid,
  ) {
    final aggregated = _aggregateReactions(m.reactions);
    if (aggregated.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: aggregated.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 14)),
                    if (e.value > 1) ...[
                      const SizedBox(width: 2),
                      Text(
                        e.value.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(groupChatControllerProvider);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<GroupMessage>>(
      stream: controller.messagesStream(widget.groupId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snap.data!;
        if (messages.isEmpty) {
          return const Center(child: Text("No messages"));
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (ctx, i) {
            final m = messages[i];
            final isMe = m.senderId == currentUid;
            final time = _formatTime(m.timeSent);

            final key =
                _messageKeys.putIfAbsent(m.messageId, () => GlobalKey());

            // ---------------- TEXT MESSAGE ----------------
            if (m.type.isText) {
              return KeyedSubtree(
                key: key,
                child: FutureBuilder<String>(
                  future:
                      controller.decryptMessageText(m, widget.groupId),
                  builder: (ctx, snap) {
                    final text = snap.data ??
                        (snap.connectionState ==
                                ConnectionState.waiting
                            ? "Decrypting..."
                            : "[Failed to decrypt]");

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green[100]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                m.senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Text(text),
                            const SizedBox(height: 4),
                            Text(time,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54)),
                            _buildReactionsBar(
                                m, isMe, currentUid),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            // ---------------- MEDIA MESSAGE ----------------
           return KeyedSubtree(
  key: key,
  child: FutureBuilder<File>(
    future: controller.decryptMedia(m, widget.groupId),
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        );
      }

      if (!snap.hasData) {
        return const SizedBox.shrink();
      }

      // ✅ DEFINE HERE (IMPORTANT)
      final File file = snap.data!;
      final bool isImage = m.type.isImage;

      return GestureDetector(
        onLongPress: () async {
          await requestGalleryPermission();
          await saveToGallery(file, m.type);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Saved to gallery")),
            );
          }
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    m.senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isImage
                      ? Image.file(file, fit: BoxFit.contain)
                      : const Icon(Icons.insert_drive_file, size: 80),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                _buildReactionsBar(m, isMe, currentUid),
              ],
            ),
          ),
        ),
      );
    },
  ),
);

          },
        );
      },
    );
  }
}
