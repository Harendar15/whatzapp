import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:adchat/controller/call/call_controller.dart';
import 'package:adchat/models/call_model.dart';
import 'package:adchat/widget/safe_image.dart';

class OutgoingCallScreen extends StatelessWidget {
  static const String routeName = '/outgoing-call';

  OutgoingCallScreen({super.key});

  final CallController controller = Get.find<CallController>();

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        (Get.arguments ?? {}) as Map<String, dynamic>;

    final name = args["receiverName"] ?? "Unknown";
    final image = args["receiverImage"] ?? "";
    final isVideo = args["type"] == "video";
    final callId = args["callId"];

    /// 🔥 START CALL ONLY ONCE AFTER UI LOAD
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!controller.isInCall.value) {
    controller.startCall(
      call: CallModel.fromMap(args),
    );
  }
});



    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Blur background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SafeImage(
                  url: image,
                  size: 140,
                  borderRadius: BorderRadius.circular(100),
                ),

                const SizedBox(height: 20),

                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Calling…",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),

                const SizedBox(height: 120),

                /// Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    /// MUTE
                    Obx(() {
                      return _roundButton(
                        icon: controller.isMuted.value
                            ? Icons.mic_off
                            : Icons.mic,
                        label: controller.isMuted.value ? "Unmute" : "Mute",
                        onTap: () {
                          if (controller.engine != null) {
                            controller.toggleMute();
                          }
                        },
                      );
                    }),

                    /// SPEAKER
                    Obx(() {
                      return _roundButton(
                        icon: controller.isSpeakerOn.value
                            ? Icons.volume_up
                            : Icons.hearing,
                        label: controller.isSpeakerOn.value
                            ? "Speaker"
                            : "Earpiece",
                        onTap: controller.toggleSpeaker,
                      );
                    }),

                    /// VIDEO
                    if (isVideo)
                      Obx(() {
                        return _roundButton(
                          icon: controller.localVideoEnabled.value
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: controller.localVideoEnabled.value
                              ? "Camera"
                              : "Off",
                          onTap: controller.toggleVideo,
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 50),

                /// END CALL
                GestureDetector(
                  onTap: () => controller.endCall(callId),
                  child: Container(
                    height: 82,
                    width: 82,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent,
                          blurRadius: 25,
                          spreadRadius: 4,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.18),
                  blurRadius: 10,
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
