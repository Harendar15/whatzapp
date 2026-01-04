// lib/widget/chat/text_image_gif_widget.dart

import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/message_model.dart';
import '../../../../utils/custom_color.dart';
import '../../../../utils/dimensions.dart';
import 'video_player_item.dart';

class TextImageGIFWidget extends StatefulWidget {
  final String message;
  final MessageModel type;
  final Color color;
  final String? fileUrl;
  final bool me;

  const TextImageGIFWidget({
    super.key,
    required this.message,
    required this.type,
    required this.color,
    this.fileUrl,
    this.me = false,
  });

  @override
  State<TextImageGIFWidget> createState() => _TextImageGIFWidgetState();
}

class _TextImageGIFWidgetState extends State<TextImageGIFWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;
  StreamSubscription? _posSub;

  bool get _isNetwork =>
      (widget.fileUrl ?? widget.message).startsWith('http');

  @override
  void initState() {
    super.initState();

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case MessageModel.text:
        return Text(widget.message,
            style: TextStyle(
                fontSize: Dimensions.mediumTextSize,
                color: widget.color));

      case MessageModel.image:
        return _image();

      case MessageModel.gif:
        return _gif(context);

      case MessageModel.video:
        return _video();

      case MessageModel.audio:
        return _audio();

      default:
        return const SizedBox();
    }
  }

  Widget _image() {
    final src = widget.fileUrl ?? widget.message;
    return GestureDetector(
      onTap: () => _zoom(src),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(imageUrl: src),
      ),
    );
  }

  Widget _gif(BuildContext context) {
    final isVideoGif = widget.message.endsWith(".mp4");
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.55,
      child: AspectRatio(
        aspectRatio: 1,
        child: isVideoGif
            ? VideoPlayerItem(videoUrl: widget.message)
            : CachedNetworkImage(imageUrl: widget.message),
      ),
    );
  }

  Widget _video() {
    final src = widget.fileUrl ?? widget.message;
    return VideoPlayerItem(videoUrl: src);
  }

  // ✅ PURE AUDIOPLAYER VOICE NOTE
  Widget _audio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.me
            ? CustomColor.primaryColor
            : CustomColor.greyColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.me ? Colors.white : Colors.black,
            ),
            onPressed: _toggleAudio,
          ),
          Text(
            _format(_position),
            style: TextStyle(
              color: widget.me ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAudio() async {
    final src = widget.fileUrl ?? widget.message;

    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_isNetwork) {
        await _player.play(UrlSource(src));
      } else {
        await _player.play(DeviceFileSource(src));
      }
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _zoom(String path) {
    Get.to(() => Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: _isNetwork
                  ? CachedNetworkImage(imageUrl: path)
                  : Image.file(File(path)),
            ),
          ),
        ));
  }
}
