import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adchat/models/message.dart';

class MessageInfoScreen extends StatelessWidget {
  final Message message;

  const MessageInfoScreen({super.key, required this.message});

  // FIXED: supports both DateTime & int
  String formatTime(dynamic value) {
    if (value == null) return "-";

    DateTime dt;

    if (value is DateTime) {
      dt = value;
    } else if (value is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(value);
    } else {
      return "-";
    }

    return DateFormat("hh:mm a").format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Message info")),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // WhatsApp-style message bubble preview
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message.text.isEmpty ? "[Media]" : message.text,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          const Divider(height: 30),

          // Seen info
          ListTile(
            leading: const Icon(Icons.done_all, color: Colors.blueAccent),
            title: const Text("Seen"),
            subtitle: Text(
              message.isSeen
                  ? formatTime(message.timeSent)
                  : "Not seen yet",
            ),
          ),

          // Delivered info (same timestamp for WhatsApp clone)
          ListTile(
            leading: const Icon(Icons.check, color: Colors.grey),
            title: const Text("Delivered"),
            subtitle: Text(formatTime(message.timeSent)),
          ),

          // Sent info
          ListTile(
            leading: const Icon(Icons.send, color: Colors.grey),
            title: const Text("Sent"),
            subtitle: Text(formatTime(message.timeSent)),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}
