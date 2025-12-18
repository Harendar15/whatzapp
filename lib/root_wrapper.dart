// lib/root_wrapper.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:adchat/views/auth/login_screen.dart';
import 'package:adchat/views/home/home_screen.dart';
import 'package:adchat/controller/call/call_controller.dart';
import 'helpers/local_storage.dart';

class RootWrapper extends StatefulWidget {
  const RootWrapper({super.key});

  @override
  State<RootWrapper> createState() => _RootWrapperState();
}

class _RootWrapperState extends State<RootWrapper> {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
      if (!Get.isRegistered<CallController>()) {
      Get.put(CallController(), permanent: true);
    }

    _authSub =
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;

      // ⛔ NOT LOGGED IN
      if (user == null) {
        Get.offAll(() => const LoginScreen());
        return;
      }

      // 🔥 LOGGED IN
        LocalStorage.saveMyUid(user.uid);

      // 🎉 GO TO HOME
      Get.offAll(() => const  HomeScreen());
    });
  }

  @override
  void dispose() {
    _authSub?.cancel(); // ✅ VERY IMPORTANT
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Welcome to WhatZapp...",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
