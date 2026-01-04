// lib/widget/chat/chat_field_widget.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:adchat/controller/controller/chat_controller.dart';
import 'package:adchat/models/message_model.dart';
import 'package:adchat/models/message_reply_model.dart';
import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/utils/size.dart';
import 'package:adchat/utils/strings.dart';
import 'package:adchat/widget/chat/message_reply_preview.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'icon_creation_widget.dart';
import '../../controller/repo/chat_repo.dart';
import 'package:adchat/models/message.dart';
import 'package:adchat/helpers/local_storage.dart';
class ChatFieldWidget extends ConsumerStatefulWidget {
  final String recieverUserId;
  final bool isGroupChat;
  final bool isCommunityChat;
  final FocusNode? externalFocusNode;

  const ChatFieldWidget({
    super.key,
    required this.recieverUserId,
    required this.isGroupChat,
    required this.isCommunityChat,
    this.externalFocusNode,
  });

  @override
  ConsumerState<ChatFieldWidget> createState() =>
      _ChatFieldWidgetState();
}

class _ChatFieldWidgetState extends ConsumerState<ChatFieldWidget> {
  bool isShowSendButton = false;
  final TextEditingController _messageController = TextEditingController();

  // 🔊 Recorder
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecorderReady = false;
  bool isRecording = false;
  String? _recordedFilePath;

  bool isShowEmojiContainer = false;
  late FocusNode focusNode;
  bool _sending = false;

  // typing indicator
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    focusNode = widget.externalFocusNode ?? FocusNode();
    _initRecorder();
  }

  // 🔐 Ask mic permission + open recorder
  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();

    if (!mounted) return;

    if (status != PermissionStatus.granted) {
      debugPrint('Mic permission not granted');
      return;
    }

    final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('Mic permission not granted');
      }
    if (!mounted) return;

    setState(() {
      _isRecorderReady = true;
    });
  }

  // 👉 BLOCK CHECK HELPER (text + media + voice)
  Future<bool> _preventIfBlocked() async {
    // only for 1–1 chat
    if (widget.isGroupChat || widget.isCommunityChat) return false;

    final isBlocked = await ref
        .read(chatRepositoryProvider)
        .isBlocked(widget.recieverUserId)
        .first;

    if (isBlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You blocked this user.")),
        );
      }
      return true;
    }
    return false;
  }

  // ---------------------- TYPING INDICATOR ----------------------
 // ---------------------- TYPING INDICATOR ----------------------
Future<void> _setTyping(bool isTyping) async {
  if (!mounted) return;

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  // ❌ Skip group / community
  if (widget.isGroupChat || widget.isCommunityChat) return;

  // 🔒 Block check
  final isBlocked = await ref
      .read(chatRepositoryProvider)
      .isBlocked(widget.recieverUserId)
      .first;

  if (isBlocked) return;

  final other = widget.recieverUserId;
  final chatId =
      uid.compareTo(other) < 0 ? '${uid}_$other' : '${other}_$uid';

  await FirebaseFirestore.instance
      .collection('typing')
      .doc(chatId)
      .set({
    'typingBy': uid,
    'isTyping': isTyping,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  _typingTimer?.cancel();

  if (isTyping) {
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _setTyping(false);
    });
  }
}


String getChatId(String a, String b) {
  return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
}
 
  // 📨 Send text or start/stop voice note
