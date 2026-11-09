import 'package:flutter/material.dart';

import 'qr_scanner_animation.dart';

/// Lớp phủ khung ngắm QR với 4 góc bo tròn và tia quét chuyển động.
class QrScannerOverlay extends StatelessWidget {
  const QrScannerOverlay({
    super.key,
    this.color = Colors.black54,
    this.scanLineColor = const Color(0xFFF26F25),
    this.borderColor,
    this.windowSize = 260,
    this.borderRadius = 16,
    this.cornerLength = 30,
    this.strokeWidth = 4,
    this.animated = true,
  });

  final Color color;
  final Color scanLineColor;
  final Color? borderColor;
  final double windowSize;
  final double borderRadius;
  final double cornerLength;
  final double strokeWidth;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final effectiveCornerColor = borderColor ?? scanLineColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = constraints.biggest.shortestSide;
        final size =
            maxSide > 0 ? windowSize.clamp(100.0, maxSide) : windowSize;

        final left = (constraints.maxWidth - size) / 2;
        final top = (constraints.maxHeight - size) / 2;

        return Stack(
          children: [
            CustomPaint(
              size: constraints.biggest,
              painter: _OverlayPainter(
                size: size,
                color: color,
                borderRadius: borderRadius,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: size,
              height: size,
              child: CustomPaint(
                painter: _CornerPainter(
                  color: effectiveCornerColor,
                  borderRadius: borderRadius,
                  cornerLength: cornerLength,
                  strokeWidth: strokeWidth,
                ),
                child: QrScannerAnimation(
                  size: size,
                  color: scanLineColor,
                  enabled: animated,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.size,
    required this.color,
    required this.borderRadius,
  });

  final double size;
  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final rect = Rect.fromCenter(
      center: canvasSize.center(Offset.zero),
      width: size,
      height: size,
    );

    final path = Path()
      ..addRect(Offset.zero & canvasSize)
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      size != oldDelegate.size ||
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius;
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.color,
    required this.borderRadius,
    required this.cornerLength,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double cornerLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final length = cornerLength;
    final radius = borderRadius;

    final path = Path()
      // Top-left
      ..moveTo(0, length)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(length, 0)
      // Top-right
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, length)
      // Bottom-left
      ..moveTo(0, size.height - length)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(length, size.height)
      // Bottom-right
      ..moveTo(size.width - length, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width,
        size.height - radius,
      )
      ..lineTo(size.width, size.height - length);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      cornerLength != oldDelegate.cornerLength ||
      strokeWidth != oldDelegate.strokeWidth;
}
