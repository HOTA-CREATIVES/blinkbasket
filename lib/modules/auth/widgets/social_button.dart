import 'dart:math' as math;
import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const SocialButton({
    super.key,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          CustomPaint(
            size: const Size(20, 20),
            painter: GoogleLogoPainter(),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Blue (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(23.49, 12.275)
      ..cubicTo(23.49, 11.47, 23.415, 10.73, 23.3, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.51)
      ..lineTo(18.47, 14.51)
      ..cubicTo(18.18, 15.99, 17.34, 17.25, 16.08, 18.1)
      ..lineTo(19.93, 21.09)
      ..cubicTo(22.19, 19.01, 23.49, 15.92, 23.49, 12.275)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Green (#34A853)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.96, 22.92, 19.93, 21.09)
      ..lineTo(16.08, 18.1)
      ..cubicTo(15.01, 18.82, 13.62, 19.27, 12.0, 19.27)
      ..cubicTo(8.87, 19.27, 6.22, 17.14, 5.27, 14.29)
      ..lineTo(1.27, 14.29)
      ..lineTo(1.27, 17.39)
      ..cubicTo(3.26, 21.34, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // Yellow (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(5.27, 14.29)
      ..cubicTo(5.03, 13.57, 4.9, 12.8, 4.9, 12.0)
      ..cubicTo(4.9, 11.2, 5.03, 10.43, 5.27, 9.71)
      ..lineTo(5.27, 6.61)
      ..lineTo(1.27, 6.61)
      ..cubicTo(0.46, 8.24, 0.0, 10.06, 0.0, 12.0)
      ..cubicTo(0.0, 13.94, 0.46, 15.76, 1.27, 17.39)
      ..lineTo(5.27, 14.29)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Red (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(12.0, 4.73)
      ..cubicTo(13.77, 4.73, 15.35, 5.34, 16.6, 6.53)
      ..lineTo(20.02, 3.11)
      ..cubicTo(17.95, 1.18, 15.23, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.66, 1.27, 6.61)
      ..lineTo(5.27, 9.71)
      ..cubicTo(6.22, 6.86, 8.87, 4.73, 12.0, 4.73)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
