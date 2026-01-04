import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'package:adchat/controller/auth/login_controller.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/widget/custom_loader.dart';

class OTPScreen extends ConsumerStatefulWidget {
  static const routeName = '/otp';
  const OTPScreen({super.key});

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  late final String verificationId;
  late final String phoneNumber;

  final TextEditingController otpController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>?;

    verificationId = args?['verificationId'] ?? '';
    phoneNumber = args?['phoneNumber'] ?? '';

    if (verificationId.isEmpty) {
      debugPrint('❌ OTP Screen opened without verificationId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginController = Get.find<LoginController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Obx(
        () => loginController.isVerifyCode.value
            ? const CustomLoader()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Enter OTP sent to",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "••••••",
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ✅ VERIFY BUTTON
                    ElevatedButton(
                      onPressed: () async {
                        final otp = otpController.text.trim();

                        if (verificationId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text("OTP expired. Please resend OTP."),
                            ),
                          );
                          return;
                        }

                        if (otp.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Enter valid 6-digit OTP"),
                            ),
                          );
                          return;
                        }

                        await ref.read(authRepositoryProvider).verifyOTP(
                              context: context,
                              otp: otp,
                              verificationId: verificationId,
                              phoneNumber: phoneNumber,
                            );
                      },
                      child: const Text("Verify OTP"),
                    ),

                    const SizedBox(height: 12),

                    // ✅ RESEND OTP BUTTON
                    TextButton(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).resendOtp(
                              context: context,
                              phoneNumber: phoneNumber,
                            );
                      },
                      child: const Text("Resend OTP"),
                    ),
                  ],
                ),
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
