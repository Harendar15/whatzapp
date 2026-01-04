import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String url;   // Firebase download URL
  final bool isMe;

  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.isMe,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();

  bool _isReady = false;
  bool _isPlaying = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  String? _localPath;

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _localPath = await _cacheAudio(widget.url);

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });

    setState(() => _isReady = true);
  }

  // ---------------- CACHE AUDIO ----------------
  Future<String> _cacheAudio(String url) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    final bytes = await http.readBytes(Uri.parse(url));
    final file = File(path);
    await file.writeAsBytes(bytes);

    return path;
  }

  // ---------------- PLAY / PAUSE ----------------
  Future<void> _togglePlayback() async {
    if (!_isReady || _localPath == null) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(_localPath!));
    }
  }

  // ---------------- FORMAT TIME ----------------
  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------------- CLEANUP ----------------
  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // ▶ PLAY / PAUSE
          GestureDetector(
            onTap: _togglePlayback,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 🎚 SEEK BAR
          Expanded(
            child: Slider(
              value: _position.inMilliseconds.toDouble(),
              max: _duration.inMilliseconds == 0
                  ? 1
                  : _duration.inMilliseconds.toDouble(),
              onChanged: (v) {
                _player.seek(Duration(milliseconds: v.toInt()));
              },
            ),
          ),

          const SizedBox(width: 8),

          // ⏱ TIME
          Text(
            _format(_position),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
