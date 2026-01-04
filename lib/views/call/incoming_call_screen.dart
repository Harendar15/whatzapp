import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adchat/controller/call/call_controller.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:adchat/views/call/outgoing_call_screen.dart';
class IncomingCallScreen extends StatefulWidget {
  static const String routeName = '/incoming-call-screen';

  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _pulse;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();

    /// SAFE ARGUMENT GET
    data = Get.arguments is Map ? Map<String, dynamic>.from(Get.arguments) : {};

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.10)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CallController callController = Get.find();

    final name = data["callerName"] ?? "Unknown";
    final image = data["callerImage"] ?? "";
    final callId = data["callId"];
    final isVideo = data["type"] == "video";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // BG Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // BLUR
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
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) {
                    return Transform.scale(
                      scale: _pulse.value,
                      child: SafeImage(
                        url: image,
                        size: 150,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 25),

                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  isVideo ? "Incoming Video Call" : "Incoming Voice Call",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 70),

                /// WhatsApp style bottom actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _circleButton(
                      icon: Icons.call_end,
                      color: Colors.redAccent,
                      label: "Decline",
                      onTap: () async {
                        await callController.endCall(callId);
                        Get.back(); // 👈 ensure UI closes
                      },

                    ),

                    _circleButton(
                      icon: Icons.call,
                      color: Colors.green,
                      label: "Answer",
                    onTap: () async {
  if (!callController.isInCall.value) {
    await callController.acceptCall(callId);

    Get.offNamed(
      OutgoingCallScreen.routeName,
      arguments: data,
    );
  }
}


                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 20,
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}
