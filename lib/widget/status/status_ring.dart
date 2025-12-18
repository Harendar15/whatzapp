// lib/widget/status/status_ring.dart
import 'package:flutter/material.dart';
import 'package:adchat/widget/safe_image.dart';

class StatusRing extends StatelessWidget {
  final String imageUrl;
  final int ringCount;

  const StatusRing({super.key, required this.imageUrl, this.ringCount = 1});

  @override
  Widget build(BuildContext context) {
    const radius = 30.0;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(radius * 2, radius * 2), painter: _RingPainter(ringCount)),
          SafeImage(url: imageUrl, size: radius - 6),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int segments;
  _RingPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = Offset.zero & size;
    final paintBg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.shade300;
    canvas.drawArc(rect.deflate(stroke / 2), -3.14 / 2, 3.14 * 2, false, paintBg);

    final paintActive = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [Color(0xFF00BFA5), Color(0xFF4CAF50)]).createShader(rect);

    final totalSegments = segments <= 0 ? 1 : segments;
    const gap = 0.06;
    final sweepPer = (2 * 3.141592653589793) / totalSegments;

    for (int i = 0; i < totalSegments; i++) {
      final start = -3.14 / 2 + i * sweepPer + gap;
      final sweep = sweepPer - gap * 2;
      canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, paintActive);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.segments != segments;
}
