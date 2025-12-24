import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Custom painted meditation illustration for onboarding
class MeditationIllustration extends StatelessWidget {
  final double size;
  
  const MeditationIllustration({super.key, this.size = 280});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MeditationPainter(),
      ),
    );
  }
}

class _MeditationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Serene blue and coral colors
    final primaryBlue = const Color(0xFF5B8FB9);
    final coral = const Color(0xFFE88B6C);
    final sage = const Color(0xFF88B0A8);
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // Background glow circles
    paint.color = primaryBlue.withOpacity(0.1);
    canvas.drawCircle(center, size.width * 0.45, paint);
    
    paint.color = coral.withOpacity(0.08);
    canvas.drawCircle(center, size.width * 0.35, paint);
    
    // Floating leaves - left side
    _drawLeaf(canvas, Offset(size.width * 0.15, size.height * 0.3), sage, 30, -20);
    _drawLeaf(canvas, Offset(size.width * 0.1, size.height * 0.5), sage.withOpacity(0.7), 25, 10);
    
    // Floating leaves - right side
    _drawLeaf(canvas, Offset(size.width * 0.85, size.height * 0.35), sage, 28, 15);
    _drawLeaf(canvas, Offset(size.width * 0.9, size.height * 0.55), sage.withOpacity(0.7), 22, -15);
    
    // Person in meditation (simplified geometric style)
    final personPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryBlue;
    
    // Body (simple rounded shape)
    final bodyPath = Path();
    final bodyCenter = Offset(center.dx, center.dy + size.height * 0.08);
    bodyPath.addOval(Rect.fromCenter(
      center: bodyCenter,
      width: size.width * 0.25,
      height: size.height * 0.3,
    ));
    canvas.drawPath(bodyPath, personPaint);
    
    // Head
    canvas.drawCircle(
      Offset(center.dx, center.dy - size.height * 0.15),
      size.width * 0.1,
      personPaint,
    );
    
    // Arms in meditation pose
    final armPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..color = primaryBlue;
    
    // Left arm
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - size.width * 0.08, center.dy),
        width: size.width * 0.15,
        height: size.height * 0.15,
      ),
      -math.pi * 0.8,
      math.pi * 0.6,
      false,
      armPaint,
    );
    
    // Right arm
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + size.width * 0.08, center.dy),
        width: size.width * 0.15,
        height: size.height * 0.15,
      ),
      -math.pi * 0.2,
      -math.pi * 0.6,
      false,
      armPaint,
    );
    
    // Peaceful aura/energy waves
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = coral.withOpacity(0.3);
    
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(center.dx, center.dy - size.height * 0.15),
        size.width * 0.12 + (i * 8),
        auraPaint,
      );
    }
    
    // Sparkles/stars around
    _drawSparkle(canvas, Offset(size.width * 0.25, size.height * 0.25), coral, 8);
    _drawSparkle(canvas, Offset(size.width * 0.75, size.height * 0.28), sage, 6);
    _drawSparkle(canvas, Offset(size.width * 0.3, size.height * 0.7), primaryBlue.withOpacity(0.6), 7);
    _drawSparkle(canvas, Offset(size.width * 0.7, size.height * 0.75), coral.withOpacity(0.6), 5);
  }
  
  void _drawLeaf(Canvas canvas, Offset position, Color color, double size, double rotation) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation * math.pi / 180);
    
    final path = Path();
    path.moveTo(0, -size / 2);
    path.quadraticBezierTo(size / 3, -size / 4, size / 2, 0);
    path.quadraticBezierTo(size / 4, size / 3, 0, size / 2);
    path.quadraticBezierTo(-size / 4, size / 3, -size / 2, 0);
    path.quadraticBezierTo(-size / 3, -size / 4, 0, -size / 2);
    canvas.drawPath(path, paint);
    
    canvas.restore();
  }
  
  void _drawSparkle(Canvas canvas, Offset position, Color color, double size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2);
      final x = position.dx + math.cos(angle) * size;
      final y = position.dy + math.sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      final midAngle = angle + math.pi / 4;
      final midX = position.dx + math.cos(midAngle) * (size * 0.3);
      final midY = position.dy + math.sin(midAngle) * (size * 0.3);
      path.lineTo(midX, midY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nature scene illustration with hills and sun
class NatureSceneIllustration extends StatelessWidget {
  final double size;
  
  const NatureSceneIllustration({super.key, this.size = 280});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.7, // Landscape format
      child: CustomPaint(
        painter: _NatureScenePainter(),
      ),
    );
  }
}