void sendMessage() async {
  if (!mounted || _sending) return;
  _sending = true;

  try {
    if (await _preventIfBlocked()) return;

    // ---------- TEXT ----------
    if (isShowSendButton) {
      final text = _messageController.text.trim();
      if (text.isEmpty) return;

      await _setTyping(false);

     final reply = ref.read(messageReplyProvider);
    
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final messageId = const Uuid().v1();

    final senderDeviceId = LocalStorage.getDeviceId();
    if (senderDeviceId == null || senderDeviceId.isEmpty) return;

// 🔑 peerDeviceId UI ke liye required hai
// local echo me hum same rakh sakte hain
    final peerDeviceId = senderDeviceId;

// 🔥 1️⃣ LOCAL ECHO (sender ko real msg dikhane ke liye)
final chatId = getChatId(myUid, widget.recieverUserId);

ref.read(localMessageProvider.notifier).add(
  chatId,
  Message(
    senderId: myUid,
    recieverid: widget.recieverUserId,
    senderDeviceId: senderDeviceId,
    peerDeviceId: peerDeviceId,
    text: text,
    type: MessageModel.text,
    timeSent: DateTime.now(),
    messageId: messageId,
    isSeen: false,
    reactions: const {},
  ),
);



// 🔐 2️⃣ ENCRYPTED SEND (Firestore)
// 🔥 fire-and-forget (NO await)
unawaited(
  ref.read(chatControllerProvider).sendTextMessage(
    context,
    text,
    widget.recieverUserId,
    widget.isGroupChat,
    widget.isCommunityChat,
    messageReply: reply,
  ),
);


      ref.read(messageReplyProvider.state).update((_) => null);


      if (!mounted) return;
      setState(() {
        _messageController.clear();
        isShowSendButton = false;
      });
      return;
    }

    // ---------- VOICE ----------
    // ---------- VOICE ----------
if (isRecording) {
  await _recorder.stop();
  setState(() => isRecording = false);

  if (_recordedFilePath != null &&
      File(_recordedFilePath!).existsSync()) {
    sendFileMessage(File(_recordedFilePath!), MessageModel.audio);
  }
} else {
  final dir = await getTemporaryDirectory();
  _recordedFilePath =
      '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

  await _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    ),
    path: _recordedFilePath!,
  );

  setState(() => isRecording = true);
}

  } finally {
    _sending = false; // ✅ CRITICAL
  }
}


Future<void> sendFileMessage(File file, MessageModel messageEnum) async {
  if (await _preventIfBlocked()) return;


  ref.read(chatControllerProvider).sendFileMessage(
    context,
    file,
    widget.recieverUserId,
    messageEnum, // ✅ FIX
    widget.isGroupChat,
    widget.isCommunityChat,
  );
}


  void selectImage() async {
    File? image = await pickImageFromGallery(context);
    if (!mounted) return;
    if (image != null) sendFileMessage(image, MessageModel.image);
  }

  void pickFromCamera() async {
    File? image = await pickImageFromCamera(context);
    if (!mounted) return;
    if (image != null) sendFileMessage(image, MessageModel.image);
  }

  selectVideo() async {
    File? video = await pickVideoFromGallery(context);
    if (!mounted) return;
    if (video != null) sendFileMessage(video, MessageModel.video);
  }

  void hideEmojiContainer() {
    if (!mounted) return;
    setState(() => isShowEmojiContainer = false);
  }

  void showEmojiContainer() {
    if (!mounted) return;
    setState(() => isShowEmojiContainer = true);
  }

  void showKeyboard() => focusNode.requestFocus();
  void hideKeyboard() => focusNode.unfocus();

  void toggleEmojiKeyboardContainer() {
    if (isShowEmojiContainer) {
      showKeyboard();
      hideEmojiContainer();
    } else {
      hideKeyboard();
      showEmojiContainer();
    }
  }

  Widget bottomSheetWidget(
    BuildContext context,
    Function pickFromCamera,
    Function selectImage,
    Function selectVideo,
  ) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.21,
      width: MediaQuery.of(context).size.width,
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: GridView(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            children: [
              iconCreation(Icons.camera_alt, Colors.pink, "Camera",
                  onTap: () {
                pickFromCamera();
                Get.back();
              }),
              iconCreation(Icons.insert_photo, Colors.purple, "Gallery",
                  onTap: () {
                selectImage();
                Get.back();
              }),
              iconCreation(Icons.videocam, Colors.blue, "Video",
                  onTap: () {
                selectVideo();
                Get.back();
              }),
            ],
          ),
        ),
      ),
    );
  }




