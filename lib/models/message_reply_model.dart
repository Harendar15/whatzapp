// lib/models/message_reply_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_model.dart';

/// A model representing a reply to a message.
class MessageReply {
  final String message;
  final bool isMe;
  final MessageModel messageModel;

  MessageReply(
    this.message,
    this.isMe,
    this.messageModel,
  );
}

/// Riverpod provider for message reply state
final messageReplyProvider = StateProvider<MessageReply?>((ref) => null);
