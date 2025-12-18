import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:adchat/widget/safe_image.dart';

import '../../controller/controller/chat_controller.dart';
import '../../models/community.dart';
import '../../models/group.dart';
import '../chat/chat_screen.dart';

class CommunityGroupsScreen extends ConsumerWidget {
  final Community community;
  const CommunityGroupsScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatController = ref.watch(chatControllerProvider);

    final groupIds = community.groupIds;

    return Scaffold(
      appBar: AppBar(title: const Text("Community Groups")),
      body: groupIds.isEmpty
          ? const Center(child: Text("No groups added to this community"))
          : StreamBuilder<List<Group>>(
              stream: chatController.chatGroupsById(groupIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = snapshot.data ?? [];
                if (groups.isEmpty) {
                  return const Center(child: Text("No accessible groups"));
                }

                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    return ListTile(
                      leading: SafeImage(url: g.groupPic, size: 45),
                      title: Text(g.name),
                      subtitle: Text(g.lastMessage),
                      onTap: () {
                        Get.to(
                          () => ChatScreen(
                            name: g.name,
                            uid: g.groupId,
                            isGroupChat: true,
                            profilePic: g.groupPic,
                            groupData: g,
                            isCommunityChat: false,
                            isHideChat: false,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
