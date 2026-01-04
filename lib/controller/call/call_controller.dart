import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/services.dart';
import 'dart:convert';      // ✅ for base64Decode
import 'dart:typed_data';  // ✅ for Uint8List
import 'dart:math';      // ✅ for Random.secure()
import '../../models/call_model.dart';
import 'package:adchat/controller/repo/call_repository.dart';
import 'call_history_controller.dart';
import '../../views/call/incoming_call_screen.dart';

class CallController extends GetxController {
  // 🔑 Agora
  static const String appId = "8fc842bb18b545d2ab4453fe61cf6d83";

  RtcEngine? engine;
  bool _engineReady = false;
  bool _encryptionEnabled = false;


  // --------------------------------------------------
  RxBool isReceivingCall = false.obs;
  RxBool isInCall = false.obs;

  Rx<CallModel?> incomingCall = Rx<CallModel?>(null);
  RxInt remoteUid = 0.obs;

  RxBool isMuted = false.obs;
  RxBool isSpeakerOn = false.obs;
  RxBool localVideoEnabled = true.obs;

  RxString callType = 'video'.obs;
  bool get isVideoCall => callType.value == 'video';

  String? currentCallId;
  String? currentChannel;
  CallModel? _activeCall;
  bool _answered = false;
  bool _permissionGranted = false;


  Timer? _callTimeoutTimer;
  Timer? _callTimer;
  RxInt callSeconds = 0.obs;
  int agoraUidFromFirebaseUid(String uid) {
  return uid.codeUnits.fold(0, (a, b) => a + b) & 0x7fffffff;
}


  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;

  CallHistoryController get _history =>
      Get.put(CallHistoryController(), permanent: true);

  // ==================================================
    @override
    void onInit() {
      super.onInit();

      final user = _auth.currentUser;

      if (user != null) {
        _listenForIncomingCalls();
      } else {
        FirebaseAuth.instance.authStateChanges().listen((u) {
          if (u != null) {
            _listenForIncomingCalls();
          }
        });
      }
    }


  @override
  Future<void> onClose() async {
    await _incomingSub?.cancel();
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    await _ringtonePlayer.dispose();
   if (isInCall.value) {
  await engine?.leaveChannel();
    }
    await engine?.release();
    engine = null;

    super.onClose();
  }

  // ==================================================
  // 🔐 TOKEN (PRODUCTION SAFE)
//  Future<String?> _fetchAgoraToken(String channel) async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) return null;

//       final uid = user.uid.hashCode;


//       final result = await FirebaseFunctions.instanceFor(
//         region: 'asia-south1',
//       ).httpsCallable('getAgoraToken').call({
//         'channelName': channel,
//         'uid': uid,
//       });

//       return result.data['token']; 
//     } catch (e) {
//       return null;
//     }
//   }



  // ==================================================
Future<void> initializeEngine() async {
  if (_engineReady) return;

  if (!_permissionGranted) {
    final status = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (!status[Permission.microphone]!.isGranted) {
      throw Exception("Microphone permission denied");
    }

    _permissionGranted = true;
  }

  engine = createAgoraRtcEngine();
  await engine!.initialize(RtcEngineContext(appId: appId));

  engine!.registerEventHandler(
    RtcEngineEventHandler(
      onUserJoined: (_, uid, __) => remoteUid.value = uid,
      onUserOffline: (_, __, ___) => endCall(),
      onLeaveChannel: (_, __) => isInCall.value = false,
    ),
  );

  _engineReady = true;
}


  // ==================================================
 void _listenForIncomingCalls() {
  final user = _auth.currentUser;

  if (user == null) {
 
    return;
  }

  final uid = user.uid;

  _incomingSub?.cancel(); // prevent double listeners

  _incomingSub = _firestore
      .collection("calls")
      .where("receiverId", isEqualTo: uid)
      .where("status", isEqualTo: "ringing")
      .snapshots()
      .listen((snap) async {
    for (final doc in snap.docs) {
      final data = doc.data();

      final repo = CallRepository();

      final call = await repo.decryptIncomingCall(data);
      if (call == null) continue;

      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!_answered) {
          endCall(call.callId);
        }
      });

      incomingCall.value = call;
      isReceivingCall.value = true;
      _activeCall = call;
      callType.value = call.type;
      _answered = false;

      await _playIncomingTone();

      if (Get.currentRoute != IncomingCallScreen.routeName) {
        Get.toNamed(
          IncomingCallScreen.routeName,
          arguments: call.toMap(),
        );
      }
    }
  });
}




  // ==================================================
  // 📞 START CALL
