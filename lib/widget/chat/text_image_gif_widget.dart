// lib/widget/chat/text_image_gif_widget.dart
// FULLY FIXED – No more setState() after dispose errors 💥

import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:voice_message_package/voice_message_package.dart';

import '../../../../models/message_model.dart';
import '../../../../utils/custom_color.dart';
import '../../../../utils/dimensions.dart';
import 'video_player_item.dart';

class TextImageGIFWidget extends StatefulWidget {
  final String message;
  final MessageModel type;
  final Color color;
  final bool me;

  const TextImageGIFWidget({
    super.key,
    required this.message,
    required this.type,
    required this.color,
    this.me = false,
  });

  @override
  State<TextImageGIFWidget> createState() => _TextImageGIFWidgetState();
}

class _TextImageGIFWidgetState extends State<TextImageGIFWidget> {
  bool isPlaying = false;
  final AudioPlayer audioPlayer = AudioPlayer();

  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  bool get _isNetwork => widget.message.startsWith('http');

  @override
  void initState() {
    super.initState();

    // 🔥 FIX: cancel-safe state listeners
    _stateSub = audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => isPlaying = state == PlayerState.playing);
    });

    _durationSub = audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => duration = d);
    });

    _positionSub = audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => position = p);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case MessageModel.text:
        return _buildText();
      case MessageModel.image:
        return _buildImage(context);
      case MessageModel.gif:
        return _buildGif(context);
      case MessageModel.video:
        return _buildVideo();
      case MessageModel.audio:
        return _buildAudio();
      default:
        return _buildText();
    }
  }

  // ----------------------------- TEXT -----------------------------
  Widget _buildText() {
    return Text(
      widget.message,
      style: TextStyle(
        fontSize: Dimensions.mediumTextSize,
        color: widget.color,
      ),
    );
  }

  // ----------------------------- IMAGE -----------------------------
  Widget _buildImage(BuildContext context) {
    return InkWell(
      onTap: () => _openZoomDialog(widget.message),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.55,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: _isNetwork
                ? CachedNetworkImage(imageUrl: widget.message, fit: BoxFit.cover)
                : Image.file(File(widget.message), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  // ----------------------------- GIF -----------------------------
  Widget _buildGif(BuildContext context) {
    final isVideoGif = widget.message.endsWith(".mp4");

    return InkWell(
      onTap: () => _openZoomDialog(widget.message),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.55,
          child: AspectRatio(
            aspectRatio: 1,
            child: isVideoGif
                ? VideoPlayerItem(videoUrl: widget.message)
                : CachedNetworkImage(imageUrl: widget.message),
          ),
        ),
      ),
    );
  }

  // ----------------------------- VIDEO -----------------------------
  Widget _buildVideo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayerItem(videoUrl: widget.message),
          Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child:
                const Icon(Icons.play_arrow, size: 32, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ----------------------------- AUDIO -----------------------------
  Widget _buildAudio() {
    return VoiceMessage(
      audioSrc: widget.message,
      played: true,
      me: widget.me,
      meBgColor: CustomColor.primaryColor,
      meFgColor: Colors.white,
      mePlayIconColor: CustomColor.appBarColor,
      contactBgColor: Get.isDarkMode
          ? CustomColor.appBarColor.withOpacity(0.6)
          : CustomColor.white.withOpacity(0.6),
      contactFgColor: Get.isDarkMode
          ? Colors.white70
          : CustomColor.black.withOpacity(0.8),
      contactPlayIconColor: CustomColor.appBarColor,
      noiseColor: Colors.white,
      noiseBgColor: Colors.transparent,
      onPlay: () {},
    );
  }

  // ----------------------------- ZOOM VIEW -----------------------------
  void _openZoomDialog(String path) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: InteractiveViewer(
            maxScale: 10,
            child:
                _isNetwork ? CachedNetworkImage(imageUrl: path) : Image.file(File(path)),
          ),
        ),
      ),
      fullscreenDialog: true,
    );
  }
}
