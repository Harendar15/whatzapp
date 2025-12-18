// lib/views/group/group_chat_screen.dart
import 'package:adchat/controller/controller/group_chat_controller.dart';
import 'package:adchat/models/group_message_model.dart';
import 'package:adchat/widget/chat/group_chat_list.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adchat/models/message_model.dart';
class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  GroupMessage? _replyTo;
  String _replyPreview = '';
  bool _replyIsMe = false;

  String _myName = '';
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadMyName();
  }

  Future<void> _loadMyName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        _myName = doc.data()?['name'] ??
            doc.data()?['displayName'] ??
            'Unknown';
        _loadingUser = false;
      });
    } catch (_) {
      setState(() {
        _myName = 'Unknown';
        _loadingUser = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearReply() {
    setState(() {
      _replyTo = null;
      _replyPreview = '';
      _replyIsMe = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupCtrl = ref.watch(groupChatControllerProvider);
 

    if (_loadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          // 🔹 Messages list with reply callback
          Expanded(
            child: GroupChatList(
              groupId: widget.groupId,
              myName: _myName,
              onReply: (message, preview, isMe) {
                setState(() {
                  _replyTo = message;
                  _replyPreview = preview;
                  _replyIsMe = isMe;
                });
              },
            ),
          ),

          // 🔹 Reply preview bar (WhatsApp style)
          if (_replyTo != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                border: Border(
                  left: BorderSide(
                    color: Colors.teal.shade400,
                    width: 4,
                  ),
                  top: Divider.createBorderSide(context),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyIsMe ? 'You' : _replyTo!.senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearReply,
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

          // 🔹 Input row (text + attach + send)
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () async {
                    final file = await pickImageFromGallery(context);
                    if (file == null) return;

                    await groupCtrl.sendMedia(
                      groupId: widget.groupId,
                      file: file,
                      senderName: _myName,
                      type:MessageModel.image,
                      // reply meta optional
                      replyToMessageId: _replyTo?.messageId,
                      replyToSenderName: _replyTo?.senderName,
                      replyToTextPreview: _replyPreview,
                      replyToType: _replyTo?.type.type,
                    );

                    _clearReply();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
               IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sending
                      ? null
                      : () async {
                          final text = _controller.text.trim();
                          if (text.isEmpty) return;

                          setState(() => _sending = true);
                          _controller.clear();

                          await groupCtrl.sendText(
                            groupId: widget.groupId,
                            message: text,
                            senderName: _myName,
                            replyToMessageId: _replyTo?.messageId,
                            replyToSenderName: _replyTo?.senderName,
                            replyToTextPreview: _replyPreview,
                            replyToType: _replyTo?.type.name,
                          );

                          _clearReply();
                          setState(() => _sending = false);
                        },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
