// lib/views/community/community_screen.dart

import 'package:adchat/controller/repo/community_repository.dart';
import 'package:adchat/models/community.dart';
import 'package:adchat/views/group/group_chat_screen.dart';
import 'package:adchat/views/community/community_groups_screen.dart';
import 'package:adchat/views/community/community_members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityScreen extends ConsumerWidget {
  final String communityId;

  const CommunityScreen({super.key, required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(communityRepositoryProvider);

    return StreamBuilder<Community?>(
      stream: repo.watchCommunity(communityId),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final c = snap.data!;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final bool isAdmin =
            currentUid != null && c.admins.contains(currentUid);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(c.name),
              actions: [
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "Delete community",
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Delete community?"),
                          content: const Text(
                            "This will remove the community for all members. "
                            "Are you sure?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await repo.deleteCommunity(communityId);
                          if (context.mounted) {
                            Navigator.pop(context); // close CommunityScreen
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text("Failed to delete community: $e"),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
              ],
              bottom: const TabBar(
                indicatorWeight: 3,
                tabs: [
                  Tab(text: "Announcements"),
                  Tab(text: "Groups"),
                  Tab(text: "Members"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 1️⃣ ANNOUNCEMENTS TAB
                _buildAnnouncementsTab(context, c),

                // 2️⃣ GROUPS TAB
                CommunityGroupsScreen(community: c),

                // 3️⃣ MEMBERS TAB
                CommunityMembersScreen(community: c),
              ],
            ),
          ),
        );
      },
    );
  }

  // ANNOUNCEMENT TAB
  Widget _buildAnnouncementsTab(BuildContext context, Community c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SafeImage(url: c.communityPic, size: 90, isCircular: false),

        const SizedBox(height: 16),
        Text(
          c.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),
        Text(
          c.description.isEmpty ? "No description" : c.description,
          style: const TextStyle(fontSize: 14),
        ),

        const SizedBox(height: 24),
        const Divider(),

        ListTile(
          tileColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.campaign, color: Colors.green),
          title: Text("${c.name} – Announcements"),
          subtitle: const Text("Admin-only messages"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupChatScreen(
                  groupId: c.announcementGroupId,
                  groupName: "${c.name} • Announcements",
                ),
              ),
            );
          },
        )
      ],
    );
  }
}
