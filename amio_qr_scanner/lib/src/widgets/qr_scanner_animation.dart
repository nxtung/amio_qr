import 'package:flutter/material.dart';

/// Widget hiệu ứng tia quét chạy dọc bên trong khung ngắm QR.
class QrScannerAnimation extends StatefulWidget {
  const QrScannerAnimation({
    super.key,
    required this.size,
    this.color = const Color(0xFFF26F25),
    this.duration = const Duration(milliseconds: 1800),
    this.enabled = true,
  });

  final double size;
  final Color color;
  final Duration duration;
  final bool enabled;

  @override
  State<QrScannerAnimation> createState() => _QrScannerAnimationState();
}

class _QrScannerAnimationState extends State<QrScannerAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant QrScannerAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _ScanLinePainter(
            color: widget.color,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = (size.height - 16) * progress + 8;

    final glowRect = Rect.fromLTWH(
        8, (y - 16).clamp(4.0, size.height - 4.0), size.width - 16, 16);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.25),
        ],
      ).createShader(glowRect);

    canvas.drawRect(glowRect, glowPaint);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(8, y),
      Offset(size.width - 8, y),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
