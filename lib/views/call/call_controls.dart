// lib/views/call/call_controls.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/call/call_controller.dart';

class CallControls extends StatelessWidget {
  const CallControls({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CallController>();

    return Obx(() {
      final audioEnabled = !ctrl.isMuted.value;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            heroTag: 'mute',
            backgroundColor:
                audioEnabled ? Colors.black87 : Colors.grey,
            onPressed: ctrl.toggleMute,
            child: Icon(
              audioEnabled ? Icons.mic : Icons.mic_off,
              color: Colors.white,
            ),
          ),
          FloatingActionButton(
            heroTag: 'video',
            backgroundColor:
                ctrl.localVideoEnabled.value ? Colors.black87 : Colors.grey,
            onPressed: ctrl.toggleVideo,
            child: Icon(
              ctrl.localVideoEnabled.value
                  ? Icons.videocam
                  : Icons.videocam_off,
              color: Colors.white,
            ),
          ),
          FloatingActionButton(
            heroTag: 'switch',
            backgroundColor: Colors.black87,
            onPressed: ctrl.switchCamera,
            child: const Icon(Icons.switch_camera, color: Colors.white),
          ),
        ],
      );
    });
  }
}
