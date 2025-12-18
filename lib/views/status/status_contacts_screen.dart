import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'package:adchat/controller/controller/status_controller.dart';
import '../../models/status_model.dart';
import '../../widget/status/status_ring.dart';
import 'status_viewer_screen.dart';
import 'confirm_status_screen.dart';

// ✅ IMPORT FUNCTIONS (not widget)
import 'package:adchat/widget/picker/picker_widget.dart';

class StatusContactsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/status-contacts';

  const StatusContactsScreen({super.key});

  @override
  ConsumerState<StatusContactsScreen> createState() =>
      _StatusContactsScreenState();
}

class _StatusContactsScreenState
    extends ConsumerState<StatusContactsScreen> {
  late final StatusController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = ref.read(statusControllerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.bindVisibleStatuses();
    });
  }

  // 📸 Pick image (gallery) and go to confirm screen
  Future<void> _pickAndCreateStatus() async {
    final File? file = await pickImageFromGallery(context);
    if (file == null) return;

    Get.to(() => ConfirmStatusScreen(file: file));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statusControllerProvider);
    final statuses = state.statuses;

    if (state.loading && statuses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: statuses.isEmpty
          ? const Center(
              child: Text(
                'No statuses yet',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final Status status = statuses[index];

                return ListTile(
                  leading: StatusRing(
                    imageUrl: status.profilePic,
                    ringCount: status.statusUrl.length,
                  ),
                  title: Text(
                    status.username,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${status.statusUrl.length} updates',
                  ),
                  onTap: () {
                    Get.to(
                      () => StatusViewerScreen(ownerStatus: status),
                    );
                  },
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndCreateStatus,
        child: const Icon(Icons.add),
      ),
    );
  }
}
