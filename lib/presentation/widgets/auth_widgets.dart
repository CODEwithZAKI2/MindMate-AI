import 'package:flutter/material.dart';

/// Welcoming Illustration for Auth Screens
class WelcomeIllustration extends StatelessWidget {
  final double size;

  const WelcomeIllustration({
    super.key,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: child,
          ),
        );
      },
      child: CustomPaint(
        size: Size(size, size),
        painter: _WelcomeIllustrationPainter(),
      ),
    );
  }
}

class _WelcomeIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Serene Blue and Soft Coral colors
    final primaryColor = const Color(0xFF5B8FB9);
    final secondaryColor = const Color(0xFFE88B6C);
    final tertiaryColor = const Color(0xFF88B0A8);
    
    // Background glow circles
    paint.color = primaryColor.withOpacity(0.1);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.45,
      paint,
    );
    
    paint.color = secondaryColor.withOpacity(0.08);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.35,
      paint,
    );
    
    // Central meditation figure (simplified)
    paint.color = primaryColor;
    
    // Head
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.35),
      size.width * 0.08,
      paint,
    );
    
    // Body (sitting position)
    final bodyPath = Path();
    bodyPath.moveTo(size.width * 0.5, size.height * 0.43);
    bodyPath.quadraticBezierTo(
      size.width * 0.45, size.height * 0.55,
      size.width * 0.4, size.height * 0.65,
    );
    bodyPath.lineTo(size.width * 0.6, size.height * 0.65);
    bodyPath.quadraticBezierTo(
      size.width * 0.55, size.height * 0.55,
      size.width * 0.5, size.height * 0.43,
    );
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);
    
    // Peaceful aura around head
    paint.color = tertiaryColor.withOpacity(0.3);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.35),
        size.width * 0.12 + (i * size.width * 0.04),
        paint,
      );
    }
    
    // Floating leaves/sparkles
    paint.style = PaintingStyle.fill;
    paint.color = tertiaryColor.withOpacity(0.6);
    
    final sparklePositions = [
      Offset(size.width * 0.25, size.height * 0.3),
      Offset(size.width * 0.75, size.height * 0.4),
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.7, size.height * 0.25),
    ];
    
    for (final pos in sparklePositions) {
      canvas.drawCircle(pos, size.width * 0.015, paint);
    }
    
    // Larger floating leaves
    paint.color = tertiaryColor.withOpacity(0.4);
    final leaf1 = Path();
    leaf1.moveTo(size.width * 0.2, size.height * 0.5);
    leaf1.quadraticBezierTo(
      size.width * 0.18, size.height * 0.48,
      size.width * 0.2, size.height * 0.46,
    );
    leaf1.quadraticBezierTo(
      size.width * 0.22, size.height * 0.48,
      size.width * 0.2, size.height * 0.5,
    );
    canvas.drawPath(leaf1, paint);
    
    final leaf2 = Path();
    leaf2.moveTo(size.width * 0.8, size.height * 0.55);
    leaf2.quadraticBezierTo(
      size.width * 0.78, size.height * 0.53,
      size.width * 0.8, size.height * 0.51,
    );
    leaf2.quadraticBezierTo(
      size.width * 0.82, size.height * 0.53,
      size.width * 0.8, size.height * 0.55,
    );
    canvas.drawPath(leaf2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Google Sign In Button
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo using colored circles (simplified)
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(
                painter: _GoogleLogoPainter(),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Google colors
    final blue = const Color(0xFF4285F4);
    final red = const Color(0xFFEA4335);
    final yellow = const Color(0xFBBC04);
    final green = const Color(0xFF34A853);
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw simplified "G" shape with Google colors
    // Blue arc (top right)
    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5,
      1.5,
      true,
      paint,
    );
    
    // Red arc (top left)
    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.5,
      1.0,
      true,
      paint,
    );
    
    // Yellow arc (bottom left)
    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.0,
      1.0,
      true,
      paint,
    );
    
    // Green arc (bottom right)
    paint.color = green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.0,
      1.0,
      true,
      paint,
    );
    
    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