class _NatureScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final primaryBlue = const Color(0xFF5B8FB9);
    final coral = const Color(0xFFE88B6C);
    final sage = const Color(0xFF88B0A8);
    
    // Sky gradient
   final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryBlue.withOpacity(0.3),
        primaryBlue.withOpacity(0.1),
        Colors.white.withOpacity(0.1),
      ],
    );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.6),
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6)),
    );
    
    // Sun
    final sunPaint = Paint()
      ..color = coral
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.2),
      size.width * 0.08,
      sunPaint,
    );
    
    // Sun glow
    final glowPaint = Paint()
      ..color = coral.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.2),
      size.width * 0.12,
      glowPaint,
    );
    
    // Back hills
    _drawHill(canvas, size, 0, 0.5, sage.withOpacity(0.4));
    _drawHill(canvas, size, 0.3, 0.55, sage.withOpacity(0.5));
    
    // Front hills
    _drawHill(canvas, size, 0.5, 0.65, sage);
    _drawHill(canvas, size, 0.15, 0.7, sage.withOpacity(0.8));
    
    // Simple trees
    _drawTree(canvas, Offset(size.width * 0.2, size.height * 0.55), sage, size.width * 0.04);
    _drawTree(canvas, Offset(size.width * 0.35, size.height * 0.6), sage.withOpacity(0.7), size.width * 0.035);
    _drawTree(canvas, Offset(size.width * 0.65, size.height * 0.63), sage, size.width * 0.045);
    
    // Clouds
    _drawCloud(canvas, Offset(size.width * 0.25, size.height * 0.15), Colors.white.withOpacity(0.8), size.width * 0.12);
    _drawCloud(canvas, Offset(size.width * 0.55, size.height * 0.25), Colors.white.withOpacity(0.6), size.width * 0.1);
  }
  
  void _drawHill(Canvas canvas, Size size, double startX, double peakY, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * (startX + 0.25),
      size.height * peakY,
      size.width * (startX + 0.5),
      size.height,
    );
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  
  void _drawTree(Canvas canvas, Offset position, Color color, double size) {
    final paint = Paint()..color = color;
    
    // Trunk
    canvas.drawRect(
      Rect.fromCenter(center: Offset(position.dx, position.dy + size), width: size * 0.3, height: size * 2),
      paint,
    );
    
    // Foliage (triangle)
    final path = Path();
    path.moveTo(position.dx, position.dy - size);
    path.lineTo(position.dx - size, position.dy + size);
    path.lineTo(position.dx + size, position.dy + size);
    path.close();
    canvas.drawPath(path, paint);
  }
  
  void _drawCloud(Canvas canvas, Offset position, Color color, double size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, size * 0.5, paint);
    canvas.drawCircle(Offset(position.dx - size * 0.4, position.dy), size * 0.4, paint);
    canvas.drawCircle(Offset(position.dx + size * 0.4, position.dy), size * 0.4, paint);
    canvas.drawCircle(Offset(position.dx + size * 0.2, position.dy - size * 0.2), size * 0.35, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chat illustration with plant
class ChatPlantIllustration extends StatelessWidget {
  final double size;
  
  const ChatPlantIllustration({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChatPlantPainter(),
      ),
    );
  }
}

class _ChatPlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final primaryBlue = const Color(0xFF5B8FB9);
    final coral = const Color(0xFFE88B6C);
    final sage = const Color(0xFF88B0A8);
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // Chat bubble
    final bubblePaint = Paint()
      ..color = primaryBlue.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    final bubblePath = Path();
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.7,
        height: size.height * 0.6,
      ),
      Radius.circular(size.width * 0.1),
    );
    bubblePath.addRRect(bubbleRect);
    
    // Bubble tail
    final tailPath = Path();
    tailPath.moveTo(center.dx - size.width * 0.2, center.dy + size.height * 0.25);
    tailPath.lineTo(center.dx - size.width * 0.25, center.dy + size.height * 0.35);
    tailPath.lineTo(center.dx - size.width * 0.15, center.dy + size.height * 0.3);
    tailPath.close();
    canvas.drawPath(tailPath, bubblePaint);
    canvas.drawPath(bubblePath, bubblePaint);
    
    // Plant pot
    final potPaint = Paint()
      ..color = coral
      ..style = PaintingStyle.fill;
    
    final potPath = Path();
    potPath.moveTo(center.dx - size.width * 0.15, center.dy + size.height * 0.1);
    potPath.lineTo(center.dx - size.width * 0.1, center.dy + size.height * 0.2);
    potPath.lineTo(center.dx + size.width * 0.1, center.dy + size.height * 0.2);
    potPath.lineTo(center.dx + size.width * 0.15, center.dy + size.height * 0.1);
    potPath.close();
    canvas.drawPath(potPath, potPaint);
    
    // Plant leaves
    final leafPaint = Paint()
      ..color = sage
      ..style = PaintingStyle.fill;
    
    // Center stem
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.02,
        height: size.height * 0.25,
      ),
      leafPaint,
    );
    
    // Leaves
    _drawSimpleLeaf(canvas, Offset(center.dx, center.dy - size.height * 0.05), sage, size.width * 0.08, -30);
    _drawSimpleLeaf(canvas, Offset(center.dx, center.dy - size.height * 0.1), sage, size.width * 0.09, 25);
    _drawSimpleLeaf(canvas, Offset(center.dx, center.dy - size.height * 0.15), sage, size.width * 0.07, -20);
    
    // Sparkles
    final sparklePaint = Paint()
      ..color = coral.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    _drawSparkle(canvas, Offset(center.dx - size.width * 0.25, center.dy - size.height * 0.15), sparklePaint, 6);
    _drawSparkle(canvas, Offset(center.dx + size.width * 0.25, center.dy - size.height * 0.1), sparklePaint, 5);
    _drawSparkle(canvas, Offset(center.dx + size.width * 0.15, center.dy + size.height * 0.25), sparklePaint, 4);
  }
  
  void _drawSimpleLeaf(Canvas canvas, Offset position, Color color, double size, double rotation) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation * math.pi / 180);
    
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size / 2, -size / 4, size, 0);
    path.quadraticBezierTo(size / 2, size / 4, 0, 0);
    canvas.drawPath(path, paint);
    
    canvas.restore();
  }
  
  void _drawSparkle(Canvas canvas, Offset position, Paint paint, double size) {
    canvas.drawCircle(Offset(position.dx, position.dy - size), size / 3, paint);
    canvas.drawCircle(Offset(position.dx, position.dy + size), size / 3, paint);
    canvas.drawCircle(Offset(position.dx - size, position.dy), size / 3, paint);
    canvas.drawCircle(Offset(position.dx + size, position.dy), size / 3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
