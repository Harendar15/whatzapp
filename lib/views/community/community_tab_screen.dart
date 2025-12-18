import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import '../../controller/community/community_controller.dart';
import '../../models/community.dart';
import '../../helpers/local_storage.dart';
import 'community_screen.dart';
import 'community_list_screen.dart';
import '../group/my_groups_screen.dart';
import 'create_community_screen.dart';
import 'package:adchat/widget/safe_image.dart';

class CommunityTabScreen extends ConsumerWidget {
  const CommunityTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communityControllerProvider);

    // ✅ STRICT UID CHECK (MOST IMPORTANT)
    final uid = LocalStorage.getMyUid();
    if (uid == null || uid.isEmpty || uid == "Null") {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<Community>>(
        stream: controller.streamMyCommunities(uid),
        builder: (context, snapshot) {
          // 🔄 Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ Error
          if (snapshot.hasError) {
            return const Center(
              child: Text("Something went wrong"),
            );
          }

          // 🔄 Still waiting for data
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final communities = snapshot.data!;

          // 📭 Empty State
          if (communities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "You are not part of any community",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () =>
                        Get.to(() => const CreateCommunityScreen()),
                    child: const Text("Create Community"),
                  ),
                ],
              ),
            );
          }

          // Show only first 4
          final firstFour = communities.take(4).toList();
          final hasMore = communities.length > 4;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: firstFour.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final cm = firstFour[index];

                    return ListTile(
                      leading: cm.communityPic.isNotEmpty
                          ? SafeImage(url: cm.communityPic, size: 45)
                          : const CircleAvatar(
                              radius: 22,
                              child: Icon(Icons.groups),
                            ),
                      title: Text(cm.name),
                      subtitle: Text(
                        cm.headline.isEmpty ? " " : cm.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        LocalStorage.saveCommunityId(
                          id: cm.communityId,
                        );
                        Get.to(
                          () => CommunityScreen(
                            communityId: cm.communityId,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ⬇ Bottom actions
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 20, top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasMore)
                      TextButton(
                        onPressed: () {
                          Get.to(() =>
                              const CommunityListScreen());
                        },
                        child: const Text("View more"),
                      ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Get.to(() => const MyGroupsScreen()),
                      icon: const Icon(Icons.group),
                      label: const Text("My Groups"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // ➕ Create community
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Get.to(() => const CreateCommunityScreen()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
