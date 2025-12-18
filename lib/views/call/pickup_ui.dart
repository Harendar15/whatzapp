import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adchat/widget/safe_image.dart';
import '../../models/call_model.dart';
import '../../controller/call/call_controller.dart';

class PickupUI extends StatelessWidget {
  final CallModel call;

  const PickupUI({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CallController>();

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SafeImage(url: call.callerImage, size: 120),

            const SizedBox(height: 12),
            Text("${call.callerName} is calling...",
                style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  onPressed: () => controller.acceptCall(call.callId),
                  child: const Icon(Icons.call),
                ),
                const SizedBox(width: 30),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => controller.endCall(call.callId),
                  child: const Icon(Icons.call_end),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
