// lib/views/chat/message_card_widget.dart
// Updated message card that formats timeSent robustly and shows safe avatar.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adchat/widget/safe_image.dart';

Widget messageCardWidget(
  BuildContext context, {
  required String name,
  required String lastMessage,
  required String pic,
  required String id,
  required bool isGroupchat,
  bool isSelected = false,
  dynamic timeSent, // can be int (epoch ms), DateTime, or null
}) {
  String timeString() {
    try {
      if (timeSent == null) return '';
      DateTime dt;
      if (timeSent is DateTime) {
        dt = timeSent;
      } else if (timeSent is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(timeSent);
      } else {
        final parsed = int.tryParse(timeSent.toString());
        if (parsed != null) {
          dt = DateTime.fromMillisecondsSinceEpoch(parsed);
        } else {
          return '';
        }
      }
      // show time if today else date
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return DateFormat.jm().format(dt);
      }
      return DateFormat.yMMMd().format(dt);
    } catch (_) {
      return '';
    }
  }

  final ts = timeString();

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: ListTile(
      leading: SafeImage(
        url: pic,
        size: 44,
      ),
      title: Text(name),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ts.isNotEmpty)
            Text(
              ts,
              style: const TextStyle(fontSize: 12),
            ),
          if (isSelected)
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 18,
            ),
        ],
      ),
      onTap: () {
        // Parent (InkWell) controls tap behavior.
      },
    ),
  );
}
