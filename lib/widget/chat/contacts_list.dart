// lib/widget/chat/contacts_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import '../../../../controller/controller/chat_controller.dart';
import '../../../../models/chat_contact_model.dart';
import '../../../../models/group.dart';
import '../../../../models/community.dart';
import '../../../../utils/custom_color.dart';
import '../../../../utils/strings.dart';
import '../custom_loader.dart';
import 'message_card_widget.dart';

class ContactsList extends ConsumerWidget {
  const ContactsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          StreamBuilder<List<Group>>(
            stream: ref.watch(chatControllerProvider).chatGroups(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CustomLoader();
              }
              final groups = snapshot.data ?? [];
              if (groups.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return InkWell(
                    onTap: () => Get.toNamed('/mobile-chat-screen', arguments: {
                      'name': group.name,
                      'uid': group.groupId,
                      'isGroupChat': true,
                      'profilePic': group.groupPic,
                      'isHideChat': false,
                    }),
                    child: messageCardWidget(
                      context,
                      name: group.name,
                      lastMessage: group.lastMessage,
                      pic: group.groupPic,
                      timeSent: group.timeSent,
                      id: group.groupId,
                      isGroupchat: true,
                      isSelected: false,
                    ),
                  );
                },
              );
            },
          ),

          StreamBuilder<List<Community>>(
            stream: ref.watch(chatControllerProvider).chatCommunities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final communities = snapshot.data ?? [];
              if (communities.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: communities.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final community = communities[index];
                  return InkWell(
                    onTap: () => Get.toNamed('/mobile-chat-screen', arguments: {
                      'name': community.name,
                      'uid': community.communityId,
                      'isCommunityChat': true,
                      'profilePic': community.communityPic,
                      'isGroupChat': false,
                      'isHideChat': false,
                    }),
                    child: messageCardWidget(
                      context,
                      name: community.name,
                      lastMessage: community.lastMessage,
                      pic: community.communityPic,
                      timeSent: community.timeSent,
                      id: community.communityId,
                      isGroupchat: false,
                      isSelected: false,
                    ),
                  );
                },
              );
            },
          ),

          StreamBuilder<List<ChatContactModel>>(
            stream: ref.watch(chatControllerProvider).chatContacts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CustomLoader();
              }

              final chatContacts = snapshot.data ?? [];
              if (chatContacts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      Strings.noCallData.tr,
                      style: TextStyle(
                        fontSize: 16,
                        color: Get.isDarkMode ? CustomColor.greyColor : CustomColor.black,
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chatContacts.length,
                itemBuilder: (context, index) {
                  final contact = chatContacts[index];
                  return InkWell(
                    onTap: () => Get.toNamed('/mobile-chat-screen', arguments: {
                      'name': contact.name,
                      'uid': contact.contactId,
                      'isGroupChat': false,
                      'profilePic': contact.profilePic,
                      'isHideChat': contact.isHideChat,
                    }),
                    child: messageCardWidget(
                      context,
                      name: contact.name,
                      lastMessage: contact.lastMessage,
                      pic: contact.profilePic,
                      timeSent: contact.timeSent,
                      id: contact.contactId,
                      isGroupchat: false,
                      isSelected: false,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
