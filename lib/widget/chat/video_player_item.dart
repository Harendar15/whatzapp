// lib/widget/chat/video_player_item.dart
// WHATSAPP PERFECT VIDEO BUBBLE 🔥
// Smooth autoplay, tap-to-pause, overlay play icon, safe cleanup, zero lag.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isBuffering = true;
  bool _disposed = false;

  bool get _isNetwork => widget.videoUrl.startsWith("http");

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final ctrl = _isNetwork
          ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          : VideoPlayerController.file(File(widget.videoUrl));

      _controller = ctrl;

      ctrl.addListener(() {
        if (!_initialized) return;

        // WhatsApp-style buffering indicator
        final buffering = ctrl.value.isBuffering;
        if (_isBuffering != buffering && mounted) {
          setState(() => _isBuffering = buffering);
        }
      });

      await ctrl.initialize();

      if (!_disposed && mounted) {
        setState(() => _initialized = true);
      }

      ctrl.setLooping(true);
      ctrl.play(); // AUTO-PLAY like WhatsApp

    } catch (e) {
      debugPrint("❌ Video load error: $e");
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 200,
        width: 150,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // VIDEO
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),

            // WHATSAPP PLAY ICON (only when paused)
            if (!_controller!.value.isPlaying)
              AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),

            // WHATSAPP BUFFERING SPINNER
            if (_isBuffering)
              const Positioned(
                child: SizedBox(
                  height: 35,
                  width: 35,
                  child: CircularProgressIndicator(
                    color: Colors.white70,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
