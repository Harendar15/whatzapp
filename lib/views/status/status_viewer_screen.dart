// lib/views/status/status_viewer_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:adchat/widget/status/video_player_widget.dart';
import '../../models/status_model.dart';
import 'package:adchat/controller/controller/status_controller.dart';
import 'viewers_screen.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:adchat/widget/status/progress_bar.dart';
import 'package:adchat/controller/controller/chat_controller.dart';
import 'package:adchat/models/message_reply_model.dart';
import 'package:adchat/models/message_model.dart';
import 'package:adchat/router.dart';

class StatusViewerScreen extends ConsumerStatefulWidget {
  final Status ownerStatus;

  const StatusViewerScreen({super.key, required this.ownerStatus});

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen> {
  late final PageController _pageCtrl;
  final Map<int, File?> _decryptedFiles = {};
  final Map<int, bool> _loading = {};
  final Map<int, double> _progress = {};
  Timer? _timer;
  int _currentIndex = 0;
  bool _isPaused = false;
  static const int _durationSeconds = 5;

  final TextEditingController _replyController = TextEditingController();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _fetchForIndex(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markSeen(0);
      _startProgress();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _fetchForIndex(int idx) async {
    if (!mounted) return;
    if (_decryptedFiles.containsKey(idx)) return;
    if (_loading[idx] == true) return;

    _loading[idx] = true;
    if (mounted) setState(() {});

    try {
      final ctrl = ref.read(statusControllerProvider.notifier);
      final file = await ctrl.downloadAndDecryptStatusImage(
        ownerUid: widget.ownerStatus.uid,
        index: idx,
      );
      _decryptedFiles[idx] = file;
    } catch (e) {
      debugPrint("Decrypt error: $e");
      _decryptedFiles[idx] = null;
    } finally {
      _loading[idx] = false;
      if (mounted) setState(() {});
    }
  }

  void _startProgress() {
    _timer?.cancel();
    if (!mounted) return;

    _progress[_currentIndex] = 0.0;
    setState(() {});

    const tick = Duration(milliseconds: 100);
    final ticks = (_durationSeconds * 1000) ~/ tick.inMilliseconds;
    final inc = 1.0 / ticks;

    _timer = Timer.periodic(tick, (timer) {
      if (!mounted) return;
      if (_isPaused) return;

      final cur = _progress[_currentIndex] ?? 0.0;
      final next = (cur + inc).clamp(0.0, 1.0);

      _progress[_currentIndex] = next;
      setState(() {});

      if (next >= 1.0) _advance();
    });
  }

  void _advance() {
    if (_currentIndex + 1 < widget.ownerStatus.statusUrl.length) {
      _pageCtrl.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Get.back();
    }
  }

  void _goPrevious() {
    if (_currentIndex == 0) return;
    _pageCtrl.animateToPage(_currentIndex - 1, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }
void _markSeen(int index) {
  final myUid = ref.read(authRepositoryProvider).currentUid;
  if (myUid == null) return;

  ref.read(statusRepositoryProvider).markStatusSeen(
    ownerUid: widget.ownerStatus.uid,
    mediaIndex: index,
    viewerUid: myUid,
  );
}


  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _startProgress();
    _markSeen(index);

    _fetchForIndex(index);
    if (index + 1 < widget.ownerStatus.statusUrl.length) _fetchForIndex(index + 1);
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sendingReply) return;

    setState(() => _sendingReply = true);
    try {
      final chatController = ref.read(chatControllerProvider);
      final replyMeta = MessageReply('[Status]', false, MessageModel.image);
      await chatController.sendTextMessage(
        context,
        text,
        widget.ownerStatus.uid,
        false,
        false,
        messageReply: replyMeta,
      );
      _replyController.clear();
      if (mounted) Get.back();
      AppRoutes.moveToChat({
        'name': widget.ownerStatus.username,
        'uid': widget.ownerStatus.uid,
        'isGroupChat': false,
        'isCommunityChat': false,
        'profilePic': widget.ownerStatus.profilePic,
        'isHideChat': false,
      });
    } catch (e) {
      debugPrint("Reply error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send reply")));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }
  bool _isVideo(int index) {
  return widget.ownerStatus.mediaTypes[index] == 'video';
}


  @override
  Widget build(BuildContext context) {
    final total = widget.ownerStatus.statusUrl.length;
    if (total == 0) return const Scaffold(body: Center(child: Text("Nothing to show")));

    final myUid = ref.read(authRepositoryProvider).currentUid;
    final isOwnStatus = myUid == widget.ownerStatus.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPressStart: (_) => _isPaused = true,
                          onLongPressEnd: (_) => _isPaused = false,
                          onTapUp: (d) {
                            final dx = d.localPosition.dx;
                            if (dx < w * 0.33) _goPrevious();
                            else if (dx > w * 0.67) _advance();
                          },
                          child: PageView.builder(
                            controller: _pageCtrl,
                            itemCount: total,
                            onPageChanged: _onPageChanged,
                            itemBuilder: (context, index) {
                              final loading = _loading[index] ?? false;
                              final file = _decryptedFiles[index];
                              if (!loading && file == null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _fetchForIndex(index);
                                });
                              }
                              if (loading || file == null) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (_isVideo(index)) {
                              return Center(
                                child: AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: VideoPlayerWidget(file: file), // your video widget
                                ),
                              );
                            }

                            return Center(
                              child: Image.file(
                                file,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) {
                                  return const Text(
                                    "Could not load image",
                                    style: TextStyle(color: Colors.white),
                                  );
                                },
                              ),
                            );

                            },
                          ),
                        );
                      },
                    ),
                  ),

                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: List.generate(total, (i) {
                        final prog = _progress[i] ?? (i < _currentIndex ? 1.0 : 0.0);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: StoryProgressBar(progress: prog, isActive: i == _currentIndex),
                          ),
                        );
                      }),
                    ),
                  ),

                  Positioned(
                    top: 20,
                    left: 12,
                    child: Row(
                      children: [
                        SafeImage(url: widget.ownerStatus.profilePic, size: 36),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.ownerStatus.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(_timeAgo(widget.ownerStatus.uploadTime.last), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),

                  Positioned(
                    top: 18,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.white), onPressed: () {
                          Get.to(() => ViewersScreen(ownerUid: widget.ownerStatus.uid, index: _currentIndex));
                        }),
                        if (isOwnStatus)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete status?"),
                                  content: const Text("This will remove this update for everyone."),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(statusControllerProvider.notifier).deleteSingleStatus(ownerUid: widget.ownerStatus.uid, index: _currentIndex);
                                if (mounted) Get.back();
                              }
                            },
                          ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Get.back()),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (!isOwnStatus)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Reply",
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: _sendingReply
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                          : IconButton(icon: const Icon(Icons.send, size: 18, color: Colors.white), onPressed: _sendReply),
                    )
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  String _timeAgo(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m";
    if (diff.inDays < 1) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }
}
