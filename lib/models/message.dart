// lib/models/message.dart
import 'dart:convert';

import 'package:adchat/models/message_model.dart';

class Message {
  final String senderId;
  final String recieverid;
  final String text; // decrypted plaintext for UI (or caption for media)
  final MessageModel type;
  final DateTime timeSent;
  final String messageId;
  final bool isSeen;

  // E2E fields for main Signal session payload
  final String? ciphertext;
  final String? iv;
  final String? mac;
  final String? sessionId;

  // Media URL (encrypted blob in Firebase Storage if media)
  final String? fileUrl;

  final bool deleted;
  final bool edited;
  final String repliedMessage;
  final String repliedTo;
  final MessageModel repliedMessageType;

  // Runtime-only media E2E fields (NOT stored back to Firestore)
  final String? encryptedMediaUrl;
  final String? mediaKeyB64;
  final String? mediaNonceB64;
  final String senderDeviceId;
  final String peerDeviceId;
  final String? senderEphemeralPub;



  /// Reactions map
  final Map<String, List<String>> reactions;

  Message({
    required this.senderId,
    required this.recieverid,
    required this.text,
    required this.type,
    required this.timeSent,
    required this.messageId,
    required this.isSeen,
    this.encryptedMediaUrl,
     required this.senderDeviceId,
     required this.peerDeviceId,
    this.ciphertext,
    this.senderEphemeralPub,
    this.iv,
    this.mac,
    this.sessionId,
    this.fileUrl,
    this.deleted = false,
    this.edited = false,
    this.repliedMessage = '',
    this.repliedTo = '',
    this.repliedMessageType = MessageModel.text,
    this.mediaKeyB64,
    this.mediaNonceB64,
    this.reactions = const {},
  });

  Message copyWith({
  String? senderId,
  String? recieverid,
  String? text,
  MessageModel? type,
  DateTime? timeSent,
  String? messageId,
  bool? isSeen,
  String? ciphertext,
  String? iv,
  String? mac,
  String? sessionId,
  String? fileUrl,
  bool? deleted,
  bool? edited,
  String? repliedMessage,
  String? repliedTo,
  MessageModel? repliedMessageType,
  String? mediaKeyB64,
  String? mediaNonceB64,
  String? encryptedMediaUrl,
  Map<String, List<String>>? reactions,
  String? senderDeviceId, // ✅ ADD
  String? senderEphemeralPub,
}) {
  return Message(
    senderId: senderId ?? this.senderId,
    recieverid: recieverid ?? this.recieverid,
    text: text ?? this.text,
   senderEphemeralPub: senderEphemeralPub ?? this.senderEphemeralPub,
    type: type ?? this.type,
    timeSent: timeSent ?? this.timeSent,
    messageId: messageId ?? this.messageId,
    isSeen: isSeen ?? this.isSeen,
    senderDeviceId: senderDeviceId ?? this.senderDeviceId, // ✅ ADD
    peerDeviceId: peerDeviceId,
    ciphertext: ciphertext ?? this.ciphertext,
    iv: iv ?? this.iv,
    mac: mac ?? this.mac,
    sessionId: sessionId ?? this.sessionId,
    fileUrl: fileUrl ?? this.fileUrl,
    deleted: deleted ?? this.deleted,
    edited: edited ?? this.edited,
    repliedMessage: repliedMessage ?? this.repliedMessage,
    repliedTo: repliedTo ?? this.repliedTo,
    repliedMessageType:
        repliedMessageType ?? this.repliedMessageType,
    encryptedMediaUrl:
        encryptedMediaUrl ?? this.encryptedMediaUrl,
    mediaKeyB64: mediaKeyB64 ?? this.mediaKeyB64,
    mediaNonceB64: mediaNonceB64 ?? this.mediaNonceB64,
    reactions: reactions ?? this.reactions,
  );
}


  Map<String, dynamic> toMap() {
    final m = {
      'senderId': senderId,
      'recieverid': recieverid,
      'text': text,
      'type': type.type,
      'timeSent': timeSent.millisecondsSinceEpoch,
      'messageId': messageId,
      'isSeen': isSeen,
      'senderDeviceId': senderDeviceId,
      'ciphertext': ciphertext,
      'iv': iv,
      'mac': mac,
      'sessionId': sessionId,
      'senderEphemeralPub': senderEphemeralPub,
      'fileUrl': fileUrl,
      'deleted': deleted,
      'edited': edited,
      'repliedMessage': repliedMessage,
      'repliedTo': repliedTo,
      'repliedMessageType': repliedMessageType.type,
      'reactions': reactions.map((k, v) => MapEntry(k, v)),
    };
    return m;
  }

  factory Message.fromMap(Map<String, dynamic> map) {
  final String typeStr = map['type']?.toString() ?? 'text';
  final String repliedTypeStr = map['repliedMessageType']?.toString() ?? 'text';

  // Parse reactions safely
  final rawReactions = map['reactions'];
  final Map<String, List<String>> parsedReactions = {};
  if (rawReactions is Map) {
    rawReactions.forEach((key, value) {
      parsedReactions[key.toString()] = List<String>.from(value ?? []);
    });
  }

  return Message(
    senderId: map['senderId'] ?? '',
    recieverid: map['recieverid'] ?? '',
    text: map['text'] ?? '',
    type: typeStr.toMessageModel(),
    timeSent: DateTime.fromMillisecondsSinceEpoch(
      (map['timeSent'] is int)
          ? map['timeSent']
          : int.tryParse(map['timeSent']?.toString() ?? '') ?? 0,
    ),
    messageId: map['messageId'] ?? '',
    isSeen: map['isSeen'] ?? false,

    ciphertext: map['ciphertext'],
    iv: map['iv'],
    mac: map['mac'],
    sessionId: map['sessionId'],
    senderDeviceId: map['senderDeviceId'] ?? '',
    peerDeviceId: map['peerDeviceId'] ?? '',
    senderEphemeralPub: map['senderEphemeralPub'],
    fileUrl: map['fileUrl']?.toString(),


    deleted: map['deleted'] ?? false,
    edited: map['edited'] ?? false,

    repliedMessage: map['repliedMessage'] ?? '',
    repliedTo: map['repliedTo'] ?? '',
    repliedMessageType: repliedTypeStr.toMessageModel(),

    encryptedMediaUrl: null,
    mediaKeyB64: null,
    mediaNonceB64: null,

    reactions: parsedReactions,
  );
}

}
