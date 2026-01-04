import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../helpers/prefs_services.dart';
import '../welcome/welcome_screen.dart';
import '../../root_wrapper.dart';


class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';


  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {
      bool completed = PrefHelper.isCompleted();

      if (completed) {
        Get.offAll(() => const RootWrapper());
      } else {
        Get.offAllNamed(WelcomeScreen.routeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Welcome to AdChat...",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
