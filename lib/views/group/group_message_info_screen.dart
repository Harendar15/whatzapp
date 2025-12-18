import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:adchat/models/group_message_model.dart';

class GroupMessageInfoScreen extends StatelessWidget {
  final GroupMessage message;

  const GroupMessageInfoScreen({
    super.key,
    required this.message,
  });

  // Accepts int (ms since epoch), numeric-string, or ISO string and returns DateTime.
  DateTime _dateTimeFrom(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) {
      final trimmed = v.trim();
      // numeric string -> epoch millis
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      // try ISO parse
      try {
        return DateTime.parse(trimmed);
      } catch (_) {
        // fallback to epoch 0
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final dt = _dateTimeFrom(message.timeSent);
    final sentAt = DateFormat.yMMMd().add_jm().format(dt);

    final seenCount = (message.seenBy ).length;
    final reactions = message.reactions ;

    String typeLabel;
    switch (message.type) {
      case 'text':
        typeLabel = 'Text message';
        break;
      case 'image':
        typeLabel = 'Image';
        break;
      case 'video':
        typeLabel = 'Video';
        break;
      case 'audio':
        typeLabel = 'Audio';
        break;
      default:
        typeLabel = 'Message';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              typeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            if (message.type == 'text') ...[
              const SizedBox(height: 4),
              Text(
                '(text message)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Sent'),
              subtitle: Text(sentAt),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.remove_red_eye_outlined),
              title: Text(
                'Seen by $seenCount member${seenCount == 1 ? '' : 's'}',
              ),
            ),
            if (reactions.isNotEmpty) ...[
              const Divider(),
              const ListTile(
                leading: Icon(Icons.emoji_emotions_outlined),
                title: Text('Reactions'),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 72, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: reactions.entries.map((entry) {
                    final emoji = entry.key;
                    final count = (entry.value as List).length;
                    return Chip(
                      label: Text(
                        count > 1 ? '$emoji $count' : emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
