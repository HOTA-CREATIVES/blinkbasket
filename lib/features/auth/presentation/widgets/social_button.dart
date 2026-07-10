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
            style: const TextStyle(
              fontSize: 16,
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
    final double rectSize = size.width;
    final double radius = rectSize / 2;
    final double strokeWidth = rectSize * 0.22;
    
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final Rect rect = Rect.fromLTWH(0, 0, rectSize, rectSize);
    
    // Red quadrant
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.8, math.pi * 0.6, false, paint);

    // Yellow quadrant
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -math.pi * 1.35, math.pi * 0.55, false, paint);

    // Green quadrant
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -math.pi * 1.9, math.pi * 0.55, false, paint);

    // Blue quadrant & horizontal bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.2, math.pi * 0.4, false, paint);
    
    final Paint fillPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
      
    final double barY = radius - (strokeWidth / 2);
    final double barHeight = strokeWidth;
    final double barWidth = radius * 0.95;
    canvas.drawRect(
      Rect.fromLTWH(radius, barY, barWidth, barHeight),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
