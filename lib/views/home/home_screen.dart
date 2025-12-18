// FINAL FIXED VERSION (Stable)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../controller/selectable list/list_selection_controller.dart';
import '../../views/call/call_tab_screen.dart';
import '../../views/community/community_tab_screen.dart';
import '../../views/select_contacts/select_contacts_screen.dart';
import '../../views/status/confirm_status_screen.dart';
import '../../views/status/status_contacts_screen.dart';
import '../../controller/home_controller.dart';
import '../../utils/dimensions.dart';
import '../home/settings_screen.dart';
import '../../controller/notification/push_notification_controller.dart';
import '../../utils/strings.dart';
import '../../utils/custom_color.dart';
import '../../widget/picker/picker_widget.dart';
import '../../views/call/select_contact_for_call_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const String routeName = '/home';
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {

  final HomeController homeController = Get.put(HomeController());
  final ListSelectionController listController =
      Get.put(ListSelectionController());

  late TabController tabController;
  static const int tabCount = 4;

  @override
  void initState() {
    super.initState();

    // ✅ SAVE FCM TOKEN SAFELY
   WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(seconds: 2));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await Get.find<PushNotificationController>().saveDeviceToken(uid);
      } catch (e) {
        debugPrint("Token save skipped: $e");
      }
    }
  });


    tabController = TabController(length: tabCount, vsync: this);

    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        homeController.selectIndex.value = tabController.index;
      }
    });
  }
  

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: _buildAppBar(context),
        body: TabBarView(
          controller: tabController,
          children: [
           const  CommunityTabScreen(),
            const  SelectContactsScreen(),
            const StatusContactsScreen(),
            CallTabScreen(),
          ],
        ),
        floatingActionButton: _buildFAB(context),
      ),
    );
  }

  // ---------------- TAB BAR ----------------
  PreferredSizeWidget _buildTabBar(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return PreferredSize(
      preferredSize: Size(width, 48),
      child: TabBar(
        controller: tabController,
        indicatorColor: CustomColor.tabColor,
        indicatorWeight: 4,
        tabs: [
          SizedBox(width: width / 16, child: const Tab(icon: Icon(Icons.groups))),
          SizedBox(width: width / 5, child: Tab(text: Strings.chat.tr)),
          SizedBox(width: width / 5, child: Tab(text: Strings.status.tr)),
          SizedBox(width: width / 5, child: Tab(text: Strings.calls.tr)),
        ],
      ),
    );
  }

  // ---------------- APP BAR ----------------
  AppBar _buildAppBar(BuildContext context) {
    final int index = homeController.selectIndex.value;

    return AppBar(
      backgroundColor: CustomColor.primaryColor,
      title: Text(
        Strings.appName,
        style: TextStyle(
          fontSize: Dimensions.largeTextSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (index == 1 || index == 2)
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.camera, color: Colors.white),
            onPressed: () async {
              final img = await pickImageFromCamera(context);
              if (img != null) {
                Get.toNamed(ConfirmStatusScreen.routeName, arguments: img);
              }
            },
          ),

        if (index == 3)
          IconButton(
            icon: const Icon(Icons.add_ic_call, color: Colors.white),
            onPressed: () {
              Get.toNamed(SelectContactForCallScreen.routeName);
            },
          ),

        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (_) => [
            PopupMenuItem(
              child: Text(Strings.settings.tr),
              onTap: () => Future(() => Get.to(() => SettingsScreen())),
            ),
          ],
        ),
      ],
      bottom: _buildTabBar(context),
    );
  }

  // ---------------- FLOATING BUTTON ----------------
  Widget _buildFAB(BuildContext context) {
    final int index = homeController.selectIndex.value;

    if (index == 0) return const SizedBox();

    return FloatingActionButton(
      backgroundColor: CustomColor.tabColor,
      onPressed: () async {
        if (index == 1) {
          Get.toNamed(SelectContactsScreen.routeName);
        } else if (index == 2) {
          final img = await pickImageFromCamera(context);
          if (img != null) {
            Get.toNamed(ConfirmStatusScreen.routeName, arguments: img);
          }
        } else if (index == 3) {
          Get.toNamed(SelectContactForCallScreen.routeName);
        }
      },
      child: Icon(
        index == 3
            ? Icons.add_ic_call
            : index == 2
                ? FontAwesomeIcons.camera
                : Icons.comment,
        color: Colors.white,
      ),
    );
  }
}
