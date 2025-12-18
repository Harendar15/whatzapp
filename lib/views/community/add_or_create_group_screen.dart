import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import '../../controller/community/community_controller.dart';
import '../../utils/custom_color.dart';
import 'select_group_screen.dart';

class AddGroupScreen extends ConsumerStatefulWidget {
  final List<String> groupId;
  final String communityId;

  const AddGroupScreen({
    super.key,
    required this.groupId,
    required this.communityId,
  });

  @override
  ConsumerState<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends ConsumerState<AddGroupScreen> {

  @override
  void initState() {
    super.initState();

    // ✅ clear selection ONCE when screen opens
    Future.microtask(() {
      ref.read(communityControllerProvider).selectedGroupsId.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(communityControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add / Create Group"),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectContactTitleWidget(),
          Expanded(
            child: SelectGroup(
              groupId: widget.groupId,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CustomColor.tabColor,
        onPressed: () => controller.updateCommunity(context),
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
    );
  }

  Widget _selectContactTitleWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        "Groups you administer",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }
}
