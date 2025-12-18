// lib/views/chat/chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:adchat/controller/repo/call_repository.dart';
import 'package:adchat/controller/call/call_controller.dart';
import 'package:adchat/controller/settings/settings_screen_controller.dart';
import 'package:adchat/models/user_model.dart';
import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/size.dart';
import 'package:adchat/utils/strings.dart';
import 'package:adchat/utils/assets.dart';
import 'package:adchat/models/call_model.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/widget/chat/chat_field_widget.dart';
import 'package:adchat/widget/chat/chat_list_widget.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/controller/repo/chat_repo.dart';

class ChatScreen extends ConsumerStatefulWidget {
  static const String routeName = '/mobile-chat-screen';

  final String name;
  final String uid;
  final bool isGroupChat;
  final bool isCommunityChat;
  final String profilePic;
  final bool isHideChat;
  final dynamic groupData;
  final dynamic communityData;
  final bool fromStatusReply;

  const ChatScreen({
    super.key,
    required this.name,
    required this.uid,
    required this.isGroupChat,
    required this.isCommunityChat,
    required this.profilePic,
    required this.isHideChat,
    this.groupData,
    this.communityData,
    this.fromStatusReply = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final settingsController = Get.put(SettingsScreenController());
  final FocusNode messageFocusNode = FocusNode();

  bool isLoading = false;
  final List<UserModel> userInfo = [];
  
@override
void dispose() {
  if (messageFocusNode.hasFocus) {
    messageFocusNode.unfocus();
  }
  messageFocusNode.dispose();
  super.dispose();
}

  @override
  void initState() {
    super.initState();
    _guardGroupAccess();
    _fetchUserData();

    if (widget.fromStatusReply) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(messageFocusNode);
        }
      });
    }
  }
  

  Future<void> _fetchUserData() async {
   

    setState(() => isLoading = true);
    userInfo.clear();
    try {
      final members = widget.isGroupChat
          ? (widget.groupData?.membersUid ?? [])
          : widget.isCommunityChat
              ? (widget.communityData?.membersUid ?? [])
              : [widget.uid];

      for (final uid in members) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (snapshot.exists && snapshot.data() != null) {
          userInfo.add(UserModel.fromMap(snapshot.data()!));
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;

    return Stack(
      children: [
        Container(
          color: Get.isDarkMode
              ? CustomColor.bgColorDarkMode
              : const Color(0xffEAE2D8),
          child: Image.asset(
            Assets.whatsAppBg,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            color: Colors.white.withOpacity(0.6),
            colorBlendMode: BlendMode.modulate,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBarWidget(context, ref, w),
          body: _bodyWidget(context, w),
        )
      ],
    );
  }
  Future<void> _guardGroupAccess() async {
  if (!widget.isGroupChat) return;

  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return;

  final members = widget.groupData?.membersUid ?? [];

  if (!members.contains(myUid)) {
    await Future.delayed(Duration.zero);

    Get.snackbar(
      "Access Denied",
      "You are not a member of this group",
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );

    Get.back(); // ⛔ BLOCK ACCESS
  }
}


  Widget _bodyWidget(BuildContext context, ChatScreen w) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: w.isHideChat
              ? const SizedBox.shrink()
              : ChatList(
                  recieverUserId: w.uid,
                  isGroupChat: w.isGroupChat,
                  isCommunityChat: w.isCommunityChat,
                ),
        ),

        // Bottom: input area or block-banner
        StreamBuilder<bool>(
          stream: ref.read(chatRepositoryProvider).isBlocked(w.uid),
          builder: (_, snap) {
            final isBlocked = snap.data ?? false;

            if (isBlocked && !w.isGroupChat && !w.isCommunityChat) {
              return Container(
                height: 60,
                alignment: Alignment.center,
                color: Colors.red.shade100,
                child: const Text(
                  "You blocked this user. Unblock to send messages.",
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            return ChatFieldWidget(
              recieverUserId: w.uid,
              isGroupChat: w.isGroupChat,
              isCommunityChat: w.isCommunityChat,
              externalFocusNode: messageFocusNode,
            );
          },
        ),
      ],
    );
  }

  // -------------------- APPBAR WITH CALL BUTTONS + BLOCK MENU --------------------
  PreferredSizeWidget _appBarWidget(
      BuildContext context, WidgetRef ref, ChatScreen w) {
    final callCtrl = Get.find<CallController>();

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Get.back(),
      ),
      title: w.isCommunityChat ? _communityTitle(w) : _userTitle(w),

      actions: [
        // 🔔 Call buttons (blocked -> disabled)
        if (!w.isGroupChat && !w.isCommunityChat)
          StreamBuilder<bool>(
            stream: ref.read(chatRepositoryProvider).isBlocked(w.uid),
            builder: (_, snap) {
              final blocked = snap.data ?? false;

              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.call,
                      color: blocked ? Colors.grey : Colors.white,
                    ),
                                onPressed: blocked
                ? null
                : () async {
                    final me = await ref
                        .read(authRepositoryProvider)
                        .getCurrentUserData();
                    if (me == null) return;

                    final repo = CallRepository();

                    final call = CallModel(
                      callId: DateTime.now().millisecondsSinceEpoch.toString(),
                      callerId: me.uid,
                      callerName: me.name,
                      callerImage: me.profilePic,
                      receiverId: w.uid,
                      receiverName: w.name,
                      receiverImage: w.profilePic,
                      channelName: "call_${DateTime.now().millisecondsSinceEpoch}",
                      token: "",
                      type: "audio",
                      status: "ringing",
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                      mediaKey: "",
                      members: [me.uid, w.uid],
                    );

                    // 🔐 CREATE ENCRYPTED CALL (MANDATORY)
                    await repo.createEncryptedCall(model: call);

                    // 🔔 START CALL FLOW
                    await callCtrl.startCall(call: call);
                  },

                  ),
                  IconButton(
                    icon: Icon(
                      Icons.videocam,
                      color: blocked ? Colors.grey : Colors.white,
                    ),
                   onPressed: blocked
                  ? null
                  : () async {
                      final me = await ref
                          .read(authRepositoryProvider)
                          .getCurrentUserData();
                      if (me == null) return;

                      final repo = CallRepository();

                      final call = CallModel(
                        callId: DateTime.now().millisecondsSinceEpoch.toString(),
                        callerId: me.uid,
                        callerName: me.name,
                        callerImage: me.profilePic,
                        receiverId: w.uid,
                        receiverName: w.name,
                        receiverImage: w.profilePic,
                        channelName: "call_${DateTime.now().millisecondsSinceEpoch}",
                        token: "",
                        type: "video",
                        status: "ringing",
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        mediaKey: "",
                        members: [me.uid, w.uid],
                      );

                      // 🔐 ENCRYPTED CALL FIRST
                      await repo.createEncryptedCall(model: call);

                      await callCtrl.startCall(call: call);
                    },

                  ),
                ],
              );
            },
          ),

        // ⋮ Hide + Block / Unblock
        if (!w.isGroupChat)
          StreamBuilder<bool>(
            stream: ref.read(chatRepositoryProvider).isBlocked(w.uid),
            builder: (_, snap) {
              final blocked = snap.data ?? false;

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  final repo = ref.read(chatRepositoryProvider);

                  if (value == "hide") {
                    _toggleHideChat(context, w.uid, !w.isHideChat);
                  } else if (value == "block") {
                    await repo.blockUser(w.uid);
                    Get.snackbar(
                      "Blocked",
                      "${w.name} is now blocked.",
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } else if (value == "unblock") {
                    await repo.unblockUser(w.uid);
                    Get.snackbar(
                      "Unblocked",
                      "${w.name} is now unblocked.",
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: "hide",
                    child: Text(
                      w.isHideChat ? Strings.unHideChat : Strings.hideChat,
                    ),
                  ),
                  PopupMenuItem(
                    value: blocked ? "unblock" : "block",
                    child: Text(
                      blocked ? "Unblock User" : "Block User",
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  // -------------------- TITLE: COMMUNITY --------------------
  Widget _communityTitle(ChatScreen w) {
    return Row(
      children: [
        SafeImage(url: w.profilePic, size: Dimensions.radius * 4),
        horizontalSpace(Dimensions.widthSize),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(w.name, style: const TextStyle(color: Colors.white)),
            const Text(
              "Announcements",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------- TITLE: USER (typing + last seen) --------------------
  Widget _userTitle(ChatScreen w) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final chatId = myUid.isEmpty
        ? ''
        : (myUid.compareTo(w.uid) < 0 ? '${myUid}_${w.uid}' : '${w.uid}_$myUid');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(w.uid)
          .snapshots(),
      builder: (_, userSnap) {
        final userData = userSnap.data?.data();
        final bool isOnline = userData?['isOnline'] ?? false;
        final lastSeenRaw = userData?['lastSeen'];

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: chatId.isEmpty
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('typing')
                  .doc(chatId)
                  .snapshots(),
          builder: (_, typingSnap) {
            String subtitle = '';

            if (typingSnap.hasData && typingSnap.data!.data() != null) {
              final tData = typingSnap.data!.data()!;
              final typingBy = tData['typingBy'];
              final isTyping = tData['isTyping'] == true;

              if (isTyping && typingBy == w.uid) {
                subtitle = 'typing...';
              }
            }

            if (subtitle.isEmpty) {
              if (isOnline) {
                subtitle = 'online';
              } else {
                final lastSeenText = _formatLastSeen(lastSeenRaw);
                if (lastSeenText != null) {
                  subtitle = 'last seen $lastSeenText';
                } else {
                  subtitle = 'offline';
                }
              }
            }

            return Row(
              children: [
                SafeImage(
                    url: w.profilePic, size: Dimensions.radius * 4),
                horizontalSpace(Dimensions.widthSize),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _formatLastSeen(dynamic raw) {
    if (raw == null) return null;

    DateTime dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);

    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (thatDay == today) {
      return 'today at $timeStr';
    }

    if (thatDay == today.subtract(const Duration(days: 1))) {
      return 'yesterday at $timeStr';
    }

    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} at $timeStr';
  }

  // -------------------- HIDE CHAT --------------------
  Future<void> _toggleHideChat(
    BuildContext context, String uid, bool hide) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  if (me == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(me)
      .collection('chats')
      .doc(uid)
      .set(
        {'isHideChat': hide},
        SetOptions(merge: true), // ✅ IMPORTANT
      );
}

}
