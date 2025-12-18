// lib/models/message_model.dart
enum MessageModel {
  text('text'),
  image('image'),
  video('video'),
  audio('audio'),
  gif('gif');

  final String type;
  const MessageModel(this.type);

  @override
  String toString() => type;
}

/// Helpers: convert stored string to MessageModel (safe fallback to text)
extension MessageModelHelpers on String {
  MessageModel toMessageModel() {
    final s = this;
    try {
      return MessageModel.values.firstWhere((m) => m.type == s);
    } catch (_) {
      return MessageModel.text;
    }
  }
}

/// Convenience extension on MessageModel for common checks
extension MessageModelChecks on MessageModel {
  bool get isText => this == MessageModel.text;
  bool get isImage => this == MessageModel.image;
  bool get isVideo => this == MessageModel.video;
  bool get isAudio => this == MessageModel.audio;
  bool get isGif => this == MessageModel.gif;
}
