import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'confirm_status_screen.dart';
import 'package:adchat/controller/controller/status_controller.dart';
import 'package:adchat/helpers/local_storage.dart';
import 'package:adchat/widget/safe_image.dart';
import '../../views/status/status_viewer_screen.dart';
import '../../widget/status/image_picker_widget.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(statusControllerProvider.notifier).bindVisibleStatuses();
    });
  }

void _openPicker(BuildContext context) async {
  final file = await showModalBottomSheet<File>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => imagePickerBottomSheetWidget(context),
  );

  if (file == null) return;

  Get.to(() => ConfirmStatusScreen(file: file));

}


  @override
  Widget build(BuildContext context) {
    final statusState = ref.watch(statusControllerProvider);
    final myUid = LocalStorage.getMyUid() ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("Status")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt, color: Colors.white),
        onPressed: () => _openPicker(context), // ✅ FIXED
      ),
      body: statusState.loading
          ? const Center(child: CircularProgressIndicator())
          : _buildStatusList(statusState.statuses, myUid),
    );
  }

  Widget _buildStatusList(List statuses, String myUid) {
    if (statuses.isEmpty) {
      return _createStatusTile(); // no status → show add tile
    }

    final myStatus = statuses.where((s) => s.uid == myUid).toList();
    final others = statuses.where((s) => s.uid != myUid).toList();

    return ListView(
      children: [
        if (myStatus.isNotEmpty)
          _myStatusTile(myStatus.first)
        else
          _createStatusTile(),

        if (others.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 16, bottom: 8),
            child: Text(
              "Recent updates",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

        ...others.map((s) => _statusTile(s)),
      ],
    );
  }

  Widget _myStatusTile(dynamic s) {
    return ListTile(
      leading: SafeImage(url: s.profilePic, size: 52),
      title: const Text("My Status"),
      subtitle: Text(
        s.statusUrl.isEmpty
            ? "Tap to add status"
            : "Tap to view (${s.statusUrl.length})",
      ),
      onTap: () {
        Get.to(() => StatusViewerScreen(ownerStatus: s));
      },
    );
  }

  Widget _createStatusTile() {
    return ListTile(
      leading: Stack(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundImage: AssetImage("assets/logo/user.png"),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      title: const Text("My Status"),
      subtitle: const Text("Tap to add status update"),
      onTap: () => _openPicker(context), // ✅ FIXED
    );
  }

  Widget _statusTile(dynamic s) {
    return ListTile(
      leading: SafeImage(url: s.profilePic, size: 52),
      title: Text(s.username),
      subtitle: Text("${s.statusUrl.length} updates"),
      onTap: () => Get.to(() => StatusViewerScreen(ownerStatus: s)),
    );
  }
}
