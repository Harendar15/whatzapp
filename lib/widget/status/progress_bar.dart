// lib/widget/status/progress_bar.dart
import 'package:flutter/material.dart';

class StoryProgressBar extends StatelessWidget {
  final double progress;
  final bool isActive;

  const StoryProgressBar({super.key, required this.progress, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: Colors.white24,
        valueColor: AlwaysStoppedAnimation(isActive ? Colors.white : Colors.white54),
        minHeight: 3,
      ),
    );
  }
}
