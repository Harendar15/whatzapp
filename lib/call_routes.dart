import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'views/call/incoming_call_screen.dart';
import 'views/call/outgoing_call_screen.dart';
import 'views/call/call_screen.dart';
import 'views/call/select_contact_for_call_screen.dart';

class CallRoutes {
  static final pages = [
    GetPage(
      name: '/select-call-contact',
      page: () => const SelectContactForCallScreen(),
    ),

    GetPage(
      name: IncomingCallScreen.routeName,
      page: () => const IncomingCallScreen(),
    ),

    GetPage(
      name: OutgoingCallScreen.routeName,
      page: () => OutgoingCallScreen(),
    ),

    GetPage(
      name: '/call-screen',
      page: () => CallScreen(),
    ),
  ];
}
