import 'package:flutter/material.dart';
import 'dart:math';

class BarVisualizerPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool mirror;

  BarVisualizerPainter({
    required this.data,
    required this.color,
    this.mirror = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barWidth = size.width / data.length;
    final gap = barWidth * 0.25;
    final bw = barWidth - gap;

    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth + gap / 2;
      final h = data[i] * size.height * (mirror ? 0.45 : 0.9);
      if (h < 1) continue;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0.4)],
        ).createShader(Rect.fromLTWH(x, size.height - h, bw, h))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, bw, h),
          const Radius.circular(3),
        ),
        paint,
      );

      if (mirror) {
        final paint2 = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.05),
            ],
          ).createShader(Rect.fromLTWH(x, size.height, bw, h))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height, bw, h),
            const Radius.circular(3),
          ),
          paint2,
        );
      }
    }
  }

  @override
  // FIX: use listEquals-style comparison so repaints actually trigger
  bool shouldRepaint(BarVisualizerPainter old) => true;
}

class WaveformVisualizerPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  WaveformVisualizerPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final mid = size.height / 2;

    // FIX: Waveform now draws a single continuous line using the signed
    // [-1, 1] values from waveData. Positive = above center, negative = below.
    // This gives a proper oscilloscope-style waveform.
    final path = Path();
    final pathFill = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      // data[i] is in [-1, 1]; map to canvas Y (invert so positive = up)
      final y = mid - data[i] * mid * 0.85;

      if (i == 0) {
        path.moveTo(x, y);
        pathFill.moveTo(x, mid);
        pathFill.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (data.length - 1)) * size.width;
        final cx = (prevX + x) / 2;
        final prevY = mid - data[i - 1] * mid * 0.85;
        path.cubicTo(cx, prevY, cx, y, x, y);
        pathFill.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    // Close fill path back to center line
    pathFill.lineTo(size.width, mid);
    pathFill.lineTo(0, mid);
    pathFill.close();

    // Fill under the waveform
    canvas.drawPath(
      pathFill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Glow pass
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Center baseline
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(WaveformVisualizerPainter old) => true;
}

class RadialVisualizerPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double rotation;

  RadialVisualizerPainter({
    required this.data,
    required this.color,
    this.rotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.28;
    final maxBarLen = min(size.width, size.height) * 0.22;
    final count = data.length;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + rotation - pi / 2;
      final barLen = data[i] * maxBarLen;

      final startX = center.dx + radius * cos(angle);
      final startY = center.dy + radius * sin(angle);
      final endX = center.dx + (radius + barLen) * cos(angle);
      final endY = center.dy + (radius + barLen) * sin(angle);

      final t = data[i];
      final barColor = Color.lerp(color.withValues(alpha: 0.4), color, t)!;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = barColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      if (data[i] > 0.6) {
        canvas.drawCircle(
          Offset(endX, endY),
          2,
          Paint()..color = color.withValues(alpha: data[i] * 0.8),
        );
      }
    }

    canvas.drawCircle(
      center,
      radius * 0.85,
      Paint()..color = color.withValues(alpha: 0.04),
    );

    canvas.drawCircle(
      center,
      4,
      Paint()..color = color.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(RadialVisualizerPainter old) => true;
}