@override
void dispose() {
  _typingTimer?.cancel();

  if (FirebaseAuth.instance.currentUser != null &&
      !widget.isGroupChat &&
      !widget.isCommunityChat) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final other = widget.recieverUserId;
    final chatId =
        uid.compareTo(other) < 0 ? '${uid}_$other' : '${other}_$uid';

    FirebaseFirestore.instance.collection('typing').doc(chatId).set({
      'isTyping': false,
      'typingBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  _messageController.dispose();
  focusNode.dispose();

 if (isRecording) {
  _recorder.stop();
}
_recorder.dispose();

  super.dispose();
}




  @override
  Widget build(BuildContext context) {
    final messageReply = ref.watch(messageReplyProvider);
    final isShowMessageReply = messageReply != null;

    return Column(
      children: [
        isShowMessageReply
            ? const MessageReplyPreview()
            : const SizedBox(),
        Row(
          children: [
            horizontalSpace(Dimensions.widthSize),
            Expanded(
              flex: 5,
              child: TextFormField(
                maxLength: null,
                maxLines: 3,
                minLines: 1,
                focusNode: focusNode,
                controller: _messageController,
                onChanged: (val) {
                if (!mounted) return;

                final hasText = val.trim().isNotEmpty;
                setState(() => isShowSendButton = hasText);

                if (hasText) {
                  _setTyping(true);
                } else {
                  _setTyping(false); // ✅ STOP typing
                }
              },

                onTap: () {
                  if (!mounted) return;
                  setState(() => isShowEmojiContainer = false);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Get.isDarkMode
                      ? CustomColor.chatBoxColor
                      : CustomColor.white,
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Dimensions.marginSize * 0.8,
                    ),
                    child: GestureDetector(
                      onTap: toggleEmojiKeyboardContainer,
                      child: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: CustomColor.greyColor,
                      ),
                    ),
                  ),
                  suffixIcon: _messageController.text.isNotEmpty
                      ? const Text('')
                      : SizedBox(
                          width: 100.w,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    backgroundColor:
                                        Colors.transparent,
                                    context: context,
                                    builder:
                                        (BuildContext context) {
                                      return bottomSheetWidget(
                                        context,
                                        pickFromCamera,
                                        selectImage,
                                        selectVideo,
                                      );
                                    },
                                  );
                                },
                                child: Transform.rotate(
                                  angle: -math.pi / 4,
                                  child: const Icon(
                                    Icons.attach_file,
                                    color: CustomColor.greyColor,
                                  ),
                                ),
                              ),
                              horizontalSpace(
                                  Dimensions.widthSize * 0.5),
                              GestureDetector(
                                onTap: pickFromCamera,
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: CustomColor.greyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                  hintText: Strings.typeAMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        Dimensions.radius * 2),
                    borderSide: const BorderSide(
                      width: 0,
                      style: BorderStyle.none,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
            horizontalSpace(Dimensions.widthSize * 0.5),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 8,
                  right: 2,
                  left: 2,
                ),
                child: InkWell(
                  onTap: sendMessage,
                  child: CircleAvatar(
                    backgroundColor: CustomColor.primaryColor,
                    radius: Dimensions.radius * 2.5,
                    child: Icon(
                      isShowSendButton
                          ? Icons.send
                          : isRecording
                              ? Icons.close
                              : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            horizontalSpace(Dimensions.widthSize * 0.5),
          ],
        ),
        isShowEmojiContainer
            ? SizedBox(
                height:
                    MediaQuery.of(context).size.height * 0.35,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    if (!mounted) return;
                    setState(() {
                      _messageController.text += emoji.emoji;
                      isShowSendButton =
                          _messageController.text.isNotEmpty;
                    });
                    _setTyping(true);
                    Future.delayed(const Duration(seconds: 2), () {
                      _setTyping(false);
                    });

                  },
                ),
              )
            : const SizedBox(),
      ],
    );
  }
}
