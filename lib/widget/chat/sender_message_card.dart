// lib/widget/chat/sender_text_card.dart
// MIRROR OF MYTEXTCARD BUT FOR OTHER USER

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:swipe_to/swipe_to.dart';

import '../../../../models/message_model.dart';
import '../../../../utils/custom_color.dart';
import '../../../../utils/dimensions.dart';
import 'text_image_gif_widget.dart';
import '../../../../utils/size.dart';

class SenderTextCard extends StatelessWidget {
  final String message;
  final String date;
  final MessageModel type;
  final void Function(DragUpdateDetails)? onRightSwipe;
  final String repliedText;
  final String username;
  final MessageModel repliedMessageType;
  final Map<String, List<String>> reactions;
  final String? fileUrl;


  const SenderTextCard({
    super.key,
    required this.message,
    required this.date,
    required this.type,
    required this.onRightSwipe,
    required this.repliedText,
    required this.username,
    required this.repliedMessageType,
     this.fileUrl,
    this.reactions = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SwipeTo(
      onRightSwipe: onRightSwipe,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReplyBlock(context),
                  _buildMainMessageBubble(context),
                  if (reactions.isNotEmpty) _buildReactionRow(),
                  const SizedBox(height: 14),
                ],
              ),
              _buildTimeWidget(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainMessageBubble(BuildContext context) {
    return Container(
      padding: type.isText
          ? const EdgeInsets.fromLTRB(12, 10, 35, 10)
          : const EdgeInsets.all(6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
        minWidth: 80,
      ),
      decoration: BoxDecoration(
        color: Get.isDarkMode
            ? CustomColor.appBarColor.withOpacity(0.6)
            : CustomColor.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextImageGIFWidget(
        message: message,
        type: type,
        fileUrl: fileUrl, // ✅ PASS URL
        color: Get.isDarkMode ? Colors.white : Colors.black87,
      ),

    );
  }

  Widget _buildReplyBlock(BuildContext context) {
    if (repliedText.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextImageGIFWidget(
            message: repliedText,
            type: repliedMessageType,
            color: Get.isDarkMode ? Colors.white : Colors.black87,
          )
        ],
      ),
    );
  }

  Widget _buildReactionRow() {
    return Row(
      children: reactions.entries.map((e) {
        final emoji = e.key;
        final count = e.value.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count > 1 ? "$emoji $count" : emoji,
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeWidget(BuildContext context) {
    return Positioned(
      bottom: 2,
      right: 25,
      child: Text(
        date,
        style: TextStyle(
          fontSize: 10,
          color: Get.isDarkMode ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
