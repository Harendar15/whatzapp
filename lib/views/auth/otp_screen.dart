// lib/views/auth/otp_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:adchat/controller/auth/login_controller.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/widget/custom_loader.dart';

class OTPScreen extends ConsumerStatefulWidget {
  static const routeName = '/otp';
  const OTPScreen({super.key});

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  String verificationId = "";
  String phoneNumber = "";
  final TextEditingController otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments ?? {};
    verificationId = args["verificationId"] ?? "";
    phoneNumber = args["phoneNumber"] ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();

    return Scaffold(
      appBar: AppBar(title: Text("Verify OTP")),
      body: Obx(
        () => controller.isVerifyCode.value
            ? const CustomLoader()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Enter the OTP sent to $phoneNumber"),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: otpController,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ElevatedButton(
                    child: Text("Verify"),
                    onPressed: () async {
                      final otp = otpController.text.trim();
                      if (otp.length == 6) {
                        await ref.read(authRepositoryProvider).verifyOTP(
                              context: context,
                              otp: otp,
                              verificationId: verificationId,
                              phoneNumber: phoneNumber,
                            );
                      }
                    },
                  ),
                  TextButton(
                    child: Text("Resend OTP"),
                    onPressed: () {
                      ref
                          .read(authRepositoryProvider)
                          .resendOtp(context: context, phoneNumber: phoneNumber);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }
}
