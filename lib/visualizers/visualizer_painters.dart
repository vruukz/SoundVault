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

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color,
            color.withValues(alpha: 0.4),
          ],
        ).createShader(Rect.fromLTWH(x, size.height - h, bw, h))
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, bw, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);

      if (mirror) {
        final rect2 = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height, bw, h),
          const Radius.circular(3),
        );
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
        canvas.drawRRect(rect2, paint2);
      }
    }
  }

  @override
  bool shouldRepaint(BarVisualizerPainter old) => old.data != data;
}

class WaveformVisualizerPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  WaveformVisualizerPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final mid = size.height / 2;
    final path = Path();
    final path2 = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final amp = data[i] * mid * 0.9;
      final y = mid - amp;
      final y2 = mid + amp;
      if (i == 0) {
        path.moveTo(x, y);
        path2.moveTo(x, y2);
      } else {
        final prevX = ((i - 1) / (data.length - 1)) * size.width;
        final cx = (prevX + x) / 2;
        final prevAmp = data[i - 1] * mid * 0.9;
        path.cubicTo(cx, mid - prevAmp, cx, y, x, y);
        path2.cubicTo(cx, mid + prevAmp, cx, y2, x, y2);
      }
    }

    final fillPath = Path()..addPath(path, Offset.zero);
    for (int i = data.length - 1; i >= 0; i--) {
      final x = (i / (data.length - 1)) * size.width;
      final amp = data[i] * mid * 0.9;
      final y2 = mid + amp;
      if (i == data.length - 1) fillPath.lineTo(x, y2);
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final strokePaint2 = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path2, glowPaint);
    canvas.drawPath(path, strokePaint);
    canvas.drawPath(path2, strokePaint2);

    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(WaveformVisualizerPainter old) => old.data != data;
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
  bool shouldRepaint(RadialVisualizerPainter old) =>
      old.data != data || old.rotation != rotation;
}