Future<void> startCall({required CallModel call}) async {
  await initializeEngine();

  _activeCall = call;
  currentCallId = call.callId;
  currentChannel = call.channelName;
  callType.value = call.type;

  if (call.token.isEmpty || call.mediaKey.isEmpty) {
    throw Exception("Call token or mediaKey missing");
  }

  await _joinChannel(
    call.token,
    call.channelName,
    mediaKeyB64: call.mediaKey,
  );
}



  // ==================================================
Future<void> acceptCall(String callId) async {
  final snap =
      await _firestore.collection("calls").doc(callId).get();
  if (!snap.exists) return;

  final repo = CallRepository();
  final call = await repo.decryptIncomingCall(snap.data()!);
  if (call == null) {
    Get.snackbar("Call Error", "Unable to decrypt call");
    return;
  }

  await snap.reference.update({'status': 'accepted'});

  _answered = true;
  _activeCall = call;
  currentCallId = call.callId;
  callType.value = call.type;

  await _stopTone();
}




  // ==================================================
Future<void> _joinChannel(
  String token,
  String channel, {
  required String mediaKeyB64,
}) async {
  final user = _auth.currentUser;
  if (user == null) throw Exception("User not logged in");

  final uid = agoraUidFromFirebaseUid(user.uid);

  await engine!.enableAudio();

  if (isVideoCall) {
    await engine!.enableVideo();
    await engine!.startPreview();
  }

  // 🔐 Encryption
  final keyBytes = base64Decode(mediaKeyB64);
  if (![16, 24, 32].contains(keyBytes.length)) {
    throw Exception("Invalid Agora encryption key length");
  }

  final encryptionKey = base64Encode(keyBytes);

  if (!_encryptionEnabled) {
    await engine!.enableEncryption(
      enabled: true,
      config: EncryptionConfig(
        encryptionMode: EncryptionMode.aes256Gcm,
        encryptionKey: encryptionKey,
      ),
    );
    _encryptionEnabled = true;
  }

  // ✅ JOIN ONLY ONCE
  await engine!.joinChannel(
    token: token,
    channelId: channel,
    uid: uid,
    options: const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      autoSubscribeAudio: true,
      autoSubscribeVideo: true,
    ),
  );

  isInCall.value = true;
  _startTimer();
}



  // ==================================================
Future<void> endCall([String? id]) async {
  final callId = id ?? currentCallId;

  if (callId != null) {
    await _firestore
        .collection("calls")
        .doc(callId)
        .update({'status': 'ended'});
  }

  await _stopTone();
  await engine?.leaveChannel();

  _activeCall = null;
  currentCallId = null;
  currentChannel = null;
  _answered = false;

  isInCall.value = false;
  isReceivingCall.value = false;
  _encryptionEnabled = false;

  _stopTimer();

  // 🔥 FORCE UI EXIT
  Get.offAllNamed('/home');
}


  // ==================================================
  void toggleMute() {
    isMuted.toggle();
    engine?.muteLocalAudioStream(isMuted.value);
  }

  Future<void> toggleSpeaker() async {
    isSpeakerOn.toggle();
    await engine?.setEnableSpeakerphone(isSpeakerOn.value);
  }

  void toggleVideo() {
    if (!isVideoCall) return;
    localVideoEnabled.toggle();
    engine?.muteLocalVideoStream(!localVideoEnabled.value);
  }

  void switchCamera() {
    if (isVideoCall) engine?.switchCamera();
  }

  // ==================================================
  void _startTimer() {
    callSeconds.value = 0;
    _callTimer?.cancel();
    _callTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => callSeconds++);
  }

  void _stopTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

Future<void> _playIncomingTone() async {
  await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
  await _ringtonePlayer.play(
    AssetSource('sounds/incoming_call.mp3'),
  );

  // ✅ Native haptic (Android 14 + iOS safe)
  HapticFeedback.mediumImpact();
}


Future<void> _stopTone() async {
  await _ringtonePlayer.stop();
  // nothing else needed
}

}
