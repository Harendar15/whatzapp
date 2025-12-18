// lib/widget/chat/my_text_card.dart
// COMPLETELY FIXED MEDIA + TEXT HANDLING

import '/utils/assets.dart';
import '/utils/dimensions.dart';
import '/utils/size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:swipe_to/swipe_to.dart';

import '../../../../models/message_model.dart';
import '../../../../utils/custom_color.dart';
import 'text_image_gif_widget.dart';

class MyTextCard extends StatelessWidget {
  final String message;        // text or fileUrl
  final String date;
  final MessageModel type;
  final void Function(DragUpdateDetails)? onLeftSwipe;
  final String repliedText;
  final String username;
  final MessageModel repliedMessageType;
  final bool isSeen;
  final Map<String, List<String>> reactions;

  const MyTextCard({
    super.key,
    required this.message,
    required this.date,
    required this.type,
    required this.onLeftSwipe,
    required this.repliedText,
    required this.username,
    required this.repliedMessageType,
    required this.isSeen,
    this.reactions = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SwipeTo(
      onLeftSwipe: onLeftSwipe,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildReplyBlock(),
                  _buildMainMessageBubble(context),
                  if (reactions.isNotEmpty) _reactionRow(),
                  const SizedBox(height: 14),
                ],
              ),
              _buildTimeSeen(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------
  // MESSAGE BUBBLE
  // -------------------

  Widget _buildMainMessageBubble(BuildContext context) {
    return Container(
      padding: type.isText
          ? const EdgeInsets.fromLTRB(14, 10, 35, 10)
          : const EdgeInsets.all(6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
        minWidth: 80,
      ),
      decoration: BoxDecoration(
        color: type == MessageModel.audio
            ? Colors.transparent
            : CustomColor.primaryColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextImageGIFWidget(
        me: true,
        color: CustomColor.white,
        message: message,
        type: type,
      ),
    );
  }

  // -------------------
  // REPLY BLOCK
  // -------------------

  Widget _buildReplyBlock() {
    if (repliedText.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: CustomColor.primaryColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextImageGIFWidget(
            me: true,
            color: Colors.white70,
            message: repliedText,
            type: repliedMessageType,
          ),
        ],
      ),
    );
  }

  // -------------------
  // REACTIONS
  // -------------------

  Widget _reactionRow() {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: reactions.entries.map((e) {
          final emoji = e.key;
          final count = e.value.length;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count > 1 ? "$emoji $count" : emoji,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------
  // TIME + SEEN TICK
  // -------------------

  Widget _buildTimeSeen() {
    return Positioned(
      bottom: 2,
      right: 6,
      child: Row(
        children: [
          Text(
            date,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
          const SizedBox(width: 4),
          isSeen
              ? SvgPicture.asset(
                  Assets.checkMark,
                  height: 14,
                  color: CustomColor.messageSeenColor,
                )
              : const Icon(Icons.done_rounded, size: 14, color: Colors.white70),
        ],
      ),
    );
  }
}
