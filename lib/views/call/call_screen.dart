// lib/views/call/call_screen.dart
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:adchat/controller/call/call_controller.dart';
import 'package:adchat/widget/safe_image.dart';

class CallScreen extends StatelessWidget {
  static const String routeName = '/call-screen';

  CallScreen({super.key});

  final Map<String, dynamic> args =
    (Get.arguments ?? {}) as Map<String, dynamic>;

  final CallController controller = Get.find<CallController>();

  String _buildOtherName() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return args['receiverName'] ?? 'User';
    return myUid == args['callerId']
        ? (args['receiverName'] ?? 'User')
        : (args['callerName'] ?? 'User');
  }

  String _buildOtherImage() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return args['receiverImage'] ?? '';
    return myUid == args['callerId']
        ? (args['receiverImage'] ?? '')
        : (args['callerImage'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
      final String type = args['type'] ?? 'audio';
     
  
    final otherName = _buildOtherName();
    final otherImage = _buildOtherImage();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          // video call UI
          if (controller.isVideoCall) {
            return _buildVideoLayout(otherName, otherImage);
          }

          // audio call UI
          return _buildAudioLayout(otherName, otherImage);
        }),
      ),
    );
  }

  // ----------------------------------------------------------
  // VIDEO CALL LAYOUT
  // ----------------------------------------------------------
  Widget _buildVideoLayout(String otherName, String otherImage) {
    return Stack(
      children: [
        // REMOTE VIDEO
        Positioned.fill(
          child: controller.engine == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Obx(() {
                  if (controller.remoteUid.value == 0) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF141E30), Color(0xFF243B55)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "Connecting video...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  return AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: controller.engine!,
                      canvas: VideoCanvas(
                        uid: controller.remoteUid.value,
                      ),
                      connection: RtcConnection(
                        channelId: controller.currentChannel ?? '',
                      ),
                    ),
                  );
                }),
        ),

        // LOCAL PREVIEW
        Positioned(
          top: 16,
          right: 16,
          child: Obx(() {
            if (!controller.localVideoEnabled.value ||
                controller.engine == null) {
              return const SizedBox.shrink();
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 150,
                width: 110,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: controller.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            );
          }),
        ),

        // TOP NAME + TYPE
        Positioned(
          top: 16,
          left: 16,
          child: Row(
            children: [
              SafeImage(url: otherImage, size: 38),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Video call",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),

        // BOTTOM CONTROLS
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: _buildControlsRow(),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // AUDIO CALL LAYOUT
  // ----------------------------------------------------------
  Widget _buildAudioLayout(String otherName, String otherImage) {
    return Stack(
      children: [
        // beautiful gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),

        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // avatar
            SafeImage(
              url: otherImage,
              size: 130,
              borderRadius: BorderRadius.circular(100),
            ),
            const SizedBox(height: 16),
            Text(
              otherName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Voice call…",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 40),

            // controls
            _buildControlsRow(),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // COMMON CONTROLS
  // ----------------------------------------------------------
  Widget _buildControlsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Obx(() {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _roundIconButton(
              icon: controller.isMuted.value ? Icons.mic_off : Icons.mic,
              label: controller.isMuted.value ? "Unmute" : "Mute",
              bg: Colors.white.withOpacity(0.18),
              onTap: controller.toggleMute,
            ),
            if (controller.isVideoCall)
              _roundIconButton(
                icon: controller.localVideoEnabled.value
                    ? Icons.videocam
                    : Icons.videocam_off,
                label: controller.localVideoEnabled.value ? "Video" : "Camera off",
                bg: Colors.white.withOpacity(0.18),
                onTap: controller.toggleVideo,
              )
            else
              _roundIconButton(
                icon: controller.isSpeakerOn.value
                    ? Icons.volume_up
                    : Icons.hearing,
                label: controller.isSpeakerOn.value ? "Speaker" : "Earpiece",
                bg: Colors.white.withOpacity(0.18),
                onTap: controller.toggleSpeaker,
              ),
            _roundIconButton(
              icon: Icons.call_end,
              label: "End",
              bg: Colors.red,
              onTap: () => controller.endCall(),
            ),
          ],
        );
      }),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String label,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bg.withOpacity(0.5),
                  blurRadius: 18,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        )
      ],
    );
  }
}
